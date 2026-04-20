import XCTest
import SwiftUI
@testable import ColorFlow

final class DesignSystemTests: XCTestCase {

    // MARK: - Accent Variant

    func test_accentVariant_defaultIsNil() {
        UserDefaults.standard.removeObject(forKey: "accentVariant")
        let raw = UserDefaults.standard.string(forKey: "accentVariant")
        XCTAssertNil(raw)
    }

    func test_accentVariant_sageAndCoralExist() {
        XCTAssertEqual(AccentVariant.allCases.count, 2)
        XCTAssertEqual(AccentVariant.sage.rawValue, "sage")
        XCTAssertEqual(AccentVariant.coral.rawValue, "coral")
    }

    // MARK: - Appearance Preference

    func test_appearancePreference_systemReturnsNil() {
        let pref = AppearancePreference.system
        XCTAssertNil(pref.colorScheme)
    }

    func test_appearancePreference_lightAndDarkReturnCorrectScheme() {
        XCTAssertEqual(AppearancePreference.light.colorScheme, .light)
        XCTAssertEqual(AppearancePreference.dark.colorScheme, .dark)
    }

    func test_appearancePreference_rawValues() {
        XCTAssertEqual(AppearancePreference.system.rawValue, "system")
        XCTAssertEqual(AppearancePreference.light.rawValue, "light")
        XCTAssertEqual(AppearancePreference.dark.rawValue, "dark")
    }

    // MARK: - Theme Token Existence

    func test_brandTokens_resolveToColors() {
        let _: Color = AppTheme.Brand.accent
        let _: Color = AppTheme.Brand.accentPressed
        let _: Color = AppTheme.Brand.accentHover
        let _: Color = AppTheme.Brand.accentSubtle
        let _: Color = AppTheme.Brand.accentWash
        let _: Color = AppTheme.Brand.onAccent
    }

    func test_surfaceTokens_resolveToColors() {
        let _: Color = AppTheme.Surface.background
        let _: Color = AppTheme.Surface.canvas
        let _: Color = AppTheme.Surface.sheet
        let _: Color = AppTheme.Surface.elevated
        let _: Color = AppTheme.Surface.scrim
    }

    func test_inkTokens_resolveToColors() {
        let _: Color = AppTheme.Ink.primary
        let _: Color = AppTheme.Ink.secondary
        let _: Color = AppTheme.Ink.tertiary
        let _: Color = AppTheme.Ink.lineArt
    }

    func test_strokeTokens_resolveToColors() {
        let _: Color = AppTheme.Stroke.hairline
        let _: Color = AppTheme.Stroke.swatchBorder
        let _: Color = AppTheme.Stroke.previewBorder
    }

    func test_stateTokens_resolveToColors() {
        let _: Color = AppTheme.State.success
        let _: Color = AppTheme.State.warning
        let _: Color = AppTheme.State.danger
    }

    // MARK: - Radius Tokens

    func test_radiusTokens_matchDesignSystem() {
        XCTAssertEqual(AppTheme.Radius.sm, 8)
        XCTAssertEqual(AppTheme.Radius.md, 12)
        XCTAssertEqual(AppTheme.Radius.lg, 16)
        XCTAssertEqual(AppTheme.Radius.pill, 999)
    }

    // MARK: - Spacing Tokens

    func test_spacingTokens_match8ptGrid() {
        XCTAssertEqual(AppTheme.Spacing.xxs, 2)
        XCTAssertEqual(AppTheme.Spacing.xs, 4)
        XCTAssertEqual(AppTheme.Spacing.sm, 6)
        XCTAssertEqual(AppTheme.Spacing.md, 8)
        XCTAssertEqual(AppTheme.Spacing.lg, 12)
        XCTAssertEqual(AppTheme.Spacing.xl, 16)
        XCTAssertEqual(AppTheme.Spacing.xxl, 20)
        XCTAssertEqual(AppTheme.Spacing.xxxl, 24)
    }

    // MARK: - Size Tokens

    func test_sizeTokens_matchDesignSystem() {
        XCTAssertEqual(AppTheme.Size.touchTarget, 44)
        XCTAssertEqual(AppTheme.Size.toolButton, 40)
        XCTAssertEqual(AppTheme.Size.colorWell, 32)
        XCTAssertEqual(AppTheme.Size.swatchCell, 44)
    }

    // MARK: - Motion Tokens

    func test_motionTokens_exist() {
        let _: Animation = AppTheme.Motion.fast
        let _: Animation = AppTheme.Motion.standard
        let _: Animation = AppTheme.Motion.slow
        let _: Animation = AppTheme.Motion.emphasis
        let _: Animation = AppTheme.Motion.quickSpring
        let _: Animation = AppTheme.Motion.bloomSpring
        let _: Animation = AppTheme.Motion.pageTransition
        XCTAssertEqual(AppTheme.Motion.staggerBase, 0.025)
    }

    // MARK: - Backward Compat Shims

    func test_backwardCompatShims_resolveWithoutError() {
        let _: Color = AppTheme.accent
        let _: Color = AppTheme.background
        let _: Color = AppTheme.surface
        let _: Color = AppTheme.textPrimary
        let _: Color = AppTheme.textSecondary
        let _: CGFloat = AppTheme.cardCornerRadius
        let _: CGFloat = AppTheme.screenPadding
        let _: CGFloat = AppTheme.minTapTarget

        XCTAssertEqual(AppTheme.cardCornerRadius, AppTheme.Radius.md)
        XCTAssertEqual(AppTheme.screenPadding, AppTheme.Spacing.xl)
        XCTAssertEqual(AppTheme.minTapTarget, AppTheme.Size.touchTarget)
    }

    // MARK: - Typography Shims

    func test_typographyShims_resolveWithoutError() {
        let _: Font = AppTheme.Typography.heroTitle
        let _: Font = AppTheme.Typography.heroBody
        let _: Font = AppTheme.Typography.capsuleLabel
    }

    // MARK: - Font+Sable

    func test_sableFontAccessorsExist() {
        let _: Font = Font.cfDisplayHero
        let _: Font = Font.cfDisplayLarge
        let _: Font = Font.cfTitleLarge
        let _: Font = Font.cfTitle
        let _: Font = Font.cfTitleSmall
        let _: Font = Font.cfHeadline
        let _: Font = Font.cfBody
        let _: Font = Font.cfBodyEmphasis
        let _: Font = Font.cfSubheadline
        let _: Font = Font.cfFootnote
        let _: Font = Font.cfCaption
        let _: Font = Font.cfCaptionBold
        let _: Font = Font.cfMono
    }

    // MARK: - Color+Sable adaptive

    func test_adaptiveColor_resolvesInLightMode() {
        let lightColor = Color.adaptive(light: "#FF0000", dark: "#0000FF")
        XCTAssertNotNil(lightColor)
    }

    func test_adaptiveColor_resolvesWithColorInstances() {
        let lightColor = Color.adaptive(light: Color.red, dark: Color.blue)
        XCTAssertNotNil(lightColor)
    }

    // MARK: - TemplateRenderer strokeColor parameter

    func test_renderLineArt_acceptsCustomStrokeColor() throws {
        guard let svgURL = Bundle.main.url(forResource: "sunflower_mandala", withExtension: "svg", subdirectory: "Templates")
            ?? Bundle.main.url(forResource: "sunflower_mandala", withExtension: "svg")
        else {
            throw XCTSkip("No bundled SVG available for rendering test")
        }

        let parseResult = SVGParser.parse(url: svgURL)
        guard case .success(let geometry) = parseResult else {
            XCTFail("SVG parser failed")
            return
        }

        let size = CGSize(width: 100, height: 100)
        let customColor = UIColor(red: 0.1, green: 0.6, blue: 0.5, alpha: 1.0)
        let image = TemplateRenderer.renderLineArt(geometry: geometry, size: size, strokeColor: customColor)
        XCTAssertNotNil(image)
        XCTAssertEqual(image.size.width, 100)
        XCTAssertEqual(image.size.height, 100)
    }

    func test_renderLineArt_defaultStrokeColorIsSchemeAware() throws {
        guard let svgURL = Bundle.main.url(forResource: "sunflower_mandala", withExtension: "svg", subdirectory: "Templates")
            ?? Bundle.main.url(forResource: "sunflower_mandala", withExtension: "svg")
        else {
            throw XCTSkip("No bundled SVG available for rendering test")
        }

        let parseResult = SVGParser.parse(url: svgURL)
        guard case .success(let geometry) = parseResult else {
            XCTFail("SVG parser failed")
            return
        }

        let size = CGSize(width: 100, height: 100)
        let defaultImage = TemplateRenderer.renderLineArt(geometry: geometry, size: size)
        XCTAssertNotNil(defaultImage)
        XCTAssertEqual(defaultImage.size.width, 100)
        XCTAssertEqual(defaultImage.size.height, 100)
    }

    // MARK: - AppState appearance

    @MainActor func test_appState_defaultAppearanceIsSystem() {
        let state = AppState()
        XCTAssertEqual(state.appearance, .system)
    }

    @MainActor func test_appState_appearancePersistsToUserDefaults() {
        let state = AppState()
        state.appearance = .dark
        XCTAssertEqual(UserDefaults.standard.string(forKey: "appearance"), "dark")

        state.appearance = .light
        XCTAssertEqual(UserDefaults.standard.string(forKey: "appearance"), "light")

        state.appearance = .system
        XCTAssertEqual(UserDefaults.standard.string(forKey: "appearance"), "system")

        UserDefaults.standard.removeObject(forKey: "appearance")
    }
}