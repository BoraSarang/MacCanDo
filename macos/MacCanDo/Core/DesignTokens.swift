// [FEATURE] 디자인 토큰 — T-05b/T-06
// 웹과 동일한 MacCanDo 브랜드: 블루 #007AFF → 퍼플 #AF52DE, 시스템 다크모드 대응
import SwiftUI

extension Color {
    init(light: NSColor, dark: NSColor) {
        self.init(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }))
    }

    // ---- Primitive ----
    static let dsBlue = Color(light: NSColor(red: 0, green: 0.478, blue: 1, alpha: 1),       // #007AFF
                              dark: NSColor(red: 0.039, green: 0.518, blue: 1, alpha: 1))    // #0A84FF
    static let dsPurple = Color(light: NSColor(red: 0.686, green: 0.322, blue: 0.871, alpha: 1), // #AF52DE
                                dark: NSColor(red: 0.749, green: 0.353, blue: 0.949, alpha: 1))  // #BF5AF2
    static let dsGreen = Color(light: NSColor(red: 0.114, green: 0.541, blue: 0.306, alpha: 1),  // #1D8A4E
                               dark: NSColor(red: 0.188, green: 0.82, blue: 0.345, alpha: 1))    // #30D158
    static let dsRed = Color(light: NSColor(red: 0.843, green: 0, blue: 0.082, alpha: 1),        // #D70015
                             dark: NSColor(red: 1, green: 0.271, blue: 0.227, alpha: 1))         // #FF453A
    static let dsAmber = Color(light: NSColor(red: 0.698, green: 0.314, blue: 0, alpha: 1),      // #B25000
                               dark: NSColor(red: 1, green: 0.839, blue: 0.039, alpha: 1))       // #FFD60A

    // ---- Semantic ----
    static let dsPrimary = Color.dsBlue
    static let dsAccent = Color.dsPurple
    static let dsSuccess = Color.dsGreen
    static let dsDanger = Color.dsRed
    static let dsWarning = Color.dsAmber

    static let dsText = Color(light: .textColor, dark: .textColor)
    static let dsTextSecondary = Color(light: .secondaryLabelColor, dark: .secondaryLabelColor)
    static let dsTextMuted = Color(light: .tertiaryLabelColor, dark: .tertiaryLabelColor)
    static let dsSurface = Color(nsColor: .controlBackgroundColor)
    static let dsSurfaceHover = Color(nsColor: .selectedControlColor)

    // 브랜드 그라디언트
    static let dsBrandGradient = LinearGradient(
        colors: [Color.dsBlue, Color.dsPurple],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// ---- Spacing (4px 그리드) ----
enum Spacing {
    static let xxs: CGFloat = 4
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
}

// ---- Radius ----
enum Radius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
}

// ---- Typography ----
extension Font {
    static let dsTitle = Font.system(size: 20, weight: .bold)
    static let dsBody = Font.system(size: 13)
    static let dsCaption = Font.system(size: 11)
    static let dsMono = Font.system(size: 12, design: .monospaced)
}