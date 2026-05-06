import CoreGraphics

struct CanvasViewport: Equatable {
    static let minimumScale: CGFloat = 1
    static let maximumScale: CGFloat = 4

    var scale: CGFloat = minimumScale
    var offset: CGSize = .zero

    var isIdentity: Bool {
        scale == Self.minimumScale && offset == .zero
    }

    mutating func updateScale(
        from baseScale: CGFloat,
        magnification: CGFloat,
        canvasSize: CGSize,
        viewportSize: CGSize
    ) {
        scale = Self.clamp(baseScale * magnification, lower: Self.minimumScale, upper: Self.maximumScale)
        offset = clampedOffset(offset, canvasSize: canvasSize, viewportSize: viewportSize)
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
