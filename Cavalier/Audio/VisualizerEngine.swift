import Foundation
import Observation
import QuartzCore
import os

/// A pair of bar frames with timing, used by the renderer to interpolate
/// between consecutive audio updates.
struct BarFrame {
    var previous: [Float]
    var current: [Float]
    var publishTime: CFTimeInterval
    var interval: CFTimeInterval
}

/// Orchestrates the audio pipeline: pulls raw PCM from SystemAudioTap, batches into FFT frames,
/// runs AudioProcessor at the configured framerate, and publishes the latest bar frame.
@Observable
final class VisualizerEngine {
    static let shared = VisualizerEngine()

    private let log = Logger(subsystem: "com.zman.cavalier", category: "VisualizerEngine")
    private let tap = SystemAudioTap()
    // Per-channel FFT + EMA; shared autosens/monstercat to avoid a seam at the L/R boundary.
    private let processorL = AudioProcessor(fftSize: 4096)
    private let processorR = AudioProcessor(fftSize: 4096)
    private let finalizer = BarFinalizer()
    private let ringL = FloatRingBuffer(capacity: 48_000)
    private let ringR = FloatRingBuffer(capacity: 48_000)
    private let udpSink = UDPBarSink()
    private var timer: DispatchSourceTimer?
    private var sampleRate: Double = 48_000
    private var channels: Int = 2
    private var running = false

    private(set) var frame: BarFrame = BarFrame(previous: [], current: [], publishTime: 0, interval: 1.0 / 60)
    var statusMessage: String? = nil

    /// Measured bar-update rate (Hz). Updated once per second.
    private(set) var sampleHz: Double = 0
    private var tickCounter: Int = 0
    private var lastHzStamp: CFTimeInterval = 0

    private init() {}

    func start() {
        guard !running else { return }
        running = true
        do {
            try tap.start { [weak self] ptr, frameCount, channels, sampleRate in
                self?.handleSamples(ptr, frameCount: frameCount, channels: channels, sampleRate: sampleRate)
            }
            scheduleTimer()
            statusMessage = nil
            log.info("VisualizerEngine started")
        } catch {
            running = false
            statusMessage = "Audio capture unavailable: \(error)"
            log.error("Failed to start tap: \(String(describing: error))")
        }
    }

    func stop() {
        timer?.cancel()
        timer = nil
        tap.stop()
        running = false
    }

    private func handleSamples(_ ptr: UnsafePointer<Float>, frameCount: Int, channels: Int, sampleRate: Double) {
        self.sampleRate = sampleRate
        self.channels = channels
        if channels == 1 {
            ringL.write(ptr, count: frameCount)
        } else {
            var l = [Float](repeating: 0, count: frameCount)
            var r = [Float](repeating: 0, count: frameCount)
            for f in 0..<frameCount {
                l[f] = ptr[f * channels]
                r[f] = ptr[f * channels + 1]
            }
            l.withUnsafeBufferPointer { ringL.write($0.baseAddress!, count: frameCount) }
            r.withUnsafeBufferPointer { ringR.write($0.baseAddress!, count: frameCount) }
        }
    }

    private func scheduleTimer() {
        timer?.cancel()
        let fps = max(15, Configuration.shared.framerate)
        // Use nanoseconds for accurate period — milliseconds truncates (1000/60 → 16ms = 62.5Hz).
        let nsPeriod = 1_000_000_000 / Int(fps)
        let interval = DispatchTimeInterval.nanoseconds(nsPeriod)
        let t = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInteractive))
        t.schedule(deadline: .now() + .milliseconds(50), repeating: interval, leeway: .microseconds(500))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    private func tick() {
        let config = Configuration.shared
        let nBars = Int(config.barPairs)
        var frameL = [Float](repeating: 0, count: 4096)
        guard ringL.readLatest(&frameL, count: 4096) else { return }
        let combined: [Float]
        if config.stereo && channels >= 2 {
            var frameR = [Float](repeating: 0, count: 4096)
            _ = ringR.readLatest(&frameR, count: 4096)
            let left = processorL.spectrum(frame: frameL, sampleRate: sampleRate, nBars: nBars, config: config)
            let right = processorR.spectrum(frame: frameR, sampleRate: sampleRate, nBars: nBars, config: config)
            combined = config.reverseOrder ? left.reversed() + right : left + right
        } else {
            let mono = processorL.spectrum(frame: frameL, sampleRate: sampleRate, nBars: nBars, config: config)
            combined = config.reverseOrder ? mono.reversed() : mono
        }
        let bars = finalizer.finalize(bars: combined, config: config)
        if config.udpBridgeEnabled { udpSink?.send(bars: bars) }
        let now = CACurrentMediaTime()
        if lastHzStamp == 0 { lastHzStamp = now }
        tickCounter += 1
        let elapsed = now - lastHzStamp
        let measured: Double? = elapsed >= 1.0 ? Double(tickCounter) / elapsed : nil
        if measured != nil {
            tickCounter = 0
            lastHzStamp = now
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let prev = self.frame.current
            let prevTime = self.frame.publishTime
            let newInterval: CFTimeInterval
            if prevTime > 0 {
                let delta = now - prevTime
                newInterval = self.frame.interval * 0.8 + delta * 0.2
            } else {
                newInterval = 1.0 / Double(Configuration.shared.framerate)
            }
            self.frame = BarFrame(
                previous: prev.isEmpty ? bars : prev,
                current: bars,
                publishTime: now,
                interval: max(0.001, newInterval))
            if let hz = measured { self.sampleHz = hz }
        }
    }

    /// Return a bar frame interpolated between previous and current samples based on now.
    func interpolatedBars(now: CFTimeInterval) -> [Float] {
        let f = frame
        guard !f.current.isEmpty else { return [] }
        if f.previous.isEmpty || f.previous.count != f.current.count {
            return f.current
        }
        let alpha = Float(max(0, min(1, (now - f.publishTime) / f.interval)))
        var out = [Float](repeating: 0, count: f.current.count)
        for i in 0..<f.current.count {
            out[i] = f.previous[i] * (1 - alpha) + f.current[i] * alpha
        }
        return out
    }
}
