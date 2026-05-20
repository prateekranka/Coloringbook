#!/usr/bin/env python3
import re
import statistics
import sys
from pathlib import Path


NUMBER = r"(-?\d+(?:\.\d+)?)"


def values(pattern, lines, cast=float):
    found = []
    regex = re.compile(pattern)
    for line in lines:
        match = regex.search(line)
        if match:
            found.append(cast(match.group(1)))
    return found


def count_lines(pattern, lines):
    regex = re.compile(pattern)
    return sum(1 for line in lines if regex.search(line))


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: Scripts/analyze_canvas_diagnostics.py artifacts/canvas-diagnostics/latest.log", file=sys.stderr)
        return 2

    path = Path(sys.argv[1])
    if not path.exists():
        print(f"missing log: {path}", file=sys.stderr)
        return 2

    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    input_lines = [line for line in lines if "[GouacheCanvas][input]" in line]
    compare_lines = [line for line in lines if "[GouacheCanvas][compare]" in line]

    commit_render_ms = values(r"commitRenderMs=(\d+)", compare_lines, int)
    commit_queue_wait_ms = values(r"commitQueueWaitMs=(\d+)", compare_lines, int)
    commit_total_ms = values(r"commitTotalMs=(\d+)", compare_lines, int)
    velocities = values(r"velocity=" + NUMBER, input_lines)
    pressures = values(r"force=" + NUMBER, input_lines)
    coalesced = values(r"coalesced=(\d+)", input_lines, int)

    timestamped_inputs = []
    for line in input_lines:
        ts_match = re.search(r"touchTs=" + NUMBER, line)
        phase_match = re.search(r"phase=([A-Za-z]+)", line)
        seq_match = re.search(r"seq=(\d+)", line)
        if ts_match and phase_match:
            seq = int(seq_match.group(1)) if seq_match else None
            timestamped_inputs.append((float(ts_match.group(1)), phase_match.group(1), seq, line))
    timestamped_inputs.sort(key=lambda item: item[0])
    observed_gaps_ms = [
        (timestamped_inputs[index][0] - timestamped_inputs[index - 1][0]) * 1000
        for index in range(1, len(timestamped_inputs))
    ]
    inferred_sample_gaps_ms = []
    for index in range(1, len(timestamped_inputs)):
        timestamp, phase, seq, _ = timestamped_inputs[index]
        previous_timestamp, previous_phase, previous_seq, _ = timestamped_inputs[index - 1]
        if phase not in {"pencilMoved", "fingerMoved"} or previous_phase not in {"pencilBegan", "pencilMoved", "fingerBegan", "fingerMoved"}:
            continue
        if seq is not None and previous_seq is not None and seq > previous_seq:
            inferred_sample_gaps_ms.append(((timestamp - previous_timestamp) * 1000) / (seq - previous_seq))
        else:
            inferred_sample_gaps_ms.append((timestamp - previous_timestamp) * 1000)

    ended_to_began_gaps = []
    for index, (timestamp, phase, _, _) in enumerate(timestamped_inputs[:-1]):
        if phase not in {"pencilEnded", "fingerEnded"}:
            continue
        for next_timestamp, next_phase, _, _ in timestamped_inputs[index + 1:]:
            if next_phase in {"pencilBegan", "fingerBegan"}:
                ended_to_began_gaps.append((next_timestamp - timestamp) * 1000)
                break

    moved_gaps = []
    moved_inputs = [item for item in timestamped_inputs if item[1] in {"pencilMoved", "fingerMoved"}]
    for index in range(1, len(moved_inputs)):
        moved_gaps.append((moved_inputs[index][0] - moved_inputs[index - 1][0]) * 1000)

    stroke_ended = count_lines(r"stroke queued", lines)
    stroke_committed = count_lines(r"stroke committed", lines)
    pending_samples = count_lines(r"phase=pencilMoved", input_lines)

    max_observed_gap = max(observed_gaps_ms, default=0)
    median_observed_gap = statistics.median(observed_gaps_ms) if observed_gaps_ms else 0
    max_inferred_gap = max(inferred_sample_gaps_ms, default=0)
    median_inferred_gap = statistics.median(inferred_sample_gaps_ms) if inferred_sample_gaps_ms else 0
    max_render = max(commit_render_ms, default=0)
    max_end_begin = max(ended_to_began_gaps, default=0)
    avg_moved = statistics.fmean(moved_gaps) if moved_gaps else 0

    correlated_stalls = 0
    for render in commit_render_ms:
        if render > 50 and any(abs(gap - render) <= max(20, render * 0.35) for gap in ended_to_began_gaps):
            correlated_stalls += 1

    print(f"canvas diagnostics: {path}")
    print(f"commits: count={len(commit_render_ms)} maxCommitRenderMs={max_render} maxCommitQueueWaitMs={max(commit_queue_wait_ms, default=0)} maxCommitTotalMs={max(commit_total_ms, default=0)}")
    print(f"input log gaps: max={max_observed_gap:.1f}ms median={median_observed_gap:.1f}ms over16={sum(g > 16 for g in observed_gaps_ms)} over33={sum(g > 33 for g in observed_gaps_ms)} over50={sum(g > 50 for g in observed_gaps_ms)}")
    print(f"inferred sample gaps: max={max_inferred_gap:.1f}ms median={median_inferred_gap:.1f}ms over16={sum(g > 16 for g in inferred_sample_gaps_ms)} over33={sum(g > 33 for g in inferred_sample_gaps_ms)} over50={sum(g > 50 for g in inferred_sample_gaps_ms)}")
    print(f"strokeEnded->next strokeBegan: max={max_end_begin:.1f}ms count={len(ended_to_began_gaps)}")
    print(f"strokeMoved interval: avg={avg_moved:.1f}ms max={max(moved_gaps, default=0):.1f}ms")
    print(f"pencil: samples={pending_samples} avgVelocity={statistics.fmean(velocities) if velocities else 0:.1f} maxVelocity={max(velocities, default=0):.1f} coalescedMax={max(coalesced, default=0)} pressureRange={min(pressures, default=0):.2f}-{max(pressures, default=0):.2f}")
    print(f"stroke accounting: ended={stroke_ended} committed={stroke_committed}")
    print(f"render/input correlation: correlatedStalls={correlated_stalls}")

    failed = False
    if max_inferred_gap > 50:
        print("FAIL: an input gap exceeded 50ms during active drawing", file=sys.stderr)
        failed = True
    if median_inferred_gap > 16:
        print("FAIL: median input gap exceeded 16ms", file=sys.stderr)
        failed = True
    if correlated_stalls > 0:
        print("FAIL: a >50ms commit render was followed by a similar input stall", file=sys.stderr)
        failed = True
    if stroke_committed < stroke_ended:
        print("FAIL: committed stroke count is lower than stroke-ended count", file=sys.stderr)
        failed = True

    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
