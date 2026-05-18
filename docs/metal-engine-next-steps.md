# Metal Drawing Engine: Next Steps & Limitation Workarounds

## Overview

The `experimental-smooth-coloring` branch has a working Metal-backed drawing
engine prototype that compiles, renders visible strokes, and passes all tests.
This document covers the known limitations and the recommended work to make it
production-viable.

---

## Known Limitations & Workarounds

### L1: Touch Double-Counting in Pencil Move Handler

**Problem**: `handlePencilMoved` in `MetalCanvasInteractionView` accumulates
ALL coalesced touches into `strokeSamples` on every move, then passes the
entire array to `viewModel.appendMetalStroke()`. This causes quadratic
duplication (N*(N+1)/2 entries for N samples).

**Workaround** (immediate): Track only the *new* samples per move event.
On `touchesBegan`, reset `strokeSamples` to the initial sample. On
`touchesMoved`, append only the new coalesced samples since the last call
and forward those.

```swift
// In handlePencilMoved:
let newSamples = coalesced.map { strokeSample(from: $0) }
strokeSamples.append(contentsOf: newSamples)
coordinator.viewModel.appendMetalStroke(samples: newSamples)  // only new ones
```

**Fix location**: `ColorFlow/Views/MetalCanvasView.swift`
`MetalCanvasInteractionView.handlePencilMoved`

---

### L2: Dual Touch Input Conflict

**Problem**: In Metal+Free mode, both `MetalCanvasInteractionView` and
`CanvasInteractionOverlay` are in the view hierarchy. Touches can be
dispatched to both, causing the pigment engine AND the Metal renderer to
process the same stroke.

**Workaround** (immediate): When `drawingEngineMode == .metalExperimental`,
disable touch handling on `CanvasInteractionOverlay` by setting
`.allowsHitTesting(false)` on it, or add a guard in its touch handlers that
checks `viewModel.drawingEngineMode`.

Alternatively, restructure the view so that `MetalCanvasInteractionView`
fully owns touch input for Metal mode, and `CanvasInteractionOverlay` is
only present for PencilKit mode.

**Fix location**: `ColorFlow/Views/ColoringCanvasView.swift`
the `readyBody` view modifier that overlays `CanvasInteractionOverlay`.

---

### L3: PencilKit Fallback is Preserved

**Status**: ✅ Already working. The `switch viewModel.drawingEngineMode`
in `canvasArtwork` gates between `pencilKitCanvasArtwork` and
`metalCanvasArtwork`. Setting the engine to `.pencilKit` restores the
original PencilKit path with zero changes.

---

### L4: No Undo/Redo for Metal Strokes

**Problem**: `beginMetalStroke`/`appendMetalStroke`/`endMetalStroke` only
accumulate `metalStrokes: [StrokePoint]`. No `PigmentPatch` (before/after
image) is created, and no `CanvasEditAction` is pushed to the undo stack.

**Workaround strategy** (three phases):

#### Phase A: Image-snapshot undo (fastest, mirrors PencilKit)

1. In `beginStroke()` on the Metal coordinator, capture a snapshot of the
   `accumulationTexture` before the stroke starts (GPU→CPU readback).
2. In `endStroke()`, after `commitStroke()`, capture another snapshot.
3. Create a `StrokePatchAction` with the before/after images as `PigmentPatch`.
4. Push to `viewModel.undoStack` via a new `pushMetalStrokeUndo()` method.

Readback approach: render `accumulationTexture` into a staging buffer:

```swift
// Create a staging texture with .shared storage mode
let stagingDesc = MTLTextureDescriptor.texture2DDescriptor(
    pixelFormat: .bgra8Unorm,
    width: Int(size.width), height: Int(size.height),
    mipmapped: false
)
stagingDesc.usage = [.shaderRead]
stagingDesc.storageMode = .shared  // CPU-readable

// Blit from accumulation to staging
if let commandBuffer = commandQueue.makeCommandBuffer(),
   let blitEncoder = commandBuffer.makeBlitCommandEncoder() {
    blitEncoder.copy(from: accumulationTexture, to: stagingTexture)
    blitEncoder.endEncoding()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
}
// Read pixels from staging texture into UIImage
```

#### Phase B: Command-replay undo (more memory-efficient)

Instead of storing full bitmap snapshots, store `StrokeAction` objects and
re-render from stroke history on undo/redo. This requires:
- Converting `[StrokePoint]` + `BrushConfiguration` → `StrokeAction` at
  `endStroke` time
- On undo, remove the last `StrokeAction`, clear the accumulation texture,
  and replay all remaining strokes through the Metal renderer
- Store the initial blank canvas as the undo baseline

This approach trades undo speed for memory efficiency (no full-bitmap
snapshots per stroke).

#### Phase C: Differential patch undo (best performance)

Store only the dirty rect region of the accumulation texture per stroke,
not the full bitmap. This requires:
- Computing the bounding rect of the stroke before commit
- Rendering a crop of the accumulation texture for before/after patches
- Restoring only the crop on undo

---

### L5: No Persistence of Metal Stroke Data

**Problem**: `metalStrokes: [StrokePoint]` in the VM is transient.
On save, the Metal accumulation texture is not captured, and the stroke
points are not serialized.

**Workaround approach**:

1. At `endStroke()`, convert the final smoothed `[StrokePoint]` into a
   `StrokeAction` (mapping `BrushType` → `ToolType` reverse, converting
   coordinates to document space).
2. Append the `StrokeAction` to `paintState.strokeActions`.
3. On save, capture the Metal accumulation texture as a PNG (via readback)
   and store it as the `pigmentLayerFilename`.
4. On reload, if the engine mode is `.metalExperimental`, restore the
   accumulation texture from the saved PNG, then replay any `strokeActions`
   where `drawingEngine == .metalExperimental`.

**Fix location**:
- `ColorFlow/ViewModels/ColoringSessionViewModel.swift` — `endMetalStroke`
  needs to create a `StrokeAction` and append to `paintState`
- `ColorFlow/Services/Metal/MetalBrushRenderer.swift` — add
  `snapshotAccumulationTexture() -> UIImage?` method
- `ColorFlow/Models/ProjectPaintState.swift` — may need a
  `metalStrokeActions` field or a tag on `StrokeAction`

---

### L6: GPU Readback for Undo/Export

**Problem**: The accumulation texture uses `.private` storage mode, which
means the CPU cannot read it. The PencilKit path uses `PigmentBitmap` (a
CPU-side `UIGraphicsImageRenderer`) which can produce `UIImage` snapshots
freely.

**Workaround**: Add a `snapshotAccumulationTexture(size:) -> UIImage?`
method to `MetalBrushRenderer`:

```swift
func snapshotAccumulationTexture() -> UIImage? {
    guard let accumulationTexture else { return nil }
    let width = Int(accumulationTextureSize.width)
    let height = Int(accumulationTextureSize.height)
    guard width > 0, height > 0 else { return nil }

    let stagingDesc = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .bgra8Unorm,
        width: width, height: height,
        mipmapped: false
    )
    stagingDesc.usage = [.shaderRead]
    stagingDesc.storageMode = .shared

    guard let stagingTexture = device.makeTexture(descriptor: stagingDesc),
          let commandBuffer = commandQueue.makeCommandBuffer(),
          let blitEncoder = commandBuffer.makeBlitCommandEncoder() else { return nil }

    blitEncoder.copy(from: accumulationTexture, to: stagingTexture)
    blitEncoder.endEncoding()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()

    // Read pixels from staging texture
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    stagingTexture.getBytes(&pixels, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)

    let cgContext = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!

    guard let cgImage = cgContext.makeImage() else { return nil }
    return UIImage(cgImage: cgImage)
}
```

This readback has a GPU sync cost and should NOT be called every frame.
Only call it at stroke boundaries (undo) and on save.

**Alternative**: Use `.shared` storage mode for the accumulation texture
instead of `.private`. This allows CPU access but may hurt GPU performance
on large textures. Benchmark both approaches.

---

### L7: No Region Masking (Clean Mode) for Metal

**Problem**: In PencilKit `.clean` mode, strokes are clipped to SVG region
paths via `RegionMaskCache` (pre-rasterized white-on-transparent masks).
The Metal renderer currently renders unmasked strokes.

**Workaround strategy**:

1. **GPU stencil masking**: Convert `RegionGeometry.path` (CGPath) to a Metal
   texture mask at load time. During stroke rendering, use a stencil
   attachment to clip fragments outside the mask.

   Steps:
   - In `MetalBrushRenderer`, add a `setRegionMask(_ path: CGPath, size: CGSize)`
     method that rasterizes the CGPath to a texture.
   - In the stroke render pass, set a stencil reference and configure the
     pipeline to discard fragments where the stencil is 0.
   - Clear stencil to 0, draw the mask to set stencil=1 for the region,
     then draw strokes with stencil test = equal(1).

2. **Simpler approach (CPU clip)**: After committing a stroke to the
   accumulation texture, use Core Graphics to clip the committed region by
   compositing the stroke image with the region mask. This avoids GPU
   stencil complexity but limits real-time "stay in lines" feedback.

3. **Hybrid**: Show the unmasked stroke in real-time during drawing (preferring
   responsiveness), then clip after commit. This is what Procreate does —
   the brush appears to draw everywhere, then snaps to the region on pen-up.

**Recommendation**: Start with the hybrid approach (no mask during drawing,
clip on commit) for the prototype. Add GPU stencil masking as a follow-up.

---

### L8: No Eraser in Metal Pipeline

**Problem**: The Metal pipeline uses premultiplied-alpha-over blending
(sourceRGB=1, destRGB=1-srcAlpha). Eraser requires destination-out blending
or a clear blend mode. The current `BrushShader.metal` has no eraser case.

**Workaround**: Add a separate pipeline state for erasing:

```swift
// Eraser pipeline: destination-out blending
pipelineDesc.colorAttachments[0].sourceRGBBlendFactor = .zero
pipelineDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
pipelineDesc.colorAttachments[0].sourceAlphaBlendFactor = .zero
pipelineDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
```

In the fragment shader, the eraser case (brushKind = 5) would output the
brush alpha but with zero color, effectively subtracting from the
accumulation texture.

Also, the `BrushType` enum needs an `.eraser` case, and `MetalCanvasView`
needs to detect `ToolType.eraser` and switch pipeline states.

---

### L9: Fill Bucket Not Wired for Metal

**Problem**: `ToolType.fillBucket` triggers a region fill via
`pigmentEngine.fill(regionID:colorHex:)`. In Metal mode, fill operations
are not connected. The current `metalCanvasArtwork` only shows the Metal
canvas in Free mode with a non-fill-bucket tool.

**Workaround**: Fill operations can still go through the pigment engine for
now. The Metal canvas overlays the `fillLayerImage` below it. When the
pigment engine fills a region, the `fillLayerImage` updates, and the Metal
canvas composites on top.

Long-term, add a `fillRegion(colorHex:mask:)` method to `MetalBrushRenderer`
that renders a solid color into the accumulation texture masked by a
pre-rasterized region mask texture.

---

### L10: Coordinate Space Mismatch

**Problem**: `MetalCanvasInteractionView` uses raw view coordinates for
touch points. The PencilKit path transforms touches through
`CanvasViewport.canvasPoint(for:)` and then to document coordinates via
`TemplateRenderer.documentToViewTransform`. Metal strokes drawn in view
space won't align with the pigment layer or line art if the viewport pans
or zooms.

**Workaround**: Apply the same coordinate transform chain used by the
pigment engine:

1. Convert touch point from view coordinates to canvas coordinates via
   `CanvasViewport.canvasPoint(for:)`.
2. Convert canvas coordinates to document coordinates via
   `TemplateRenderer.documentToViewTransform.inverted()` (or the
   equivalent transform chain from `ColoringSessionViewModel`).

Pass the transform matrix to `MetalBrushRenderer` as a uniform, or
pre-transform `StrokePoint.position` before feeding it to the renderer.

**Fix location**:
- `ColorFlow/Views/MetalCanvasView.swift` — coordinator needs access to
  `CanvasViewport` and document-space transform
- `ColorFlow/Services/Metal/MetalBrushRenderer.swift` — either accept
  document-space points or add a viewport transform uniform to the shader

---

### L11: Static Default Brush Params

**Problem**: `BrushConfiguration.defaultBrush(kind:)` provides hardcoded
defaults. Real tool settings come from `ToolSettings`, which includes
user-adjustable size, opacity, and texture amount.

**Status**: Already partially wired. `MetalCanvasView.updateUIView` creates
a `BrushConfiguration(from:settings:colorHex:)` using the selected tool's
settings. The `defaultBrush(kind:)` factory is only used in
`MetalBrushRenderer.endStroke()` as a fallback for the predicted tail
segment.

**Fix**: Improve `endStroke()` to carry the current brush through, not
reconstruct from defaults.

---

## Recommended Next Steps (Priority Order)

### Step 1: Fix Touch Input Bugs (P0 — blocker)

**Goal**: Make Metal strokes render correctly with single points per event.

**Changes**:
1. Fix the pencil double-counting bug in `handlePencilMoved` (L1).
2. Disable `CanvasInteractionOverlay` touch handling when Metal engine is
   active (L2).
3. Apply viewport→document coordinate transform to Metal stroke points (L10).

**Files**:
- `ColorFlow/Views/MetalCanvasView.swift`
- `ColorFlow/Views/ColoringCanvasView.swift`
- `ColorFlow/Services/Metal/MetalBrushRenderer.swift`

**Estimated effort**: Small (a few hours).

---

### Step 2: Implement Undo/Redo for Metal Strokes (P0 — essential)

**Goal**: Users can undo Metal strokes and see their canvas revert.

**Approach**: Phase A — image-snapshot undo (mirrors PencilKit).

**Changes**:
1. Add `snapshotAccumulationTexture() -> UIImage?` to `MetalBrushRenderer`.
   Uses a `.shared` staging texture for GPU→CPU readback (L6).
2. In `ColoringCanvasView.Coordinator.beginStroke()`, capture a
   `beforeImage` via snapshot.
3. In `endStroke()`, after `commitStroke()`, capture an `afterImage`.
4. Create a `CanvasEditAction.pigmentStrokePatch(StrokePatchAction)` with
   a `PigmentPatch(rect:before:after:)`.
5. Push to `viewModel.undoStack` via a new `pushMetalStrokeUndo` method.
6. On undo, call `renderer.replaceAccumulationTexture(with: patch.before)`
   (a new method that restores the accumulation from a UIImage).
7. On redo, call `renderer.replaceAccumulationTexture(with: patch.after)`.

**Files**:
- `ColorFlow/Services/Metal/MetalBrushRenderer.swift` — add snapshot/restore
- `ColorFlow/Views/MetalCanvasView.swift` — add undo lifecycle hooks
- `ColorFlow/ViewModels/ColoringSessionViewModel.swift` — undo integration
- `ColorFlow/Services/RegionPigmentEngine.swift` — may need `PigmentPatch` accessible

**Estimated effort**: Medium (1–2 days).

---

### Step 3: Persist Metal Strokes (P1 — session continuity)

**Goal**: Metal strokes survive app relaunch and project save/load.

**Approach**:
1. Convert `[StrokePoint]` to `StrokeAction` at stroke end. Map
   `BrushType` back to `ToolType`, convert coordinates to document space.
2. Store a `strokeEngine: DrawingEngineMode` tag on each `StrokeAction`
   so reload knows which renderer to use.
3. Add `snapshotAccumulationTexture()` to save the committed canvas as PNG.
4. On project load (if engine is `.metalExperimental`):
   a. Load saved PNG into the accumulation texture via a new
      `loadAccumulationTexture(from: UIImage)` method.
   b. Replay Metal-tagged `strokeActions` through the renderer if the
     saved PNG is stale or missing.
5. Allow engine mode switching on reload: if user switches from Metal to
   PencilKit, clear the Metal accumulation, regenerate `fillLayerImage`
   from `regionFills`, and show only PencilKit strokes.

**Files**:
- `ColorFlow/Models/GouacheDomainModels.swift` — add engine tag to StrokeAction
- `ColorFlow/Models/ProjectPaintState.swift` — persist Metal PNG + actions
- `ColorFlow/ViewModels/ColoringSessionViewModel.swift` — save/load Metal state
- `ColorFlow/Services/Metal/MetalBrushRenderer.swift` — load/restore texture
- `ColorFlow/Services/StorageService.swift` — store Metal layer PNG

**Estimated effort**: Medium (1–2 days).

---

### Step 4: Add Eraser to Metal Pipeline (P1 — feature parity)

**Goal**: Eraser tool works in Metal mode.

**Changes**:
1. Add `BrushType.eraser` to the `BrushType` enum (or reuse `.marker` with
   a blend flag).
2. Add a second `MTLRenderPipelineState` in `MetalBrushRenderer` for
   destination-out blending.
3. Add eraser case (brushKind=5) in `BrushShader.metal` that outputs
   `(0, 0, 0, alpha)` where alpha is the brush's coverage.
4. In `MetalCanvasView.Coordinator`, detect `ToolType.eraser` and set the
   renderer's blend mode before rendering.
5. Wire `ToolType.eraser` → `BrushConfiguration` mapping in
   `MetalCanvasView.updateUIView`.

**Files**:
- `ColorFlow/Models/BrushConfiguration.swift` — add eraser config
- `ColorFlow/Services/Metal/MetalBrushRenderer.swift` — second pipeline
- `ColorFlow/Services/Metal/BrushShader.metal` — eraser case
- `ColorFlow/Views/MetalCanvasView.swift` — tool→brush mapping

**Estimated effort**: Small (half a day).

---

### Step 5: Region Clipping for Clean Mode (P1 — feature parity)

**Goal**: Metal strokes stay within SVG region boundaries in Clean mode.

**Approach**: Hybrid — draw unmasked during live stroke, clip on commit.

**Changes**:
1. In `MetalBrushRenderer`, add a `clipToRegionMask(_ mask: CGPath, size: CGSize)`
   method that rasterizes the path to a Metal texture.
2. Add a stencil attachment to the stroke render pass descriptor.
3. Before rendering the stroke, draw the mask to set stencil=1.
4. Configure stroke pipeline to only render where stencil=1.
5. After commit, re-composite without the stencil if the unmasked look is
   desired during live drawing.
6. In `ColoringSessionViewModel`, wire `beginLiveStroke`/`endLiveStroke`
   to pass the `regionID` for Metal strokes, resolve the CGPath, and
   pass it to the renderer.

**Files**:
- `ColorFlow/Services/Metal/MetalBrushRenderer.swift` — stencil masking
- `ColorFlow/Views/MetalCanvasView.swift` — region resolution
- `ColorFlow/ViewModels/ColoringSessionViewModel.swift` — region lookup

**Estimated effort**: Medium (1–2 days).

---

### Step 6: Tune SmootherConfig Parameters (P2 — quality)

**Goal**: Optimize input-to-render latency to target <8ms.

**Approach**: Connect `FrameInstrumentation` logging and test with real
Apple Pencil hardware.

**Changes**:
1. Expose `SmootherConfig` tuning parameters in `CanvasSettingsSheet`
   (DEBUG only).
2. Add a DEBUG-only overlay that shows frame-by-frame latency from
   `FrameInstrumentation.averageLatencyMs()`.
3. Test with different `smoothingFactor`, `predictionStrength`, and
   `velocityWeight` values on real hardware.
4. Compare PencilKit input-to-pixel latency (using RenderPerformanceProbe)
   against Metal engine latency.

**Estimated effort**: Small (a few hours of tuning on hardware).

---

### Step 7: Performance Benchmarking (P2 — validation)

**Goal**: Verify Metal engine meets or beats PencilKit on 120Hz iPad Pro.

**Approach**:
1. Add `os_signpost` intervals around the full stroke pipeline:
   touch received → smoother output → vertex buffer submission → frame present.
2. Use Instruments to capture time profiler data on a real device.
3. Compare against PencilKit's native rendering pipeline.
4. Target: <8ms total input-to-pixel latency at 120fps.
5. Verify no main-thread stalls from `waitUntilCompleted` in
   `snapshotAccumulationTexture`.

**Estimated effort**: Small (a session on hardware).

---

## Summary Priority Matrix

| Priority | Step | Effort | Dependency |
|----------|------|-------|------------|
| P0 | L1: Fix touch double-counting | Hours | None |
| P0 | L2: Disable dual touch input | Hours | None |
| P0 | L10: Coordinate transform | Hours | None |
| P0 | Step 1: Fix touch input bugs | Hours | L1+L2+L10 |
| P0 | L6: GPU readback | Hours | None |
| P0 | Step 2: Undo/redo | 1–2 days | L6 |
| P1 | Step 3: Persistence | 1–2 days | Step 2 |
| P1 | Step 4: Eraser | Half day | None |
| P1 | Step 5: Region clipping | 1–2 days | Step 2 |
| P2 | Step 6: Smoother tuning | Hours | Hardware |
| P2 | Step 7: Benchmarking | Hours | Hardware |

**Recommended execution order**: Step 1 → Step 2 → Step 4 → Step 3 → Step 5 → Step 6 → Step 7