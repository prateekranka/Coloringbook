# CoreML Conversion Runbook — Informative Drawings

This document describes how to convert the
[carolineec/informative-drawings](https://github.com/carolineec/informative-drawings)
PyTorch model to a CoreML `.mlmodelc` bundle for use as ColorFlow's "Artistic"
photo-to-template preset.

---

## Overview

The Artistic preset replaces the XDoG edge-detection stage (Stage 3) with a
neural line-art generator. The model takes a colour photo as input and produces
a grayscale sketch-style edge image as output.

- **Architecture:** CycleGAN Generator (3 ResBlocks)
- **Input size:** 512×512 RGB (re-convertible at 384×384 if latency is too high)
- **Output size:** same as input, single-channel grayscale
- **Expected size:** ~50–150 MB as `.mlmodelc`, depending on precision

The in-app Swift code (`NeuralEdgeDetector.swift`) loads the model lazily on
first Artistic-preset use and releases it immediately after inference — it is
never held in memory across invocations.

---

## Prerequisites

On a Mac with Xcode installed:

```bash
python3 -m venv coreml_venv
source coreml_venv/bin/activate
pip install torch torchvision coremltools Pillow
```

Also clone the model repository next to this script:

```bash
git clone https://github.com/carolineec/informative-drawings \
    Scripts/coreml/informative-drawings
```

---

## Step 1: Download Weights

From the informative-drawings repository, download the pre-trained weights.
The recommended checkpoint is the "anime+contour" model for best coloring-book
line quality:

```
checkpoints/contour_style/latest_net_G_A.pth
```

Place the `.pth` file anywhere accessible, e.g., `Scripts/coreml/weights/`.

---

## Step 2: Convert

```bash
python3 Scripts/coreml/convert_informative_drawings.py \
    --weights Scripts/coreml/weights/latest_net_G_A.pth \
    --output  ColorFlow/Resources/Models/InformativeDrawings.mlpackage
```

This produces `InformativeDrawings.mlpackage` and compiles it to
`InformativeDrawings.mlmodelc` in the same directory.

**To use a smaller input size (if 512×512 is too slow):**

```bash
python3 Scripts/coreml/convert_informative_drawings.py \
    --weights Scripts/coreml/weights/latest_net_G_A.pth \
    --output  ColorFlow/Resources/Models/InformativeDrawings.mlpackage \
    --input-size 384
```

---

## Step 3: Measure On-Device Latency

Use the Instruments "Core ML" template or insert a manual `Date()` before/after
`model.prediction(from:)` in `NeuralEdgeDetector.swift`.

Target thresholds:

| Device  | Input Size | Target |
|---------|-----------|--------|
| A16 (iPad Pro M2) | 512×512 | < 1.5s |
| A14 (iPad Air 5)  | 512×512 | < 3.0s |
| A14 (iPad Air 5)  | 384×384 | < 1.5s |
| A12 (iPad 9th gen)| 384×384 | < 2.5s |

If latency exceeds the target on the minimum supported device, re-convert at
384×384 and update `NeuralEdgeDetector.modelInputSize`.

---

## Step 4: Measure Memory

Use Instruments "Allocations" while running an Artistic-preset pipeline.
Memory should return to baseline after `run()` completes — the model must not
be retained. Target: peak RSS during Artistic inference < 800 MB on a 4 GB iPad.

---

## Step 5: Integrate into Xcode Project

1. Move `InformativeDrawings.mlmodelc` to `ColorFlow/Resources/Models/`.

2. Add to `project.yml` under `targets.ColorFlow.resources`:

   ```yaml
   - path: ColorFlow/Resources/Models/InformativeDrawings.mlmodelc
   ```

3. Regenerate the Xcode project:

   ```bash
   xcodegen generate
   ```

4. Build and verify: `NeuralEdgeDetector.detect()` should no longer return
   `.fallback` for the Artistic preset.

---

## Step 6: Validate

Run the app on a real iPad (not simulator):

1. Open the "Create from Photo" sheet.
2. Pick a test photo.
3. Select **Artistic**.
4. Confirm the progress view completes in < 5s end-to-end.
5. Confirm the resulting template opens and colors correctly in the canvas.

Check the app binary size: if `ipa` file > 200 MB after adding the model,
consider shipping the `.mlmodelc` as an **On-Demand Resource** (ODR):
- Tag the model with `NSBundleResourceRequest` under asset tag `artistic-model`
- Fetch before first Artistic use in `NeuralEdgeDetector`
- This also preserves the "No Data Collected" privacy stance since it's
  an Apple-served download, not user data

---

## Known Conversion Issues

| Issue | Fix |
|-------|-----|
| `torch.jit.trace` fails on dynamic shapes | Pin input size with `--input-size` |
| `coremltools` rejects instance norm layers | Upgrade coremltools ≥ 7.x |
| Model output feature name unknown at runtime | Print `output.featureNames` in a test; update `NeuralEdgeDetector.outputKey` |
| `.mlmodelc` compile step fails | Run `xcrun coremlc compile` manually and check Xcode version |
