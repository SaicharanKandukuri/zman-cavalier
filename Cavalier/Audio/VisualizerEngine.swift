import Foundation
import Observation
import os

/// Orchestrates the audio pipeline: pulls raw PCM from SystemAudioTap, batches into FFT frames,
/// runs AudioProcessor at the configured framerate, and publishes the latest bar frame.
@Observable
final class VisualizerEngine {
    static let shared = VisualizerEngine()

    private let log = Logger(subsystem: "com.zman.cavalier", category: "VisualizerEngine")
    private let tap = SystemAudioTap()
    private let processor = AudioProcessor(fftSize: 4096)
    private let ringL = FloatRingBuffer(capacity: 48_000)
    private let ringR = FloatRingBuffer(capacity: 48_000)
    private var timer: DispatchSourceTimer?
    private var sampleRate: Double = 48_000
    private var channels: Int = 2
    private var running = false

    /// Latest bar frame. For stereo, length = barPairs * 2 (L then R). For mono, length = barPairs.
    private(set) var latestBars: [Float] = []
    var statusMessage: String? = nil

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
            // De-interleave into L/R (assume channels >= 2, take first two)
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
        let interval = DispatchTimeInterval.milliseconds(Int(1000 / fps))
        let t = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInteractive))
        t.schedule(deadline: .now() + .milliseconds(50), repeating: interval, leeway: .milliseconds(2))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    private func tick() {
        let config = Configuration.shared
        let nBars = Int(config.barPairs)
        var frameL = [Float](repeating: 0, count: 4096)
        guard ringL.readLatest(&frameL, count: 4096) else { return }
        var bars: [Float]
        if config.stereo && channels >= 2 {
            var frameR = [Float](repeating: 0, count: 4096)
            _ = ringR.readLatest(&frameR, count: 4096)
            let left = processor.process(frame: frameL, sampleRate: sampleRate, nBars: nBars, config: config)
            let right = processor.process(frame: frameR, sampleRate: sampleRate, nBars: nBars, config: config)
            if config.reverseOrder {
                bars = left.reversed() + right
            } else {
                bars = left + right
            }
        } else {
            let mono = processor.process(frame: frameL, sampleRate: sampleRate, nBars: nBars, config: config)
            bars = config.reverseOrder ? mono.reversed() : mono
        }
        DispatchQueue.main.async { [weak self] in
            self?.latestBars = bars
        }
    }
}
