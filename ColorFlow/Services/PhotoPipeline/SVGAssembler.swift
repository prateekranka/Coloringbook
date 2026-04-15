import CoreGraphics
import Foundation

// MARK: - SVG Assembler

/// Stage 6: convert `CGPath` contours into a valid SVG string that passes the
/// ColorFlow SVG spec (see `docs/svg-template-spec.md` and `SVGParser.swift`).
///
/// Constraints enforced here:
///   - `viewBox` attribute present on `<svg>`
///   - Each fillable region is a `<path id="region-N" ...>`
///   - All paths are closed (`Z` terminator)
///   - No arc commands — only `M`, `L`, `Z` (straight-line segments from Vision contours)
///   - No unsupported elements or attributes
///   - Path count ≤ 500 hard limit, ≤ 300 soft target
enum SVGAssembler {

    // MARK: - Limits (mirrors the Python validator)

    static let pathCountSoftLimit: Int = 300
    static let pathCountHardLimit: Int = 500

    // MARK: - Public API

    /// Assemble an SVG string from vectorized contours.
    ///
    /// - Parameters:
    ///   - result: Output from `ContourVectorizer.detect`.
    ///   - templateName: Used as the SVG `<title>`.
    /// - Returns: SVG string, or throws if the path count exceeds the hard limit.
    static func assemble(
        _ result: ContourVectorizer.VectorizationResult,
        templateName: String
    ) throws -> String {
        let totalPaths = result.regionPaths.count + result.decorativePaths.count
        guard totalPaths <= pathCountHardLimit else {
            throw PhotoPipelineError.svgAssemblyFailed(
                "Too many paths (\(totalPaths) > \(pathCountHardLimit)). " +
                "Use a simpler preset or a less detailed photo."
            )
        }

        let w = Int(result.imageSize.width)
        let h = Int(result.imageSize.height)

        var lines: [String] = []
        lines.append("""
            <?xml version="1.0" encoding="UTF-8"?>
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(w) \(h)" width="\(w)" height="\(h)">
            <title>\(xmlEscape(templateName))</title>
            """)

        // Region paths (fillable)
        for (i, path) in result.regionPaths.enumerated() {
            let d = pathData(from: path)
            guard !d.isEmpty else { continue }
            lines.append(
                "  <path id=\"region-\(i + 1)\" d=\"\(d)\" fill=\"none\" stroke=\"#000000\" stroke-width=\"2\"/>"
            )
        }

        // Decorative paths (non-fillable)
        for path in result.decorativePaths {
            let d = pathData(from: path)
            guard !d.isEmpty else { continue }
            lines.append(
                "  <path d=\"\(d)\" fill=\"none\" stroke=\"#000000\" stroke-width=\"1\"/>"
            )
        }

        lines.append("</svg>")
        return lines.joined(separator: "\n")
    }

    // MARK: - CGPath → SVG path data

    /// Convert a `CGPath` into an SVG `d` attribute string using only M, L, Z commands.
    ///
    /// Vision contours are already straight-line polylines so no bezier conversion needed.
    /// This guarantees no `A` arc commands — the SVGParser's primary restriction.
    static func pathData(from path: CGPath) -> String {
        var tokens: [String] = []
        var didMove = false

        path.applyWithBlock { elementPtr in
            let el = elementPtr.pointee
            switch el.type {
            case .moveToPoint:
                let p = el.points[0]
                tokens.append(String(format: "M %.2f %.2f", p.x, p.y))
                didMove = true
            case .addLineToPoint:
                guard didMove else { return }
                let p = el.points[0]
                tokens.append(String(format: "L %.2f %.2f", p.x, p.y))
            case .addQuadCurveToPoint:
                // Flatten quad curve to a line (should not occur from Vision, but be safe)
                guard didMove else { return }
                let p = el.points[1]
                tokens.append(String(format: "L %.2f %.2f", p.x, p.y))
            case .addCurveToPoint:
                // Flatten cubic curve to a line (should not occur from Vision)
                guard didMove else { return }
                let p = el.points[2]
                tokens.append(String(format: "L %.2f %.2f", p.x, p.y))
            case .closeSubpath:
                tokens.append("Z")
                didMove = false
            @unknown default:
                break
            }
        }

        // Ensure the path ends with Z (SVGParser requirement for region paths)
        if !tokens.isEmpty, tokens.last != "Z" {
            tokens.append("Z")
        }

        return tokens.joined(separator: " ")
    }

    // MARK: - Helpers

    private static func xmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&",  with: "&amp;")
         .replacingOccurrences(of: "<",  with: "&lt;")
         .replacingOccurrences(of: ">",  with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
