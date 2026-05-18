import CoreGraphics
import Foundation
import Metal
import MetalKit
import os.log
import os.signpost
import simd

struct StrokeVertex {
    var color: SIMD4<Float>
    var position: SIMD2<Float>
    var halfWidth: Float
    var softness: Float
    var noiseStrength: Float
    var seed: Float
    var perpNorm: Float

    static let stride = MemoryLayout<StrokeVertex>.stride
}

private struct StrokeUniforms {
    var viewportSize: SIMD2<Float>
    var brushKind: Int32
    var _pad0: Int32
}

enum MetalBrushError: Error {
    case deviceUnavailable
    case commandQueueUnavailable
    case shaderLibraryUnavailable
    case pipelineCreationFailed
}

@MainActor
@Observable
final class MetalBrushRenderer: NSObject, MTKViewDelegate {
    @ObservationIgnored let device: MTLDevice
    @ObservationIgnored let commandQueue: MTLCommandQueue
    @ObservationIgnored private let pipelineState: MTLRenderPipelineState
    @ObservationIgnored private let blitPipelineState: MTLRenderPipelineState

    @ObservationIgnored private var vertexRingBuffers: [MTLBuffer] = []
    @ObservationIgnored private var indexRingBuffers: [MTLBuffer] = []
    @ObservationIgnored private var currentRingIndex: Int = 0
    @ObservationIgnored private var ringVertexCapacity: Int = 0
    @ObservationIgnored private var ringIndexCapacity: Int = 0

    @ObservationIgnored private var brushTextures: [BrushType: MTLTexture] = [:]

    @ObservationIgnored private var currentStrokeVertices: [StrokeVertex] = []
    @ObservationIgnored private var smoothedStrokePoints: [StrokePoint] = []
    @ObservationIgnored let smoother: StrokeSmoother

    @ObservationIgnored private var accumulationTexture: MTLTexture?
    @ObservationIgnored private var accumulationTextureSize: CGSize = .zero

    @ObservationIgnored private var viewportSize: CGSize = .zero

    @ObservationIgnored private(set) var lastFrameLatencyMs: Double = 0
    @ObservationIgnored private var frameStartTime: CFTimeInterval = 0

    private static let ringBufferCount = 3
    private static let signpostLog = OSLog(subsystem: "com.prateekranka.colorflow", category: .pointsOfInterest)

    override init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("MetalBrushRenderer: MTLCreateSystemDefaultDevice returned nil")
        }
        self.device = device

        guard let queue = device.makeCommandQueue() else {
            fatalError("MetalBrushRenderer: failed to create command queue")
        }
        self.commandQueue = queue

        guard let library = device.makeDefaultLibrary() else {
            fatalError("MetalBrushRenderer: failed to load default shader library")
        }

        guard let vertexFn = library.makeFunction(name: "brush_stroke_vertex"),
              let fragmentFn = library.makeFunction(name: "brush_stroke_fragment") else {
            fatalError("MetalBrushRenderer: brush_stroke_vertex or brush_stroke_fragment not found")
        }

        let pipelineDesc = MTLRenderPipelineDescriptor()
        pipelineDesc.vertexFunction = vertexFn
        pipelineDesc.fragmentFunction = fragmentFn
        pipelineDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDesc.colorAttachments[0].isBlendingEnabled = true
        pipelineDesc.colorAttachments[0].sourceRGBBlendFactor = .one
        pipelineDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDesc.colorAttachments[0].sourceAlphaBlendFactor = .one
        pipelineDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        pipelineDesc.colorAttachments[0].writeMask = .all

        guard let pipeline = try? device.makeRenderPipelineState(descriptor: pipelineDesc) else {
            fatalError("MetalBrushRenderer: failed to create stroke pipeline state")
        }
        self.pipelineState = pipeline

        guard let blitVertexFn = library.makeFunction(name: "brush_blit_vertex"),
              let blitFragmentFn = library.makeFunction(name: "brush_blit_fragment") else {
            fatalError("MetalBrushRenderer: brush_blit_vertex or brush_blit_fragment not found")
        }

        let blitDesc = MTLRenderPipelineDescriptor()
        blitDesc.vertexFunction = blitVertexFn
        blitDesc.fragmentFunction = blitFragmentFn
        blitDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        blitDesc.colorAttachments[0].isBlendingEnabled = false

        guard let blitPipeline = try? device.makeRenderPipelineState(descriptor: blitDesc) else {
            fatalError("MetalBrushRenderer: failed to create blit pipeline state")
        }
        self.blitPipelineState = blitPipeline

        self.smoother = StrokeSmoother(config: SmootherConfig(
            smoothingFactor: 0.35,
            predictionStrength: 0.25,
            velocityWeight: 0.4,
            pressureSmoothing: 0.3,
            minDistance: 0.5
        ))


        super.init()

        allocateRingBuffers(initialVertexCapacity: 4096, initialIndexCapacity: 6144)
    }

    func makeStrokeVertex(
        from point: StrokePoint,
        brush: BrushConfiguration,
        prev: StrokePoint?,
        next: StrokePoint?
    ) -> StrokeVertex {
        let tangent = computeTangent(current: point, prev: prev, next: next)
        let pressureScale = 1.0 + point.pressure * brush.pressureResponse
        let halfWidth = brush.size * 0.5 * pressureScale
        let color = SIMD4<Float>(
            brush.color.x,
            brush.color.y,
            brush.color.z,
            brush.color.w * brush.opacity
        )

        return StrokeVertex(
            color: color,
            position: SIMD2<Float>(Float(point.position.x), Float(point.position.y)),
            halfWidth: halfWidth,
            softness: brush.softness,
            noiseStrength: brush.noiseIntensity,
            seed: Float(point.timestamp.truncatingRemainder(dividingBy: 1000)),
            perpNorm: 0
        )
    }

    func addStrokePoint(_ point: StrokePoint, brush: BrushConfiguration) {
        currentBrushKind = brush.brushType
        let smoothed = smoother.addSample(point)
        for sp in smoothed {
            appendSmoothedPoint(sp, brush: brush)
        }
    }

    private func appendSmoothedPoint(_ point: StrokePoint, brush: BrushConfiguration) {
        let prev = smoothedStrokePoints.last
        let tangent = computeTangent(current: point, prev: prev, next: nil)
        let vertex = makeStrokeVertex(from: point, brush: brush, prev: prev, next: nil)
        smoothedStrokePoints.append(point)
        appendQuadVertices(for: vertex, tangent: tangent)
    }

    func beginStroke() {
        if !currentStrokeVertices.isEmpty {
            currentStrokeVertices.removeAll()
        }
        smoother.reset()
        currentStrokeVertices.removeAll()
        smoothedStrokePoints.removeAll()
    }

    func endStroke() -> [StrokePoint] {
        let predicted = smoother.finishStroke()
        for sp in predicted {
            let prev = smoothedStrokePoints.last
            let tangent = computeTangent(current: sp, prev: prev, next: nil)
            let vertex = makeStrokeVertex(from: sp, brush: BrushConfiguration(brushType: currentBrushKind), prev: prev, next: nil)
            smoothedStrokePoints.append(sp)
            appendQuadVertices(for: vertex, tangent: tangent)
        }
        return smoothedStrokePoints
    }

    func commitStroke(brush: BrushConfiguration, viewportSize: CGSize) {
        ensureAccumulationTexture(size: viewportSize)
        guard let accumulationTexture, !currentStrokeVertices.isEmpty else { return }

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(
                descriptor: makeRenderPassDescriptor(texture: accumulationTexture, loadAction: .load)
              ) else {
            return
        }

        renderStrokeVertices(encoder: encoder, brushKind: brush.brushType, viewportSize: viewportSize)
        encoder.endEncoding()
        commandBuffer.commit()
        currentStrokeVertices.removeAll()
    }

    func draw(in view: MTKView) {
        os_signpost(.begin, log: Self.signpostLog, name: "MetalFrame")
        frameStartTime = CACurrentMediaTime()

        guard let drawable = view.currentDrawable else {
            lastFrameLatencyMs = (CACurrentMediaTime() - frameStartTime) * 1000
            os_signpost(.end, log: Self.signpostLog, name: "MetalFrame")
            return
        }

        let size = view.drawableSize
        ensureAccumulationTexture(size: size)

        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            lastFrameLatencyMs = (CACurrentMediaTime() - frameStartTime) * 1000
            os_signpost(.end, log: Self.signpostLog, name: "MetalFrame")
            return
        }

        if let accumulationTexture {
            guard let blitEncoder = commandBuffer.makeRenderCommandEncoder(
                descriptor: makeRenderPassDescriptor(texture: drawable.texture, loadAction: .clear)
            ) else {
                lastFrameLatencyMs = (CACurrentMediaTime() - frameStartTime) * 1000
                os_signpost(.end, log: Self.signpostLog, name: "MetalFrame")
                return
            }
            renderBlit(encoder: blitEncoder, texture: accumulationTexture, viewportSize: size)
            blitEncoder.endEncoding()
        }

        if !currentStrokeVertices.isEmpty,
           let strokeEncoder = commandBuffer.makeRenderCommandEncoder(
            descriptor: makeRenderPassDescriptor(texture: drawable.texture, loadAction: .load)
           ) {
            renderStrokeVertices(encoder: strokeEncoder, brushKind: currentBrushKind, viewportSize: size)
            strokeEncoder.endEncoding()
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()

        lastFrameLatencyMs = (CACurrentMediaTime() - frameStartTime) * 1000
        os_signpost(.end, log: Self.signpostLog, name: "MetalFrame")
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewportSize = size
        ensureAccumulationTexture(size: size)
    }

    func createBrushTexture(kind: BrushType) {
        guard brushTextures[kind] == nil else { return }
        brushTextures[kind] = Self.generateBrushTexture(device: device, kind: kind, size: 64)
    }

    func clearCanvas() {
        accumulationTexture = nil
        accumulationTextureSize = .zero
    }

    func snapshotAccumulationTexture() -> UIImage? {
        guard let texture = accumulationTexture else { return nil }
        return texture.toUIImage()
    }

    func restoreAccumulationTexture(from image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        let size = CGSize(width: cgImage.width, height: cgImage.height)
        ensureAccumulationTexture(size: size)
        guard let texture = accumulationTexture else { return }

        let region = MTLRegionMake2D(0, 0, cgImage.width, cgImage.height)
        let bytesPerRow = cgImage.width * 4
        let byteCount = cgImage.width * cgImage.height * 4
        var pixelData = [UInt8](repeating: 0, count: byteCount)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixelData,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        texture.replace(region: region, mipmapLevel: 0, withBytes: &pixelData, bytesPerRow: bytesPerRow)
    }

#if DEBUG
    func logPerformance() {
        print("[MetalRenderer] frame latency: \(String(format: "%.2f", lastFrameLatencyMs))ms")
    }
#endif

    private var currentBrushKind: BrushType = .pencil

    private func computeTangent(current: StrokePoint, prev: StrokePoint?, next: StrokePoint?) -> SIMD2<Float> {
        let cur = SIMD2<Float>(Float(current.position.x), Float(current.position.y))
        if let prev, let next {
            let p = SIMD2<Float>(Float(prev.position.x), Float(prev.position.y))
            let n = SIMD2<Float>(Float(next.position.x), Float(next.position.y))
            let t = n - p
            let len = length(t)
            return len > 0.001 ? t / len : SIMD2<Float>(1, 0)
        } else if let prev {
            let p = SIMD2<Float>(Float(prev.position.x), Float(prev.position.y))
            let t = cur - p
            let len = length(t)
            return len > 0.001 ? t / len : SIMD2<Float>(1, 0)
        } else if let next {
            let n = SIMD2<Float>(Float(next.position.x), Float(next.position.y))
            let t = n - cur
            let len = length(t)
            return len > 0.001 ? t / len : SIMD2<Float>(1, 0)
        }
        return SIMD2<Float>(1, 0)
    }

    private func appendQuadVertices(for vertex: StrokeVertex, tangent: SIMD2<Float>) {
        let perp = SIMD2<Float>(-tangent.y, tangent.x)
        let center = vertex.position
        let hw = vertex.halfWidth
        let tangentExt = tangent * hw * 0.15

        let corners: [(SIMD2<Float>, Float)] = [
            (center - perp * hw - tangentExt, -1.0),
            (center + perp * hw - tangentExt,  1.0),
            (center - perp * hw + tangentExt, -1.0),
            (center + perp * hw + tangentExt,  1.0),
        ]

        for (cornerPos, perpVal) in corners {
            var v = vertex
            v.position = cornerPos
            v.perpNorm = perpVal
            currentStrokeVertices.append(v)
        }
    }

    private func renderStrokeVertices(
        encoder: MTLRenderCommandEncoder,
        brushKind: BrushType,
        viewportSize: CGSize
    ) {
        let pointCount = currentStrokeVertices.count / 4
        guard pointCount > 0 else { return }

        let vertexCount = currentStrokeVertices.count
        let indexCount = pointCount * 6
        ensureRingBufferCapacity(vertexCount: vertexCount, indexCount: indexCount)

        let ringIdx = currentRingIndex
        let vb = vertexRingBuffers[ringIdx]
        let ib = indexRingBuffers[ringIdx]

        currentStrokeVertices.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return }
            vb.contents().copyMemory(from: base, byteCount: vertexCount * StrokeVertex.stride)
        }

        let rawIndices = ib.contents().assumingMemoryBound(to: UInt32.self)
        for i in 0..<pointCount {
            let base = UInt32(i * 4)
            let ii = i * 6
            rawIndices[ii + 0] = base
            rawIndices[ii + 1] = base + 1
            rawIndices[ii + 2] = base + 2
            rawIndices[ii + 3] = base + 1
            rawIndices[ii + 4] = base + 3
            rawIndices[ii + 5] = base + 2
        }

        var uniforms = StrokeUniforms(
            viewportSize: SIMD2<Float>(Float(viewportSize.width), Float(viewportSize.height)),
            brushKind: Int32(BrushType.allCases.firstIndex(of: brushKind) ?? 0),
            _pad0: 0
        )

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vb, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<StrokeUniforms>.stride, index: 1)
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indexCount,
            indexType: .uint32,
            indexBuffer: ib,
            indexBufferOffset: 0
        )
    }

    private func renderBlit(
        encoder: MTLRenderCommandEncoder,
        texture: MTLTexture,
        viewportSize: CGSize
    ) {
        let vertices: [SIMD2<Float>] = [
            SIMD2<Float>(-1, -1),
            SIMD2<Float>( 1, -1),
            SIMD2<Float>(-1,  1),
            SIMD2<Float>( 1,  1),
        ]
        encoder.setRenderPipelineState(blitPipelineState)
        encoder.setVertexBytes(vertices, length: vertices.count * MemoryLayout<SIMD2<Float>>.stride, index: 0)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }

    private func makeRenderPassDescriptor(
        texture: MTLTexture,
        loadAction: MTLLoadAction
    ) -> MTLRenderPassDescriptor {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = texture
        descriptor.colorAttachments[0].loadAction = loadAction
        descriptor.colorAttachments[0].storeAction = .store
        if loadAction == .clear {
            descriptor.colorAttachments[0].clearColor = MTLClearColor(
                red: 0.996, green: 0.992, blue: 0.973, alpha: 1.0
            )
        }
        return descriptor
    }

    private func ensureAccumulationTexture(size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        if accumulationTexture != nil,
           accumulationTextureSize.width == size.width,
           accumulationTextureSize.height == size.height {
            return
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .private
        accumulationTexture = device.makeTexture(descriptor: descriptor)
        accumulationTextureSize = size

        if let accumulationTexture {
            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let encoder = commandBuffer.makeRenderCommandEncoder(
                    descriptor: makeRenderPassDescriptor(texture: accumulationTexture, loadAction: .clear)
                  ) else { return }
            encoder.endEncoding()
            commandBuffer.commit()
        }
    }

    private func allocateRingBuffers(initialVertexCapacity: Int, initialIndexCapacity: Int) {
        ringVertexCapacity = initialVertexCapacity
        ringIndexCapacity = initialIndexCapacity
        vertexRingBuffers.removeAll()
        indexRingBuffers.removeAll()

        for _ in 0..<Self.ringBufferCount {
            vertexRingBuffers.append(
                device.makeBuffer(
                    length: initialVertexCapacity * StrokeVertex.stride,
                    options: .storageModeShared
                )!
            )
            indexRingBuffers.append(
                device.makeBuffer(
                    length: initialIndexCapacity * MemoryLayout<UInt32>.stride,
                    options: .storageModeShared
                )!
            )
        }
    }

    private func ensureRingBufferCapacity(vertexCount: Int, indexCount: Int) {
        if vertexCount > ringVertexCapacity || indexCount > ringIndexCapacity {
            ringVertexCapacity = max(vertexCount * 2, ringVertexCapacity * 2)
            ringIndexCapacity = max(indexCount * 2, ringIndexCapacity * 2)
            allocateRingBuffers(initialVertexCapacity: ringVertexCapacity, initialIndexCapacity: ringIndexCapacity)
        }
        currentRingIndex = (currentRingIndex + 1) % Self.ringBufferCount
    }

    private static func generateBrushTexture(device: MTLDevice, kind: BrushType, size: Int) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: size,
            height: size,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead]
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }

        let half = Float(size) * 0.5
        var pixels = [UInt8](repeating: 0, count: size * size * 4)

        for y in 0..<size {
            for x in 0..<size {
                let dx = Float(x) - half + 0.5
                let dy = Float(y) - half + 0.5
                let dist = sqrt(dx * dx + dy * dy)
                let radius = half - 0.5
                let normalized = dist / radius

                var alpha: Float
                switch kind {
                case .pencil:
                    let edge = smoothstep(0.7, 1.0, normalized)
                    alpha = 1.0 - edge
                case .marker:
                    alpha = normalized < 0.9 ? 1.0 : 1.0 - (normalized - 0.9) / 0.1
                case .watercolor:
                    alpha = 1.0 - smoothstep(0.0, 1.0, normalized)
                    alpha *= 0.7
                case .spray:
                    let hash = Float(((x * 2654435761) ^ (y * 2246822519)) & 0xFF) / 255.0
                    alpha = hash > 0.5 ? (1.0 - normalized) * 0.5 : 0.0
                case .acrylic:
                    let edge = smoothstep(0.75, 1.0, normalized)
                    alpha = (1.0 - edge) * 0.95
                }

                let idx = (y * size + x) * 4
                pixels[idx + 0] = 255
                pixels[idx + 1] = 255
                pixels[idx + 2] = 255
                pixels[idx + 3] = UInt8(max(0, min(255, alpha * 255.0)))
            }
        }

        texture.replace(
            region: MTLRegionMake2D(0, 0, size, size),
            mipmapLevel: 0,
            withBytes: &pixels,
            bytesPerRow: size * 4
        )
        return texture
    }
}

private func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
    let t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)
}

extension MTLTexture {
    func toUIImage() -> UIImage? {
        let width = self.width
        let height = self.height
        guard width > 0, height > 0 else { return nil }
        let bytesPerRow = width * 4
        let byteCount = width * height * 4
        var pixelData = [UInt8](repeating: 0, count: byteCount)
        let region = MTLRegionMake2D(0, 0, width, height)
        self.getBytes(&pixelData, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ), let cgImage = context.makeImage() else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
