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
        let xmlParser = XMLParser(contentsOf: url)
        guard let xmlParser else {
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
    private var transformStack: [CGAffineTransform] = [.identity]
    private var elementIndex: Int = 0

    // Accumulated current transform (product of stack)
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
            // Informational containers — skip without error.
            break

        default:
            // Anything else that is not explicitly allowed is rejected.
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
        // viewBox absence is checked after full parse, not here,
        // to allow a top-level group to carry it in unusual files.
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

        let mutablePath = CGMutablePath()
        mutablePath.addEllipse(
            in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2),
            transform: currentTransform
        )
        addShape(mutablePath, id: attributes["id"], fillRule: cgFillRule(from: attributes["fill-rule"]))
    }

    private func handleEllipse(attributes: [String: String]) {
        let cx = cgFloat(attributes["cx"]) ?? 0
        let cy = cgFloat(attributes["cy"]) ?? 0
        let rx = cgFloat(attributes["rx"]) ?? 0
        let ry = cgFloat(attributes["ry"]) ?? 0
        guard rx > 0, ry > 0 else { return }

        let mutablePath = CGMutablePath()
        mutablePath.addEllipse(
            in: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2),
            transform: currentTransform
        )
        addShape(mutablePath, id: attributes["id"], fillRule: cgFillRule(from: attributes["fill-rule"]))
    }

    private func handleRect(attributes: [String: String]) {
        let x      = cgFloat(attributes["x"])      ?? 0
        let y      = cgFloat(attributes["y"])      ?? 0
        let width  = cgFloat(attributes["width"])  ?? 0
        let height = cgFloat(attributes["height"]) ?? 0
        guard width > 0, height > 0 else { return }

        let rx = cgFloat(attributes["rx"]) ?? 0
        let ry = cgFloat(attributes["ry"]) ?? rx

        let mutablePath = CGMutablePath()
        if rx > 0 || ry > 0 {
            let effectiveRx = min(rx, width / 2)
            let effectiveRy = min(ry, height / 2)
            mutablePath.addRoundedRect(
                in: CGRect(x: x, y: y, width: width, height: height),
                cornerWidth: effectiveRx,
                cornerHeight: effectiveRy,
                transform: currentTransform
            )
        } else {
            mutablePath.addRect(
                CGRect(x: x, y: y, width: width, height: height),
                transform: currentTransform
            )
        }
        addShape(mutablePath, id: attributes["id"], fillRule: cgFillRule(from: attributes["fill-rule"]))
    }

    private func handlePolygon(attributes: [String: String], parser: XMLParser) {
        guard let pointsStr = attributes["points"] else { return }

        let numbers = tokenizeNumbers(pointsStr)
        guard numbers.count >= 4, numbers.count % 2 == 0 else {
            parseError = .invalidPathData("polygon 'points' attribute has an odd or insufficient number of coordinates")
            parser.abortParsing()
            return
        }

        let mutablePath = CGMutablePath()
        mutablePath.move(to: CGPoint(x: numbers[0], y: numbers[1]), transform: currentTransform)
        var i = 2
        while i + 1 < numbers.count {
            mutablePath.addLine(to: CGPoint(x: numbers[i], y: numbers[i + 1]), transform: currentTransform)
            i += 2
        }
        mutablePath.closeSubpath()

        addShape(mutablePath, id: attributes["id"], fillRule: cgFillRule(from: attributes["fill-rule"]))
    }

    // MARK: - Shape registration helper

    private func addShape(_ path: CGMutablePath, id: String?, fillRule: CGPathFillRule) {
        let immutable = path.copy()!
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
        guard nums.count == 4 else { return nil }
        return CGRect(x: nums[0], y: nums[1], width: nums[2], height: nums[3])
    }

    private func parseTranslateOnly(_ str: String) -> Result<CGAffineTransform, SVGParseError> {
        let trimmed = str.trimmingCharacters(in: .whitespaces)

        // Reject any obviously unsupported transform function names.
        let unsupportedPrefixes = ["matrix", "rotate", "scale", "skewX", "skewY"]
        for prefix in unsupportedPrefixes {
            if trimmed.lowercased().hasPrefix(prefix) {
                return .failure(.unsupportedTransform(str))
            }
        }

        guard trimmed.lowercased().hasPrefix("translate") else {
            return .failure(.unsupportedTransform(str))
        }

        // Extract content between parentheses.
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

    /// Splits a string of SVG numbers separated by commas, whitespace, or implicit negative signs.
    private func tokenizeNumbers(_ str: String) -> [CGFloat] {
        var result: [CGFloat] = []
        var current = ""
        var hasDigit = false
        var hasDot   = false
        var hasE     = false

        func flush() {
            if !current.isEmpty, let v = Double(current) {
                result.append(CGFloat(v))
            }
            current = ""
            hasDigit = false
            hasDot   = false
            hasE     = false
        }

        for ch in str {
            switch ch {
            case " ", "\t", "\n", "\r", ",":
                flush()

            case "-", "+":
                // A sign character starts a new token unless it follows 'e'/'E' (exponent).
                if hasDigit && !hasE {
                    flush()
                }
                current.append(ch)

            case ".":
                if hasDot {
                    // Second dot in the same token → flush and start new token.
                    flush()
                }
                hasDot = true
                current.append(ch)

            case "e", "E":
                if hasDigit {
                    hasE = true
                    current.append(ch)
                }
                // If no digit yet, ignore silently (shouldn't happen in valid SVG).

            case "0"..."9":
                hasDigit = true
                current.append(ch)

            default:
                // Skip any stray characters (e.g., letters that aren't digits/e).
                flush()
            }
        }
        flush()
        return result
    }
}

// MARK: - Path builder

/// Parses an SVG `d` attribute string into a `CGPath`, applying `transform`.
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

    let path = CGMutablePath()

    // Current pen position (in user coordinates, before transform).
    var currentPoint  = CGPoint.zero
    // Last control point for smooth curves (S/s and T/t).
    var lastCubicCP2  = CGPoint.zero   // used by S/s
    var lastQuadCP    = CGPoint.zero   // used by T/t
    var lastCommand: Character = "M"

    // Start-of-subpath point (for Z close).
    var subpathStart  = CGPoint.zero

    var index = 0

    while index < tokens.count {
        let token = tokens[index]

        guard case .command(let cmd) = token else {
            return .failure(.invalidPathData("Expected command character, got number at position \(index)"))
        }
        index += 1

        // Arc rejection.
        if cmd == "A" || cmd == "a" {
            return .failure(.unsupportedArcCommand)
        }

        let isRelative = cmd.isLowercase
        let baseCmd    = cmd.uppercased().first!

        // How many parameters each command consumes per iteration.
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

        // Each command may be followed by implicit repetitions of its parameters.
        var firstIteration = true
        repeat {
            // Check we have enough parameters left.
            if paramCount > 0 {
                let remaining = tokens[index...].prefix(paramCount).filter {
                    if case .number = $0 { return true }
                    return false
                }.count
                if remaining < paramCount { break }
            }

            switch baseCmd {

            case "M":
                let x = number(tokens, index)
                let y = number(tokens, index + 1)
                index += 2
                let pt = isRelative
                    ? CGPoint(x: currentPoint.x + x, y: currentPoint.y + y)
                    : CGPoint(x: x, y: y)
                if firstIteration {
                    path.move(to: pt, transform: transform)
                } else {
                    // Implicit L after first M coordinate pair.
                    path.addLine(to: pt, transform: transform)
                }
                currentPoint = pt
                subpathStart = pt
                lastCubicCP2 = pt
                lastQuadCP   = pt

            case "L":
                let x = number(tokens, index)
                let y = number(tokens, index + 1)
                index += 2
                let pt = isRelative
                    ? CGPoint(x: currentPoint.x + x, y: currentPoint.y + y)
                    : CGPoint(x: x, y: y)
                path.addLine(to: pt, transform: transform)
                currentPoint = pt
                lastCubicCP2 = pt
                lastQuadCP   = pt

            case "H":
                let x = number(tokens, index)
                index += 1
                let pt = CGPoint(
                    x: isRelative ? currentPoint.x + x : x,
                    y: currentPoint.y
                )
                path.addLine(to: pt, transform: transform)
                currentPoint = pt
                lastCubicCP2 = pt
                lastQuadCP   = pt

            case "V":
                let y = number(tokens, index)
                index += 1
                let pt = CGPoint(
                    x: currentPoint.x,
                    y: isRelative ? currentPoint.y + y : y
                )
                path.addLine(to: pt, transform: transform)
                currentPoint = pt
                lastCubicCP2 = pt
                lastQuadCP   = pt

            case "C":
                let cp1x = number(tokens, index)
                let cp1y = number(tokens, index + 1)
                let cp2x = number(tokens, index + 2)
                let cp2y = number(tokens, index + 3)
                let ex   = number(tokens, index + 4)
                let ey   = number(tokens, index + 5)
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

            case "S":
                // Smooth cubic: implicit first control point is reflection of last cp2.
                let cp2x = number(tokens, index)
                let cp2y = number(tokens, index + 1)
                let ex   = number(tokens, index + 2)
                let ey   = number(tokens, index + 3)
                index += 4
                let cp2, end: CGPoint
                if isRelative {
                    cp2 = CGPoint(x: currentPoint.x + cp2x, y: currentPoint.y + cp2y)
                    end = CGPoint(x: currentPoint.x + ex,   y: currentPoint.y + ey)
                } else {
                    cp2 = CGPoint(x: cp2x, y: cp2y)
                    end = CGPoint(x: ex,   y: ey)
                }
                // If the previous command was C/c/S/s, reflect; otherwise cp1 = currentPoint.
                let cp1: CGPoint
                let prevUpper = lastCommand.uppercased().first!
                if prevUpper == "C" || prevUpper == "S" {
                    cp1 = CGPoint(
                        x: 2 * currentPoint.x - lastCubicCP2.x,
                        y: 2 * currentPoint.y - lastCubicCP2.y
                    )
                } else {
                    cp1 = currentPoint
                }
                path.addCurve(to: end, control1: cp1, control2: cp2, transform: transform)
                lastCubicCP2 = cp2
                currentPoint = end
                lastQuadCP   = end

            case "Q":
                let cpx = number(tokens, index)
                let cpy = number(tokens, index + 1)
                let ex  = number(tokens, index + 2)
                let ey  = number(tokens, index + 3)
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

            case "T":
                // Smooth quadratic: implicit control point is reflection of last quadratic cp.
                let ex = number(tokens, index)
                let ey = number(tokens, index + 1)
                index += 2
                let end: CGPoint = isRelative
                    ? CGPoint(x: currentPoint.x + ex, y: currentPoint.y + ey)
                    : CGPoint(x: ex, y: ey)
                let prevUpper = lastCommand.uppercased().first!
                let cp: CGPoint
                if prevUpper == "Q" || prevUpper == "T" {
                    cp = CGPoint(
                        x: 2 * currentPoint.x - lastQuadCP.x,
                        y: 2 * currentPoint.y - lastQuadCP.y
                    )
                } else {
                    cp = currentPoint
                }
                path.addQuadCurve(to: end, control: cp, transform: transform)
                lastQuadCP   = cp
                currentPoint = end
                lastCubicCP2 = end

            case "Z":
                path.closeSubpath()
                currentPoint = subpathStart
                lastCubicCP2 = subpathStart
                lastQuadCP   = subpathStart

            default:
                break
            }

            lastCommand   = cmd
            firstIteration = false

        } while paramCount > 0 && index < tokens.count && {
            // Continue implicit repetition as long as the next token is a number,
            // not another command letter (and we have enough numbers).
            if case .number = tokens[index] { return true }
            return false
        }()
    }

    return .success(path.copy()!)
}

// MARK: - Path token type

private enum PathToken {
    case command(Character)
    case number(CGFloat)
}

/// Lex an SVG `d` string into a flat array of command/number tokens.
/// Arc commands (A/a) are not rejected here — that happens in the builder.
private func tokenizePathData(_ d: String) throws -> [PathToken] {
    var tokens: [PathToken] = []

    let commandChars: Set<Character> = [
        "M","m","L","l","H","h","V","v",
        "C","c","S","s","Q","q","T","t",
        "A","a","Z","z"
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
            // A sign starts a new number unless it's part of an exponent.
            if hasDigit && !hasE {
                try flushNumber()
            }
            numBuf.append(ch)
        } else if ch == "." {
            if hasDot {
                // "0.5.3" → two numbers: 0.5 and .3
                try flushNumber()
            }
            hasDot = true
            numBuf.append(ch)
        } else if ch == "e" || ch == "E" {
            if hasDigit {
                hasE = true
                numBuf.append(ch)
            }
        } else if ch >= "0" && ch <= "9" {
            hasDigit = true
            numBuf.append(ch)
        }
        // Ignore any other characters silently.
    }
    try flushNumber()

    return tokens
}

// MARK: - Token access helpers

/// Extract a CGFloat from a `.number` token at `index`.
/// Returns 0 if the index is out of range or the token is not a number
/// (caller validates count before entering a command branch).
private func number(_ tokens: [PathToken], _ index: Int) -> CGFloat {
    guard index < tokens.count, case .number(let v) = tokens[index] else { return 0 }
    return v
}
