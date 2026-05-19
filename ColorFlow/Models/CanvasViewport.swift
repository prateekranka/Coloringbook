import CoreGraphics

struct CanvasViewport: Equatable {
    static let minimumScale: CGFloat = 1
    static let maximumScale: CGFloat = 6

    var scale: CGFloat = minimumScale
    var offset: CGSize = .zero

    init() {}

    init(canvasState: CanvasState) {
        scale = Self.clamp(
            CGFloat(canvasState.zoomScale),
            lower: Self.minimumScale,
            upper: Self.maximumScale
        )
        offset = CGSize(width: CGFloat(canvasState.offsetX), height: CGFloat(canvasState.offsetY))
    }

    var isIdentity: Bool {
        scale == Self.minimumScale && offset == .zero
    }

    mutating func updateScale(
        from baseScale: CGFloat,
        magnification: CGFloat,
        canvasSize: CGSize,
        viewportSize: CGSize
    ) {
        updateScale(
            from: baseScale,
            baseOffset: offset,
            magnification: magnification,
            anchor: CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2),
            canvasSize: canvasSize,
            viewportSize: viewportSize
        )
    }

    mutating func updateScale(
        from baseScale: CGFloat,
        baseOffset: CGSize,
        magnification: CGFloat,
        anchor: CGPoint,
        canvasSize: CGSize,
        viewportSize: CGSize
    ) {
        let clampedBaseScale = Self.clamp(baseScale, lower: Self.minimumScale, upper: Self.maximumScale)
        let nextScale = Self.clamp(
            clampedBaseScale * magnification,
            lower: Self.minimumScale,
            upper: Self.maximumScale
        )
        let center = CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2)
        let anchorVector = CGSize(width: anchor.x - center.x, height: anchor.y - center.y)
        let contentVector = CGSize(
            width: anchorVector.width - baseOffset.width,
            height: anchorVector.height - baseOffset.height
        )
        let scaleRatio = nextScale / clampedBaseScale
        let proposedOffset = CGSize(
            width: anchorVector.width - contentVector.width * scaleRatio,
            height: anchorVector.height - contentVector.height * scaleRatio
        )

        scale = nextScale
        offset = clampedOffset(proposedOffset, canvasSize: canvasSize, viewportSize: viewportSize)
    }

    mutating func updateOffset(
        from baseOffset: CGSize,
        translation: CGSize,
        canvasSize: CGSize,
        viewportSize: CGSize
    ) {
        let proposed = CGSize(
            width: baseOffset.width + translation.width,
            height: baseOffset.height + translation.height
        )
        offset = clampedOffset(proposed, canvasSize: canvasSize, viewportSize: viewportSize)
    }

    mutating func clamp(canvasSize: CGSize, viewportSize: CGSize) {
        scale = Self.clamp(scale, lower: Self.minimumScale, upper: Self.maximumScale)
        offset = clampedOffset(offset, canvasSize: canvasSize, viewportSize: viewportSize)
    }

    func canvasPoint(
        forViewportPoint point: CGPoint,
        canvasSize: CGSize,
        viewportSize: CGSize
    ) -> CGPoint {
        let center = CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2)
        return CGPoint(
            x: (point.x - center.x - offset.width) / scale + canvasSize.width / 2,
            y: (point.y - center.y - offset.height) / scale + canvasSize.height / 2
        )
    }

    func viewportPoint(
        forCanvasPoint point: CGPoint,
        canvasSize: CGSize,
        viewportSize: CGSize
    ) -> CGPoint {
        let center = CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2)
        return CGPoint(
            x: (point.x - canvasSize.width / 2) * scale + center.x + offset.width,
            y: (point.y - canvasSize.height / 2) * scale + center.y + offset.height
        )
    }

    func containsCanvasPoint(
        _ point: CGPoint,
        canvasSize: CGSize
    ) -> Bool {
        CGRect(origin: .zero, size: canvasSize).contains(point)
    }

    var canvasStateValues: (zoomScale: Double, offsetX: Double, offsetY: Double) {
        (
            zoomScale: Double(scale),
            offsetX: Double(offset.width),
            offsetY: Double(offset.height)
        )
    }

    mutating func reset() {
        scale = Self.minimumScale
        offset = .zero
    }

    private func clampedOffset(_ proposed: CGSize, canvasSize: CGSize, viewportSize: CGSize) -> CGSize {
        let scaledSize = CGSize(width: canvasSize.width * scale, height: canvasSize.height * scale)
        let horizontalOverflow = max(0, (scaledSize.width - viewportSize.width) / 2)
        let verticalOverflow = max(0, (scaledSize.height - viewportSize.height) / 2)

        return CGSize(
            width: Self.clamp(proposed.width, lower: -horizontalOverflow, upper: horizontalOverflow),
            height: Self.clamp(proposed.height, lower: -verticalOverflow, upper: verticalOverflow)
        )
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}
