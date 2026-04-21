import Accelerate
import Foundation

/// Per-channel FFT + log-binning + temporal smoothing.
/// Does NOT apply autosens or monstercat — those run on the combined L+R array
/// so the center of the visualization doesn't get a seam between the two channels.
final class AudioProcessor {
    private let fftSize: Int
    private let log2N: vDSP_Length
    private let setup: vDSP.FFT<DSPSplitComplex>
    private var window: [Float]
    private var real: [Float]
    private var imag: [Float]
    private var prevBars: [Float] = []

    init(fftSize: Int = 4096) {
        self.fftSize = fftSize
        self.log2N = vDSP_Length(log2(Double(fftSize)))
        self.setup = vDSP.FFT(log2n: log2N, radix: .radix2, ofType: DSPSplitComplex.self)!
        var w = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&w, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        self.window = w
        self.real = [Float](repeating: 0, count: fftSize / 2)
        self.imag = [Float](repeating: 0, count: fftSize / 2)
    }

    /// Returns raw temporal-smoothed magnitudes for `nBars` log-spaced bins.
    /// Output is NOT normalized to 0..1 — caller runs autosens/sensitivity on the combined stereo array.
    func spectrum(frame: [Float], sampleRate: Double, nBars: Int, config: Configuration) -> [Float] {
        precondition(frame.count == fftSize, "AudioProcessor.spectrum: wrong frame size")

        var windowed = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(frame, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var complex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                windowed.withUnsafeBufferPointer { wp in
                    wp.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { typed in
                        vDSP_ctoz(typed, 2, &complex, 1, vDSP_Length(fftSize / 2))
                    }
                }
                setup.forward(input: complex, output: &complex)
            }
        }

        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var complex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                vDSP_zvmags(&complex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
            }
        }
        var sqrtMag = [Float](repeating: 0, count: fftSize / 2)
        var n = Int32(fftSize / 2)
        vvsqrtf(&sqrtMag, magnitudes, &n)

        let minFreq: Float = 30
        let maxFreq: Float = min(16_000, Float(sampleRate) / 2 - 1)
        let nyquist = Float(sampleRate) / 2
        var bars = [Float](repeating: 0, count: nBars)
        for i in 0..<nBars {
            let fLo = minFreq * pow(maxFreq / minFreq, Float(i) / Float(nBars))
            let fHi = minFreq * pow(maxFreq / minFreq, Float(i + 1) / Float(nBars))
            let lo = max(1, Int((fLo / nyquist) * Float(fftSize / 2)))
            let hi = max(lo + 1, min(fftSize / 2, Int((fHi / nyquist) * Float(fftSize / 2))))
            var sum: Float = 0
            for j in lo..<hi { sum += sqrtMag[j] }
            bars[i] = sum / Float(hi - lo)
        }

        // Per-channel temporal EMA (noise reduction).
        if prevBars.count != nBars { prevBars = [Float](repeating: 0, count: nBars) }
        let alpha = max(0, min(0.95, config.noiseReduction))
        for i in 0..<nBars {
            bars[i] = prevBars[i] * alpha + bars[i] * (1 - alpha)
        }
        prevBars = bars
        return bars
    }
}

/// Shared normalization + spread + gravity across the concatenated stereo bars array.
/// Prevents a visible seam between L and R halves at the center of the visualizer,
/// and applies CAVA-style gravity so rock/percussive music doesn't strobe.
final class BarFinalizer {
    private var peak: Float = 1.0
    private var displayedBars: [Float] = []

    func finalize(bars inputBars: [Float], config: Configuration) -> [Float] {
        var bars = inputBars

        // --- Autosens / sensitivity with slow attack so a single transient
        // doesn't hijack the gain for a second. Decay stays slow.
        if config.autosens {
            let frameMax = bars.max() ?? 0
            if frameMax > peak {
                peak = peak * 0.85 + frameMax * 0.15   // slow attack
            } else {
                peak = peak * 0.995 + frameMax * 0.005 // slow decay
            }
            let norm = max(peak, 0.0001)
            for i in bars.indices { bars[i] = min(1, bars[i] / norm) }
        } else {
            let scale = Float(config.sensitivity) / 10
            for i in bars.indices { bars[i] = min(1, bars[i] * scale) }
        }

        // --- Monstercat spread across the whole array so the L/R boundary
        // benefits from both channels' energy.
        if config.monstercat && bars.count > 1 {
            let factor: Float = 1.5
            var smoothed = bars
            for i in bars.indices {
                for j in bars.indices where j != i {
                    let pull = bars[i] / pow(factor, Float(abs(i - j)))
                    if pull > smoothed[j] { smoothed[j] = pull }
                }
            }
            bars = smoothed
        }

        // --- Gravity: instant rise, fall-rate-limited drop. CAVA-style.
        // gravity is in full-scale units per second; convert to per-frame.
        if displayedBars.count != bars.count {
            displayedBars = bars
        } else {
            let fps = max(1, Float(config.framerate))
            let maxDrop = max(0, config.gravity) / fps
            for i in bars.indices {
                if bars[i] >= displayedBars[i] {
                    displayedBars[i] = bars[i]
                } else {
                    displayedBars[i] = max(bars[i], displayedBars[i] - maxDrop)
                }
            }
            bars = displayedBars
        }
        return bars
    }
}
