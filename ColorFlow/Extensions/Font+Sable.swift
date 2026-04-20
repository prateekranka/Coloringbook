import SwiftUI

extension Font {
    static let cfDisplayHero   = Font.custom("Fraunces", size: 40).bold()
    static let cfDisplayLarge  = Font.custom("Fraunces", size: 34).bold()
    static let cfTitleLarge    = Font.custom("Fraunces", size: 28).bold()
    static let cfTitle         = Font.custom("Fraunces", size: 22).bold()
    static let cfTitleSmall   = Font.title3.bold()
    static let cfHeadline     = Font.headline.bold()
    static let cfBody         = Font.body
    static let cfBodyEmphasis = Font.body.bold()
    static let cfSubheadline  = Font.subheadline.weight(.medium)
    static let cfFootnote     = Font.footnote
    static let cfCaption      = Font.caption
    static let cfCaptionBold  = Font.caption2.bold()
    static let cfMono         = Font.monospaced(.body)()
}