import SwiftUI
import Combine

enum ThemeAppearance: String, CaseIterable, Hashable {
    case system
    case light
    case dark
}

enum ThemeAccent: String, CaseIterable, Hashable {
    case purple, blue, pink, violet, indigo, orange, teal, bronze, black, mint

    var color: Color {
        switch self {
        case .purple: return .purple
        case .blue: return .blue
        case .pink: return .pink
        case .violet: return Color(hue: 0.77, saturation: 0.35, brightness: 0.85)
        case .indigo: return .indigo
        case .orange: return .orange
        case .teal: return .teal
        case .bronze: return Color(red: 205/255, green: 127/255, blue: 50/255)
        case .black: return .black
        case .mint: return .mint
        }
    }
}

final class ThemeManager: ObservableObject {
    @Published var appearance: ThemeAppearance { didSet { save() } }
    @Published var accent: ThemeAccent { didSet { save() } }

    var colorScheme: ColorScheme? {
        switch appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var accentColor: Color { accent.color }

    init() {
        let aRaw = UserDefaults.standard.string(forKey: "theme.appearance")
        let cRaw = UserDefaults.standard.string(forKey: "theme.accent")
        appearance = ThemeAppearance(rawValue: aRaw ?? "system") ?? .system
        accent = ThemeAccent(rawValue: cRaw ?? "blue") ?? .blue
    }

    private func save() {
        UserDefaults.standard.set(appearance.rawValue, forKey: "theme.appearance")
        UserDefaults.standard.set(accent.rawValue, forKey: "theme.accent")
    }
}
