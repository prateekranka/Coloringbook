import Foundation
import CoreGraphics

// MARK: - Error type

enum SVGParseError: Error, LocalizedError {
    case fileNotFound
    case invalidXML(String)
    case missingViewBox
    case unsupportedElement(String)
    case unsupportedTransform(String)
    case unsupportedArcCommand
    case invalidPathData(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "SVG file not found at the specified URL."
        case .invalidXML(let detail):
            return "Invalid XML: \(detail)"
        case .missingViewBox:
            return "SVG is missing a required viewBox attribute."
        case .unsupportedElement(let name):
            return "Unsupported SVG element: <\(name)>. This element is not allowed in coloring book templates."
        case .unsupportedTransform(let value):
            return "Unsupported transform '\(value)'. Only translate(x,y) is supported."
        case .unsupportedArcCommand:
            return "Arc commands (A/a) are not supported in path data. Convert arcs to cubic bezier curves."
        case .invalidPathData(let detail):
            return "Invalid path data: \(detail)"
        }
    }
}

// MARK: - Public API

struct SVGParser {
    /// Parse an SVG file at the given URL and return structured geometry.
    /// - Returns: `.success(TemplateGeometry)` or `.failure(SVGParseError)`.
    static func parse(url: URL) -> Result<TemplateGeometry, SVGParseError> {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .failure(.fileNotFound)
        }

        let delegate = SVGParserDelegate()
        guard let xmlParser = XMLParser(contentsOf: url) else {
            return .failure(.fileNotFound)
        }
        xmlParser.delegate = delegate
        xmlParser.parse()

        if let error = delegate.parseError {
            return .failure(error)
        }
        if let xmlError = xmlParser.parserError {
            return .failure(.invalidXML(xmlError.localizedDescription))
        }
        guard let viewBox = delegate.viewBox else {
            return .failure(.missingViewBox)
        }

        let geometry = TemplateGeometry(
            viewBox: viewBox,
            regions: delegate.regions,
            decorativePaths: delegate.decorativePaths
        )
        return .success(geometry)
    }
}

// MARK: - Rejected elements

private let rejectedElements: Set<String> = [
    "filter", "mask", "clipPath", "use", "image", "style",
    "linearGradient", "radialGradient"
]

// MARK: - Rejected attributes (checked at element parse time)

private let rejectedAttributes: Set<String> = [
    "stroke-dasharray", "opacity"
]

// MARK: - Parser delegate

private final class SVGParserDelegate: NSObject, XMLParserDelegate {

    // Outputs
    var viewBox: CGRect?
    var regions: [RegionGeometry] = []
    var decorativePaths: [CGPath] = []
    var parseError: SVGParseError?

    // State
    // Each entry in the stack is the local transform for that <g> level.
    // The accumulated transform at any point is the product of all entries.
    private var transformStack: [CGAffineTransform] = [.identity]

    // Document order counter — incremented for every shape emitted.
    private var elementIndex: Int = 0

    // The product of all transforms currently on the stack.
    private var currentTransform: CGAffineTransform {
        transformStack.reduce(.identity) { $0.concatenating($1) }
    }

    // MARK: XMLParserDelegate

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard parseError == nil else { return }

        // Reject forbidden elements immediately.
        if rejectedElements.contains(elementName) {
            parseError = .unsupportedElement(elementName)
            parser.abortParsing()
            return
        }

        // Reject forbidden attributes on any element.
        for attr in rejectedAttributes {
            if attributeDict[attr] != nil {
                parseError = .unsupportedElement("\(elementName) with attribute '\(attr)'")
                parser.abortParsing()
                return
            }
        }

        switch elementName {
        case "svg":
            handleSVG(attributes: attributeDict)

        case "g":
            handleGroup(attributes: attributeDict, parser: parser)

        case "path":
            handlePath(attributes: attributeDict, parser: parser)

        case "circle":
            handleCircle(attributes: attributeDict)

        case "ellipse":
            handleEllipse(attributes: attributeDict)

        case "rect":
            handleRect(attributes: attributeDict)

        case "polygon":
            handlePolygon(attributes: attributeDict, parser: parser)

        case "defs", "title", "desc", "metadata":
            // Informational / definition containers — skip without error.
            break

        default:
            // Anything not explicitly allowed is rejected.
            parseError = .unsupportedElement(elementName)
            parser.abortParsing()
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard parseError == nil else { return }
        if elementName == "g" {
            // Pop the transform pushed in didStartElement, but never pop the root identity.
            if transformStack.count > 1 {
                transformStack.removeLast()
            }
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        if self.parseError == nil {
            self.parseError = .invalidXML(parseError.localizedDescription)
        }
    }

    // MARK: - Element handlers

    private func handleSVG(attributes: [String: String]) {
        if let vb = attributes["viewBox"] {
            viewBox = parseViewBox(vb)
        }
        // Absence of viewBox is checked after the full parse completes.
    }

    private func handleGroup(attributes: [String: String], parser: XMLParser) {
        if let transformStr = attributes["transform"] {
            switch parseTranslateOnly(transformStr) {
            case .success(let t):
                transformStack.append(t)
            case .failure(let err):
                parseError = err
                parser.abortParsing()
                return
            }
        } else {
            // Push an identity so the stack stays balanced with didEndElement pops.
            transformStack.append(.identity)
        }
    }

    private func handlePath(attributes: [String: String], parser: XMLParser) {
        guard let d = attributes["d"] else { return }

        let fillRule = cgFillRule(from: attributes["fill-rule"])
        let id = attributes["id"]

        switch buildPath(from: d, transform: currentTransform) {
        case .success(let path):
            if let regionID = id {
                let region = RegionGeometry(
                    id: regionID,
                    path: path,
                    bounds: path.boundingBoxOfPath,
                    fillRule: fillRule,
                    zIndex: elementIndex
                )
                regions.append(region)
            } else {
                decorativePaths.append(path)
            }
            elementIndex += 1

        case .failure(let err):
            parseError = err
            parser.abortParsing()
        }
    }

    private func handleCircle(attributes: [String: String]) {
        let cx = cgFloat(attributes["cx"]) ?? 0
        let cy = cgFloat(attributes["cy"]) ?? 0
        let r  = cgFloat(attributes["r"])  ?? 0
        guard r > 0 else { return }

        let mp = CGMutablePath()
        mp.addEllipse(
            in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2),
            transform: currentTransform
        )
        addShape(mp, id: attributes["id"], fillRule: cgFillRule(from: attributes["fill-rule"]))
    }

    private func handleEllipse(attributes: [String: String]) {
        let cx = cgFloat(attributes["cx"]) ?? 0
        let cy = cgFloat(attributes["cy"]) ?? 0
        let rx = cgFloat(attributes["rx"]) ?? 0
        let ry = cgFloat(attributes["ry"]) ?? 0
        guard rx > 0, ry > 0 else { return }

        let mp = CGMutablePath()
        mp.addEllipse(
            in: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2),
            transform: currentTransform
        )
        addShape(mp, id: attributes["id"], fillRule: cgFillRule(from: attributes["fill-rule"]))
    }

    private func handleRect(attributes: [String: String]) {
        let x      = cgFloat(attributes["x"])      ?? 0
        let y      = cgFloat(attributes["y"])      ?? 0
        let width  = cgFloat(attributes["width"])  ?? 0
        let height = cgFloat(attributes["height"]) ?? 0
        guard width > 0, height > 0 else { return }

        // SVG rx/ry for rounded corners: if only one is specified, the other matches.
        let rxRaw = cgFloat(attributes["rx"])
        let ryRaw = cgFloat(attributes["ry"])
        let rx: CGFloat
        let ry: CGFloat
        if let r = rxRaw { rx = r; ry = ryRaw ?? r }
        else if let r = ryRaw { ry = r; rx = r }
        else { rx = 0; ry = 0 }

        let mp = CGMutablePath()
        if rx > 0 || ry > 0 {
            mp.addRoundedRect(
                in: CGRect(x: x, y: y, width: width, height: height),
                cornerWidth:  min(rx, width  / 2),
                cornerHeight: min(ry, height / 2),
                transform: currentTransform
            )
        } else {
            mp.addRect(
                CGRect(x: x, y: y, width: width, height: height),
                transform: currentTransform
            )
        }
        addShape(mp, id: attributes["id"], fillRule: cgFillRule(from: attributes["fill-rule"]))
    }

    private func handlePolygon(attributes: [String: String], parser: XMLParser) {
        guard let pointsStr = attributes["points"] else { return }

        let numbers = tokenizeNumbers(pointsStr)
        guard numbers.count >= 4, numbers.count.isMultiple(of: 2) else {
            parseError = .invalidPathData(
                "polygon 'points' attribute requires an even number of coordinates (at least 4); got \(numbers.count)"
            )
            parser.abortParsing()
            return
        }

        let mp = CGMutablePath()
        mp.move(to: CGPoint(x: numbers[0], y: numbers[1]), transform: currentTransform)
        var i = 2
        while i + 1 < numbers.count {
            mp.addLine(to: CGPoint(x: numbers[i], y: numbers[i + 1]), transform: currentTransform)
            i += 2
        }
        mp.closeSubpath()

        addShape(mp, id: attributes["id"], fillRule: cgFillRule(from: attributes["fill-rule"]))
    }

    // MARK: - Shape registration

    private func addShape(_ path: CGMutablePath, id: String?, fillRule: CGPathFillRule) {
        guard let immutable = path.copy() else { return }
        if let regionID = id {
            let region = RegionGeometry(
                id: regionID,
                path: immutable,
                bounds: immutable.boundingBoxOfPath,
                fillRule: fillRule,
                zIndex: elementIndex
            )
            regions.append(region)
        } else {
            decorativePaths.append(immutable)
        }
        elementIndex += 1
    }

    // MARK: - Attribute parsing helpers

    private func parseViewBox(_ str: String) -> CGRect? {
        let nums = tokenizeNumbers(str)
        guard nums.count == 4, nums[2] > 0, nums[3] > 0 else { return nil }
        return CGRect(x: nums[0], y: nums[1], width: nums[2], height: nums[3])
    }

    /// Parses a `transform` attribute value, accepting only `translate(x)` or
    /// `translate(x,y)`. Any other transform function returns `.failure`.
    private func parseTranslateOnly(_ str: String) -> Result<CGAffineTransform, SVGParseError> {
        let trimmed = str.trimmingCharacters(in: .whitespaces)

        // Reject known-unsupported transform functions before the generic check.
        let unsupportedPrefixes = ["matrix", "rotate", "scale", "skewX", "skewY"]
        for prefix in unsupportedPrefixes {
            if trimmed.lowercased().hasPrefix(prefix) {
                return .failure(.unsupportedTransform(str))
            }
        }

        guard trimmed.lowercased().hasPrefix("translate") else {
            return .failure(.unsupportedTransform(str))
        }

        guard
            let open  = trimmed.firstIndex(of: "("),
            let close = trimmed.lastIndex(of: ")")
        else {
            return .failure(.unsupportedTransform(str))
        }

        let inner = String(trimmed[trimmed.index(after: open)..<close])
        let nums  = tokenizeNumbers(inner)

        switch nums.count {
        case 1:
            return .success(CGAffineTransform(translationX: nums[0], y: 0))
        case 2:
            return .success(CGAffineTransform(translationX: nums[0], y: nums[1]))
        default:
            return .failure(.unsupportedTransform(str))
        }
    }

    private func cgFillRule(from str: String?) -> CGPathFillRule {
        str == "evenodd" ? .evenOdd : .winding
    }

    private func cgFloat(_ str: String?) -> CGFloat? {
        guard let s = str, let d = Double(s.trimmingCharacters(in: .whitespaces)) else { return nil }
        return CGFloat(d)
    }

    // MARK: - Number tokenisation

    /// Splits a string of SVG numbers separated by commas, whitespace, or implicit
    /// negative/positive signs, including scientific notation (e.g. "1.5e-3").
    private func tokenizeNumbers(_ str: String) -> [CGFloat] {
        var result: [CGFloat] = []
        var current  = ""
        var hasDigit = false
        var hasDot   = false
        var hasE     = false

        func flush() {
            if !current.isEmpty, let v = Double(current) {
                result.append(CGFloat(v))
            }
            current  = ""
            hasDigit = false
            hasDot   = false
            hasE     = false
        }

        for ch in str {
            switch ch {
            case " ", "\t", "\n", "\r", ",":
                flush()

            case "-", "+":
                // A sign character begins a new token unless it immediately follows
                // an exponent marker (e/E), in which case it belongs to the exponent.
                if hasDigit && !hasE {
                    flush()
                }
                current.append(ch)

            case ".":
                // A second decimal point in the same token starts a new token.
                // E.g. "0.5.3" → [0.5, 0.3].
                if hasDot {
                    flush()
                }
                hasDot = true
                current.append(ch)

            case "e", "E":
                // Exponent marker — only meaningful after at least one digit.
                if hasDigit {
                    hasE = true
                    current.append(ch)
                }

            case "0"..."9":
                hasDigit = true
                current.append(ch)

            default:
                // Stray letters or punctuation terminate the current token.
                flush()
            }
        }
        flush()
        return result
    }
}

// MARK: - Path token type

private enum PathToken {
    case command(Character)
    case number(CGFloat)
}

// MARK: - Path data tokeniser

/// Lexes an SVG `d` attribute string into a flat array of `.command` / `.number`
/// tokens. Arc commands (A/a) are not rejected here — rejection happens in
/// `buildPath` so the error message is consistent.
private func tokenizePathData(_ d: String) throws -> [PathToken] {
    var tokens: [PathToken] = []

    let commandChars: Set<Character> = [
        "M", "m", "L", "l", "H", "h", "V", "v",
        "C", "c", "S", "s", "Q", "q", "T", "t",
        "A", "a", "Z", "z"
    ]

    var numBuf   = ""
    var hasDigit = false
    var hasDot   = false
    var hasE     = false

    func flushNumber() throws {
        guard !numBuf.isEmpty else { return }
        guard let val = Double(numBuf) else {
            throw SVGParseError.invalidPathData("Cannot parse number '\(numBuf)'")
        }
        tokens.append(.number(CGFloat(val)))
        numBuf   = ""
        hasDigit = false
        hasDot   = false
        hasE     = false
    }

    for ch in d {
        if commandChars.contains(ch) {
            try flushNumber()
            tokens.append(.command(ch))
        } else if ch == " " || ch == "\t" || ch == "\n" || ch == "\r" || ch == "," {
            try flushNumber()
        } else if ch == "-" || ch == "+" {
            // Sign starts a new number token unless it follows 'e'/'E'.
            if hasDigit && !hasE {
                try flushNumber()
            }
            numBuf.append(ch)
        } else if ch == "." {
            // Second dot in the same token → flush and begin a new number.
            if hasDot {
                try flushNumber()
            }
            hasDot = true
            numBuf.append(ch)
        } else if ch == "e" || ch == "E" {
            if hasDigit {
                hasE = true
                numBuf.append(ch)
            }
            // No digit seen yet — ignore (shouldn't occur in valid SVG path data).
        } else if ch >= "0" && ch <= "9" {
            hasDigit = true
            numBuf.append(ch)
        }
        // All other characters are silently ignored (e.g. stray letters).
    }
    try flushNumber()

    return tokens
}

// MARK: - Path builder

/// Parses an SVG `d` attribute string and builds a `CGPath`, pre-multiplied by
/// `transform`. Implements the full set of supported commands including implicit
/// command repetition and smooth-curve reflection.
private func buildPath(
    from d: String,
    transform: CGAffineTransform
) -> Result<CGPath, SVGParseError> {

    let tokens: [PathToken]
    do {
        tokens = try tokenizePathData(d)
    } catch let err as SVGParseError {
        return .failure(err)
    } catch {
        return .failure(.invalidPathData(error.localizedDescription))
    }

    guard !tokens.isEmpty else {
        // Empty path data is valid SVG; return an empty path.
        return .success(CGMutablePath())
    }

    let path = CGMutablePath()

    // Pen state (in user / pre-transform coordinates).
    var currentPoint = CGPoint.zero
    var subpathStart = CGPoint.zero

    // Remembered control points for smooth-curve commands.
    var lastCubicCP2 = CGPoint.zero  // for S/s: reflection of last C/c second control point
    var lastQuadCP   = CGPoint.zero  // for T/t: reflection of last Q/q control point

    // The command character processed in the previous iteration (for S/s and T/t).
    var lastCommand: Character = "M"

    var index = 0

    while index < tokens.count {
        let token = tokens[index]

        guard case .command(let cmd) = token else {
            // A stray number at the top level (no leading command) is malformed.
            return .failure(.invalidPathData(
                "Expected a path command character but found a number at token index \(index)"
            ))
        }
        index += 1

        // Arc commands are unsupported — reject immediately.
        if cmd == "A" || cmd == "a" {
            return .failure(.unsupportedArcCommand)
        }

        let isRelative = cmd.isLowercase
        let baseCmd    = cmd.uppercased().first!

        // Number of numeric parameters consumed per command invocation.
        let paramCount: Int
        switch baseCmd {
        case "M": paramCount = 2
        case "L": paramCount = 2
        case "H": paramCount = 1
        case "V": paramCount = 1
        case "C": paramCount = 6
        case "S": paramCount = 4
        case "Q": paramCount = 4
        case "T": paramCount = 2
        case "Z": paramCount = 0
        default:
            return .failure(.invalidPathData("Unknown path command '\(cmd)'"))
        }

        // Execute the command once, then repeat implicitly while numeric tokens follow.
        var firstIteration = true
        repeat {
            // Verify we have `paramCount` consecutive number tokens starting at `index`.
            // We must not consume a command token as a number.
            if paramCount > 0 {
                var available = 0
                var scan = index
                while available < paramCount && scan < tokens.count {
                    if case .number = tokens[scan] {
                        available += 1
                        scan += 1
                    } else {
                        break
                    }
                }
                if available < paramCount { break }
            }

            switch baseCmd {

            // ------------------------------------------------------------------
            case "M":
                let x = numAt(tokens, index);     let y = numAt(tokens, index + 1)
                index += 2
                let pt: CGPoint
                if isRelative {
                    pt = CGPoint(x: currentPoint.x + x, y: currentPoint.y + y)
                } else {
                    pt = CGPoint(x: x, y: y)
                }
                if firstIteration {
                    path.move(to: pt, transform: transform)
                } else {
                    // After the first coordinate pair of M, additional pairs
                    // are treated as implicit L/l commands (SVG spec §8.3.2).
                    path.addLine(to: pt, transform: transform)
                }
                currentPoint = pt
                subpathStart = pt
                lastCubicCP2 = pt
                lastQuadCP   = pt

            // ------------------------------------------------------------------
            case "L":
                let x = numAt(tokens, index);     let y = numAt(tokens, index + 1)
                index += 2
                let pt: CGPoint
                if isRelative {
                    pt = CGPoint(x: currentPoint.x + x, y: currentPoint.y + y)
                } else {
                    pt = CGPoint(x: x, y: y)
                }
                path.addLine(to: pt, transform: transform)
                currentPoint = pt
                lastCubicCP2 = pt
                lastQuadCP   = pt

            // ------------------------------------------------------------------
            case "H":
                let x = numAt(tokens, index)
                index += 1
                let pt = CGPoint(
                    x: isRelative ? currentPoint.x + x : x,
                    y: currentPoint.y
                )
                path.addLine(to: pt, transform: transform)
                currentPoint = pt
                lastCubicCP2 = pt
                lastQuadCP   = pt

            // ------------------------------------------------------------------
            case "V":
                let y = numAt(tokens, index)
                index += 1
                let pt = CGPoint(
                    x: currentPoint.x,
                    y: isRelative ? currentPoint.y + y : y
                )
                path.addLine(to: pt, transform: transform)
                currentPoint = pt
                lastCubicCP2 = pt
                lastQuadCP   = pt

            // ------------------------------------------------------------------
            case "C":
                let cp1x = numAt(tokens, index)
                let cp1y = numAt(tokens, index + 1)
                let cp2x = numAt(tokens, index + 2)
                let cp2y = numAt(tokens, index + 3)
                let ex   = numAt(tokens, index + 4)
                let ey   = numAt(tokens, index + 5)
                index += 6
                let cp1, cp2, end: CGPoint
                if isRelative {
                    cp1 = CGPoint(x: currentPoint.x + cp1x, y: currentPoint.y + cp1y)
                    cp2 = CGPoint(x: currentPoint.x + cp2x, y: currentPoint.y + cp2y)
                    end = CGPoint(x: currentPoint.x + ex,   y: currentPoint.y + ey)
                } else {
                    cp1 = CGPoint(x: cp1x, y: cp1y)
                    cp2 = CGPoint(x: cp2x, y: cp2y)
                    end = CGPoint(x: ex,   y: ey)
                }
                path.addCurve(to: end, control1: cp1, control2: cp2, transform: transform)
                lastCubicCP2 = cp2
                currentPoint = end
                lastQuadCP   = end

            // ------------------------------------------------------------------
            case "S":
                // Smooth cubic bezier: cp1 is the reflection of the previous C/S cp2.
                let cp2x = numAt(tokens, index)
                let cp2y = numAt(tokens, index + 1)
                let ex   = numAt(tokens, index + 2)
                let ey   = numAt(tokens, index + 3)
                index += 4
                let cp2, end: CGPoint
                if isRelative {
                    cp2 = CGPoint(x: currentPoint.x + cp2x, y: currentPoint.y + cp2y)
                    end = CGPoint(x: currentPoint.x + ex,   y: currentPoint.y + ey)
                } else {
                    cp2 = CGPoint(x: cp2x, y: cp2y)
                    end = CGPoint(x: ex,   y: ey)
                }
                // Reflect only if the preceding command was C or S; otherwise cp1 = currentPoint.
                let cp1S: CGPoint
                let prevUpperS = lastCommand.uppercased().first!
                if prevUpperS == "C" || prevUpperS == "S" {
                    cp1S = CGPoint(
                        x: 2 * currentPoint.x - lastCubicCP2.x,
                        y: 2 * currentPoint.y - lastCubicCP2.y
                    )
                } else {
                    cp1S = currentPoint
                }
                path.addCurve(to: end, control1: cp1S, control2: cp2, transform: transform)
                lastCubicCP2 = cp2
                currentPoint = end
                lastQuadCP   = end

            // ------------------------------------------------------------------
            case "Q":
                let cpx = numAt(tokens, index)
                let cpy = numAt(tokens, index + 1)
                let ex  = numAt(tokens, index + 2)
                let ey  = numAt(tokens, index + 3)
                index += 4
                let cp, end: CGPoint
                if isRelative {
                    cp  = CGPoint(x: currentPoint.x + cpx, y: currentPoint.y + cpy)
                    end = CGPoint(x: currentPoint.x + ex,  y: currentPoint.y + ey)
                } else {
                    cp  = CGPoint(x: cpx, y: cpy)
                    end = CGPoint(x: ex,  y: ey)
                }
                path.addQuadCurve(to: end, control: cp, transform: transform)
                lastQuadCP   = cp
                currentPoint = end
                lastCubicCP2 = end

            // ------------------------------------------------------------------
            case "T":
                // Smooth quadratic: control point is reflection of the previous Q/T control.
                let ex = numAt(tokens, index)
                let ey = numAt(tokens, index + 1)
                index += 2
                let end: CGPoint
                if isRelative {
                    end = CGPoint(x: currentPoint.x + ex, y: currentPoint.y + ey)
                } else {
                    end = CGPoint(x: ex, y: ey)
                }
                // Reflect only if the preceding command was Q or T.
                let cpT: CGPoint
                let prevUpperT = lastCommand.uppercased().first!
                if prevUpperT == "Q" || prevUpperT == "T" {
                    cpT = CGPoint(
                        x: 2 * currentPoint.x - lastQuadCP.x,
                        y: 2 * currentPoint.y - lastQuadCP.y
                    )
                } else {
                    cpT = currentPoint
                }
                path.addQuadCurve(to: end, control: cpT, transform: transform)
                lastQuadCP   = cpT
                currentPoint = end
                lastCubicCP2 = end

            // ------------------------------------------------------------------
            case "Z":
                path.closeSubpath()
                // Current point resets to the start of the subpath.
                currentPoint = subpathStart
                lastCubicCP2 = subpathStart
                lastQuadCP   = subpathStart

            default:
                break
            }

            lastCommand    = cmd
            firstIteration = false

            // Continue implicit repetition while:
            //   - the command takes parameters (Z never repeats), and
            //   - there are still tokens left, and
            //   - the very next token is a number (not another command).
        } while paramCount > 0
               && index < tokens.count
               && { if case .number = tokens[index] { return true }; return false }()
    }

    guard let immutable = path.copy() else {
        return .failure(.invalidPathData("Failed to copy CGMutablePath"))
    }
    return .success(immutable)
}

// MARK: - Token access helper

/// Returns the `CGFloat` value of a `.number` token at `index`, or `0` if the
/// index is out of bounds or the token is not a number. Callers always verify
/// token availability before invoking commands, so the fallback should never fire.
private func numAt(_ tokens: [PathToken], _ index: Int) -> CGFloat {
    guard index < tokens.count, case .number(let v) = tokens[index] else { return 0 }
    return v
}
