import Foundation
import Observation

@Observable
final class Configuration: Codable {
    var windowWidth: UInt = 500
    var windowHeight: UInt = 300
    var windowMaximized: Bool = false
    var areaMargin: UInt = 0
    var areaOffsetX: Float = 0
    var areaOffsetY: Float = 0
    var borderless: Bool = false
    var sharpCorners: Bool = false
    var showControls: Bool = true
    var autohideHeader: Bool = false
    var framerate: UInt = 60
    var barPairs: UInt = 6
    var autosens: Bool = true
    var sensitivity: UInt = 10
    var stereo: Bool = true
    var monstercat: Bool = true
    var noiseReduction: Float = 0.77
    var reverseOrder: Bool = true
    var direction: DrawingDirection = .bottomTop
    var itemsOffset: Float = 0.1
    var itemsRoundness: Float = 0.5
    var filling: Bool = true
    var linesThickness: Float = 5
    var mode: DrawingMode = .waveBox
    var mirror: Mirror = .off
    var reverseMirror: Bool = false
    var innerRadius: Float = 0.5
    var rotation: Float = 0
    var colorProfiles: [ColorProfile] = [ColorProfile()]
    var activeProfile: Int = 0
    var bgImageIndex: Int = -1
    var bgImageScale: Float = 1
    var bgImageAlpha: Float = 1
    var fgImageIndex: Int = -1
    var fgImageScale: Float = 1
    var fgImageAlpha: Float = 1

    var hearts: Bool = false
    var showFPS: Bool = true
    var alwaysOnTop: Bool = true
    /// Bar fall speed (full-scale drops per second). 0 = instant snap, higher = slower fall (heavier gravity hold).
    var gravity: Float = 1.5
    /// Path to a user-selected background image, or empty. Overrides bgImageIndex.
    var bgImagePath: String = ""
    /// Path to a user-selected foreground image (clipped to the bar shape), or empty. Overrides fgImageIndex.
    var fgImagePath: String = ""

    enum CodingKeys: String, CodingKey {
        case windowWidth, windowHeight, windowMaximized, areaMargin
        case areaOffsetX, areaOffsetY, borderless, sharpCorners
        case showControls, autohideHeader, framerate, barPairs
        case autosens, sensitivity, stereo, monstercat, noiseReduction
        case reverseOrder, direction, itemsOffset, itemsRoundness
        case filling, linesThickness, mode, mirror, reverseMirror
        case innerRadius, rotation, colorProfiles, activeProfile
        case bgImageIndex, bgImageScale, bgImageAlpha
        case fgImageIndex, fgImageScale, fgImageAlpha
        case showFPS
        case alwaysOnTop
        case gravity
        case bgImagePath, fgImagePath
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        windowWidth = (try? c.decode(UInt.self, forKey: .windowWidth)) ?? 500
        windowHeight = (try? c.decode(UInt.self, forKey: .windowHeight)) ?? 300
        windowMaximized = (try? c.decode(Bool.self, forKey: .windowMaximized)) ?? false
        areaMargin = (try? c.decode(UInt.self, forKey: .areaMargin)) ?? 0
        areaOffsetX = (try? c.decode(Float.self, forKey: .areaOffsetX)) ?? 0
        areaOffsetY = (try? c.decode(Float.self, forKey: .areaOffsetY)) ?? 0
        borderless = (try? c.decode(Bool.self, forKey: .borderless)) ?? false
        sharpCorners = (try? c.decode(Bool.self, forKey: .sharpCorners)) ?? false
        showControls = (try? c.decode(Bool.self, forKey: .showControls)) ?? true
        autohideHeader = (try? c.decode(Bool.self, forKey: .autohideHeader)) ?? false
        framerate = (try? c.decode(UInt.self, forKey: .framerate)) ?? 60
        barPairs = (try? c.decode(UInt.self, forKey: .barPairs)) ?? 6
        autosens = (try? c.decode(Bool.self, forKey: .autosens)) ?? true
        sensitivity = (try? c.decode(UInt.self, forKey: .sensitivity)) ?? 10
        stereo = (try? c.decode(Bool.self, forKey: .stereo)) ?? true
        monstercat = (try? c.decode(Bool.self, forKey: .monstercat)) ?? true
        noiseReduction = (try? c.decode(Float.self, forKey: .noiseReduction)) ?? 0.77
        reverseOrder = (try? c.decode(Bool.self, forKey: .reverseOrder)) ?? true
        direction = (try? c.decode(DrawingDirection.self, forKey: .direction)) ?? .bottomTop
        itemsOffset = (try? c.decode(Float.self, forKey: .itemsOffset)) ?? 0.1
        itemsRoundness = (try? c.decode(Float.self, forKey: .itemsRoundness)) ?? 0.5
        filling = (try? c.decode(Bool.self, forKey: .filling)) ?? true
        linesThickness = (try? c.decode(Float.self, forKey: .linesThickness)) ?? 5
        mode = (try? c.decode(DrawingMode.self, forKey: .mode)) ?? .waveBox
        mirror = (try? c.decode(Mirror.self, forKey: .mirror)) ?? .off
        reverseMirror = (try? c.decode(Bool.self, forKey: .reverseMirror)) ?? false
        innerRadius = (try? c.decode(Float.self, forKey: .innerRadius)) ?? 0.5
        rotation = (try? c.decode(Float.self, forKey: .rotation)) ?? 0
        let profiles = (try? c.decode([ColorProfile].self, forKey: .colorProfiles)) ?? [ColorProfile()]
        colorProfiles = profiles.isEmpty ? [ColorProfile()] : profiles
        activeProfile = (try? c.decode(Int.self, forKey: .activeProfile)) ?? 0
        bgImageIndex = (try? c.decode(Int.self, forKey: .bgImageIndex)) ?? -1
        bgImageScale = (try? c.decode(Float.self, forKey: .bgImageScale)) ?? 1
        bgImageAlpha = (try? c.decode(Float.self, forKey: .bgImageAlpha)) ?? 1
        fgImageIndex = (try? c.decode(Int.self, forKey: .fgImageIndex)) ?? -1
        fgImageScale = (try? c.decode(Float.self, forKey: .fgImageScale)) ?? 1
        fgImageAlpha = (try? c.decode(Float.self, forKey: .fgImageAlpha)) ?? 1
        showFPS = (try? c.decode(Bool.self, forKey: .showFPS)) ?? true
        alwaysOnTop = (try? c.decode(Bool.self, forKey: .alwaysOnTop)) ?? true
        gravity = (try? c.decode(Float.self, forKey: .gravity)) ?? 1.5
        bgImagePath = (try? c.decode(String.self, forKey: .bgImagePath)) ?? ""
        fgImagePath = (try? c.decode(String.self, forKey: .fgImagePath)) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(windowWidth, forKey: .windowWidth)
        try c.encode(windowHeight, forKey: .windowHeight)
        try c.encode(windowMaximized, forKey: .windowMaximized)
        try c.encode(areaMargin, forKey: .areaMargin)
        try c.encode(areaOffsetX, forKey: .areaOffsetX)
        try c.encode(areaOffsetY, forKey: .areaOffsetY)
        try c.encode(borderless, forKey: .borderless)
        try c.encode(sharpCorners, forKey: .sharpCorners)
        try c.encode(showControls, forKey: .showControls)
        try c.encode(autohideHeader, forKey: .autohideHeader)
        try c.encode(framerate, forKey: .framerate)
        try c.encode(barPairs, forKey: .barPairs)
        try c.encode(autosens, forKey: .autosens)
        try c.encode(sensitivity, forKey: .sensitivity)
        try c.encode(stereo, forKey: .stereo)
        try c.encode(monstercat, forKey: .monstercat)
        try c.encode(noiseReduction, forKey: .noiseReduction)
        try c.encode(reverseOrder, forKey: .reverseOrder)
        try c.encode(direction, forKey: .direction)
        try c.encode(itemsOffset, forKey: .itemsOffset)
        try c.encode(itemsRoundness, forKey: .itemsRoundness)
        try c.encode(filling, forKey: .filling)
        try c.encode(linesThickness, forKey: .linesThickness)
        try c.encode(mode, forKey: .mode)
        try c.encode(mirror, forKey: .mirror)
        try c.encode(reverseMirror, forKey: .reverseMirror)
        try c.encode(innerRadius, forKey: .innerRadius)
        try c.encode(rotation, forKey: .rotation)
        try c.encode(colorProfiles, forKey: .colorProfiles)
        try c.encode(activeProfile, forKey: .activeProfile)
        try c.encode(bgImageIndex, forKey: .bgImageIndex)
        try c.encode(bgImageScale, forKey: .bgImageScale)
        try c.encode(bgImageAlpha, forKey: .bgImageAlpha)
        try c.encode(fgImageIndex, forKey: .fgImageIndex)
        try c.encode(fgImageScale, forKey: .fgImageScale)
        try c.encode(fgImageAlpha, forKey: .fgImageAlpha)
        try c.encode(showFPS, forKey: .showFPS)
        try c.encode(alwaysOnTop, forKey: .alwaysOnTop)
        try c.encode(gravity, forKey: .gravity)
        try c.encode(bgImagePath, forKey: .bgImagePath)
        try c.encode(fgImagePath, forKey: .fgImagePath)
    }

    var currentProfile: ColorProfile {
        let idx = min(max(0, activeProfile), colorProfiles.count - 1)
        return colorProfiles[idx]
    }

    static let shared: Configuration = Configuration.load()

    static var supportDir: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("Cavalier", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var configURL: URL { supportDir.appendingPathComponent("config.json") }

    static var imagesDir: URL {
        let dir = supportDir.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func load() -> Configuration {
        guard let data = try? Data(contentsOf: configURL),
              let cfg = try? JSONDecoder().decode(Configuration.self, from: data)
        else { return Configuration() }
        return cfg
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self) else { return }
        try? data.write(to: Self.configURL, options: .atomic)
    }
}
