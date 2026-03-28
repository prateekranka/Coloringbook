import UIKit
import CoreGraphics

struct TemplateRenderer {

    // MARK: - Coordinate Transform

    /// The single coordinate transform used everywhere.
    static func documentToViewTransform(viewBox: CGRect, viewSize: CGSize) -> CGAffineTransform {
        let scale = min(viewSize.width / viewBox.width, viewSize.height / viewBox.height)
        let tx = (viewSize.width - viewBox.width * scale) / 2
        let ty = (viewSize.height - viewBox.height * scale) / 2
        return CGAffineTransform(translationX: tx, y: ty).scaledBy(x: scale, y: scale)
    }

    // MARK: - Fill Layer

    /// Render filled regions to UIImage. Only regions with entries in `fills` are drawn.
    /// fills: [regionID: value] where value can be:
    ///   - "RRGGBB"                     flat color
    ///   - "gradient:RRGGBB:RRGGBB:NNN" linear gradient (startHex:endHex:angleDegrees)
    ///   - "pattern:TYPE:RRGGBB"         pattern fill (TYPE = dots/stripes/crosshatch/checker)
    static func renderFillLayer(
        geometry: TemplateGeometry,
        fills: [String: String],
        stamps: [StampEntry] = [],
        size: CGSize
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let ctx = context.cgContext
            let transform = documentToViewTransform(viewBox: geometry.viewBox, viewSize: size)
            ctx.concatenate(transform)

            let sortedRegions = geometry.regions.sorted { $0.zIndex < $1.zIndex }
            for region in sortedRegions {
                guard let value = fills[region.id] else { continue }

                if value.hasPrefix("gradient:") {
                    // --- Gradient fill ---
                    ctx.saveGState()
                    ctx.addPath(region.path)
                    ctx.clip(using: region.fillRule == .evenOdd ? .evenOdd : .winding)

                    let components = value.dropFirst("gradient:".count).split(separator: ":")
                    guard components.count >= 3 else {
                        ctx.restoreGState()
                        continue
                    }
                    let startColor = UIColor(hex: "#\(components[0])")
                    let endColor   = UIColor(hex: "#\(components[1])")
                    let angle      = Double(components[2]) ?? 0

                    let rad = angle * .pi / 180
                    let dx  = cos(rad), dy = sin(rad)
                    let startPt = CGPoint(x: 0.5 - dx * 0.5, y: 0.5 - dy * 0.5)
                    let endPt   = CGPoint(x: 0.5 + dx * 0.5, y: 0.5 + dy * 0.5)

                    let bounds = region.path.boundingBoxOfPath
                    let startAbsolute = CGPoint(
                        x: bounds.minX + startPt.x * bounds.width,
                        y: bounds.minY + startPt.y * bounds.height)
                    let endAbsolute = CGPoint(
                        x: bounds.minX + endPt.x * bounds.width,
                        y: bounds.minY + endPt.y * bounds.height)

                    var sR: CGFloat = 0, sG: CGFloat = 0, sB: CGFloat = 0, sA: CGFloat = 0
                    var eR: CGFloat = 0, eG: CGFloat = 0, eB: CGFloat = 0, eA: CGFloat = 0
                    startColor.getRed(&sR, green: &sG, blue: &sB, alpha: &sA)
                    endColor.getRed(&eR, green: &eG, blue: &eB, alpha: &eA)
                    let colorComponents = [sR, sG, sB, sA, eR, eG, eB, eA] as [CGFloat]
                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    if let gradient = CGGradient(
                        colorSpace: colorSpace,
                        colorComponents: colorComponents,
                        locations: [0, 1],
                        count: 2
                    ) {
                        ctx.drawLinearGradient(
                            gradient,
                            start: startAbsolute,
                            end: endAbsolute,
                            options: [])
                    }
                    ctx.restoreGState()

                } else if value.hasPrefix("pattern:") {
                    // --- Pattern fill ---
                    ctx.saveGState()
                    ctx.addPath(region.path)
                    ctx.clip(using: region.fillRule == .evenOdd ? .evenOdd : .winding)

                    let parts = value.dropFirst("pattern:".count).split(separator: ":")
                    guard parts.count >= 2 else {
                        ctx.restoreGState()
                        continue
                    }
                    let patternType  = String(parts[0])
                    let patternColor = UIColor(hex: "#\(parts[1])")
                    let bounds       = region.path.boundingBoxOfPath

                    // Fill background white first
                    ctx.setFillColor(UIColor.white.cgColor)
                    ctx.addPath(region.path)
                    ctx.fillPath(using: region.fillRule == .evenOdd ? .evenOdd : .winding)

                    // Re-clip for pattern drawing
                    ctx.addPath(region.path)
                    ctx.clip(using: region.fillRule == .evenOdd ? .evenOdd : .winding)

                    let spacing: CGFloat    = 12
                    let dotRadius: CGFloat  = 3
                    let x0 = Int(bounds.minX / spacing) * Int(spacing)
                    let y0 = Int(bounds.minY / spacing) * Int(spacing)

                    switch patternType {
                    case "dots":
                        ctx.setFillColor(patternColor.cgColor)
                        var y = CGFloat(y0)
                        while y < bounds.maxY + spacing {
                            var x = CGFloat(x0)
                            while x < bounds.maxX + spacing {
                                ctx.fillEllipse(in: CGRect(
                                    x: x - dotRadius, y: y - dotRadius,
                                    width: dotRadius * 2, height: dotRadius * 2))
                                x += spacing
                            }
                            y += spacing
                        }
                    case "stripes":
                        ctx.setStrokeColor(patternColor.cgColor)
                        ctx.setLineWidth(3)
                        var x = CGFloat(x0)
                        while x < bounds.maxX + spacing {
                            ctx.move(to: CGPoint(x: x, y: bounds.minY - spacing))
                            ctx.addLine(to: CGPoint(x: x, y: bounds.maxY + spacing))
                            x += spacing
                        }
                        ctx.strokePath()
                    case "crosshatch":
                        ctx.setStrokeColor(patternColor.cgColor)
                        ctx.setLineWidth(1.5)
                        var x = CGFloat(x0)
                        while x < bounds.maxX + spacing {
                            ctx.move(to: CGPoint(x: x, y: bounds.minY - spacing))
                            ctx.addLine(to: CGPoint(x: x, y: bounds.maxY + spacing))
                            x += spacing
                        }
                        var yLine = CGFloat(y0)
                        while yLine < bounds.maxY + spacing {
                            ctx.move(to: CGPoint(x: bounds.minX - spacing, y: yLine))
                            ctx.addLine(to: CGPoint(x: bounds.maxX + spacing, y: yLine))
                            yLine += spacing
                        }
                        ctx.strokePath()
                    case "checker":
                        ctx.setFillColor(patternColor.cgColor)
                        let checkerSize = spacing
                        var row = 0
                        var y = CGFloat(y0)
                        while y < bounds.maxY + checkerSize {
                            var col = 0
                            var x = CGFloat(x0)
                            while x < bounds.maxX + checkerSize {
                                if (row + col) % 2 == 0 {
                                    ctx.fill(CGRect(x: x, y: y, width: checkerSize, height: checkerSize))
                                }
                                x += checkerSize; col += 1
                            }
                            y += checkerSize; row += 1
                        }
                    default:
                        break
                    }
                    ctx.restoreGState()

                } else {
                    // --- Flat color fill (existing behavior) ---
                    let color = UIColor(hex: value)
                    ctx.setFillColor(color.cgColor)
                    ctx.addPath(region.path)
                    ctx.fillPath(using: region.fillRule)
                }
            }

            // --- Stamp rendering (no clipping, drawn on top of all region fills) ---
            for stamp in stamps {
                let center = CGPoint(x: stamp.centerX, y: stamp.centerY)
                let stampPath = StampShape(rawValue: stamp.shape.rawValue)!.path(radius: CGFloat(stamp.size))
                var transform = CGAffineTransform(translationX: center.x, y: center.y)
                let translatedPath = stampPath.copy(using: &transform)!
                UIColor(hex: "#\(stamp.hexColor)").setFill()
                ctx.addPath(translatedPath)
                ctx.fillPath()
            }
        }
    }

    // MARK: - Line Art

    /// Render line art (all paths with black strokes) to UIImage.
    /// This image is used as the topmost layer with .multiply blend mode.
    static func renderLineArt(
        geometry: TemplateGeometry,
        size: CGSize
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cgContext = context.cgContext
            let transform = documentToViewTransform(viewBox: geometry.viewBox, viewSize: size)
            cgContext.concatenate(transform)

            let scale = min(size.width / geometry.viewBox.width, size.height / geometry.viewBox.height)
            let strokeWidth = 3.0 / scale

            cgContext.setStrokeColor(UIColor.black.cgColor)
            cgContext.setLineWidth(strokeWidth)
            cgContext.setLineCap(.round)
            cgContext.setLineJoin(.round)
            cgContext.setFillColor(UIColor.clear.cgColor)

            for region in geometry.regions {
                cgContext.addPath(region.path)
                cgContext.strokePath()
            }

            for path in geometry.decorativePaths {
                cgContext.addPath(path)
                cgContext.strokePath()
            }
        }
    }

    // MARK: - Thumbnail

    /// Render a thumbnail for the template library.
    static func renderThumbnail(
        geometry: TemplateGeometry,
        fills: [String: String] = [:],
        size: CGSize = CGSize(width: 400, height: 400)
    ) -> UIImage {
        guard !fills.isEmpty else {
            return renderLineArt(geometry: geometry, size: size)
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let fillLayer = renderFillLayer(geometry: geometry, fills: fills, size: size)
            fillLayer.draw(in: CGRect(origin: .zero, size: size))

            let lineArt = renderLineArt(geometry: geometry, size: size)
            lineArt.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - Export

    /// Composite all layers for export: background + fills + pencil strokes + line art.
    static func renderExport(
        geometry: TemplateGeometry,
        fills: [String: String],
        pencilImage: UIImage?,
        backgroundColor: UIColor,
        size: CGSize
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let bounds = CGRect(origin: .zero, size: size)

            // 1. Background
            backgroundColor.setFill()
            context.fill(bounds)

            // 2. Fill layer
            let fillLayer = renderFillLayer(geometry: geometry, fills: fills, size: size)
            fillLayer.draw(in: bounds)

            // 3. Pencil strokes composited on top of fills
            if let pencilImage = pencilImage {
                pencilImage.draw(in: bounds)
            }

            // 4. Line art on top with multiply blend mode
            let cgContext = context.cgContext
            cgContext.saveGState()
            cgContext.setBlendMode(.multiply)
            let lineArt = renderLineArt(geometry: geometry, size: size)
            lineArt.draw(in: bounds)
            cgContext.restoreGState()
        }
    }
}

// UIColor(hex:) is provided by Color+Extensions.swift
