import Foundation

struct ColorPreset: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let fgColors: [String]
    let bgColors: [String]
    let theme: Theme

    func asProfile() -> ColorProfile {
        ColorProfile(name: name, fgColors: fgColors, bgColors: bgColors, theme: theme)
    }
}

enum ColorPresets {
    static let all: [ColorPreset] = [
        ColorPreset(name: "Classic",
                    fgColors: ["#ff3584e4"],
                    bgColors: ["#ff242424"],
                    theme: .dark),

        ColorPreset(name: "Sunset",
                    fgColors: ["#ffffe066", "#ffffa94d", "#ffff6b6b", "#ffd63384"],
                    bgColors: ["#ff1a1a2e", "#ff16213e"],
                    theme: .dark),

        ColorPreset(name: "Ocean",
                    fgColors: ["#ff00f5ff", "#ff0093e9", "#ff0050d4"],
                    bgColors: ["#ff001e3c"],
                    theme: .dark),

        ColorPreset(name: "Synthwave",
                    fgColors: ["#ffff006e", "#ffd500f9", "#ff7209b7"],
                    bgColors: ["#ff10002b", "#ff240046"],
                    theme: .dark),

        ColorPreset(name: "Forest",
                    fgColors: ["#ff7fff00", "#ff00c853", "#ff00796b"],
                    bgColors: ["#ff0a1f0a"],
                    theme: .dark),

        ColorPreset(name: "Fire",
                    fgColors: ["#ffffff00", "#ffff8c00", "#ffff0000"],
                    bgColors: ["#ff1a0000"],
                    theme: .dark),

        ColorPreset(name: "Nord",
                    fgColors: ["#ff88c0d0", "#ff81a1c1", "#ff5e81ac"],
                    bgColors: ["#ff2e3440"],
                    theme: .dark),

        ColorPreset(name: "Dracula",
                    fgColors: ["#ffff79c6", "#ffbd93f9", "#ff8be9fd"],
                    bgColors: ["#ff282a36"],
                    theme: .dark),

        ColorPreset(name: "Mono",
                    fgColors: ["#ffffffff", "#ffaaaaaa"],
                    bgColors: ["#ff000000"],
                    theme: .dark),

        ColorPreset(name: "Matrix",
                    fgColors: ["#ff00ff41", "#ff008f11"],
                    bgColors: ["#ff0d0208"],
                    theme: .dark),

        ColorPreset(name: "Rainbow",
                    fgColors: ["#ffff2e63", "#ffff9e00", "#ffffee00",
                               "#ff00f0a0", "#ff00b8ff", "#ff9d00ff"],
                    bgColors: ["#ff000000"],
                    theme: .dark),

        ColorPreset(name: "Pastel",
                    fgColors: ["#ffffd6e0", "#ffc9e4de", "#ffc6def1", "#ffdbcdf0"],
                    bgColors: ["#ff2d2d3a"],
                    theme: .dark),

        ColorPreset(name: "Amber",
                    fgColors: ["#ffffd54f", "#ffff8f00"],
                    bgColors: ["#ff1c1c1c"],
                    theme: .dark),

        ColorPreset(name: "Solarized",
                    fgColors: ["#ffb58900", "#ffcb4b16", "#ffd33682"],
                    bgColors: ["#ff002b36", "#ff073642"],
                    theme: .dark),

        ColorPreset(name: "Ice",
                    fgColors: ["#ffffffff", "#ffa8dadc", "#ff457b9d"],
                    bgColors: ["#ff1d3557"],
                    theme: .dark),
    ]
}
