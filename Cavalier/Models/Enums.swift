import Foundation

enum DrawingMode: Int, Codable, CaseIterable, Identifiable {
    case waveBox = 0
    case levelsBox
    case particlesBox
    case barsBox
    case spineBox
    case splitterBox
    case waveCircle
    case levelsCircle
    case particlesCircle
    case barsCircle
    case spineCircle

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .waveBox: return "Wave (Box)"
        case .levelsBox: return "Levels (Box)"
        case .particlesBox: return "Particles (Box)"
        case .barsBox: return "Bars (Box)"
        case .spineBox: return "Spine (Box)"
        case .splitterBox: return "Splitter (Box)"
        case .waveCircle: return "Wave (Circle)"
        case .levelsCircle: return "Levels (Circle)"
        case .particlesCircle: return "Particles (Circle)"
        case .barsCircle: return "Bars (Circle)"
        case .spineCircle: return "Spine (Circle)"
        }
    }
}

enum DrawingDirection: Int, Codable, CaseIterable {
    case topBottom = 0
    case bottomTop
    case leftRight
    case rightLeft

    var isVertical: Bool { self == .topBottom || self == .bottomTop }
}

enum Mirror: Int, Codable, CaseIterable {
    case off = 0
    case full
    case splitChannels
}

enum Theme: Int, Codable, CaseIterable {
    case light = 0
    case dark
}
