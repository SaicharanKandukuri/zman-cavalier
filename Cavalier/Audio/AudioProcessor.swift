import Accelerate
import Foundation

/// Converts raw PCM samples into normalized bar magnitudes.
/// Pipeline: window → FFT → log-bin → smoothing (monstercat) → noise reduction (EMA) → autosens/sensitivity.
final class AudioProcessor {
    private let fftSize: Int
    private let log2N: vDSP_Length
    private let setup: vDSP.FFT<DSPSplitComplex>
    private var window: [Float]
    private var real: [Float]
    private var imag: [Float]
    private var prevBars: [Float] = []
    private var peak: Float = 1.0

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

    /// Produce `nBars` normalized [0,1] bar values from the given time-domain frame.
    /// - Parameters:
    ///   - frame: Exactly `fftSize` samples (mono or summed stereo).
    ///   - sampleRate: Input sample rate in Hz.
    ///   - nBars: Number of output bars.
    ///   - config: Active configuration (for smoothing, noise reduction, sensitivity, autosens).
    func process(frame: [Float], sampleRate: Double, nBars: Int, config: Configuration) -> [Float] {
        precondition(frame.count == fftSize, "AudioProcessor.process: wrong frame size")

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

        // Log-spaced bin grouping
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

        // Sensitivity / autosens
        if config.autosens {
            let frameMax = bars.max() ?? 0
            // Track a slow-decay peak so autosens doesn't clip on transients but reacts to quiet periods.
            if frameMax > peak { peak = frameMax }
            else { peak = peak * 0.995 + frameMax * 0.005 }
            let norm = max(peak, 0.0001)
            for i in 0..<nBars { bars[i] = min(1, bars[i] / norm) }
        } else {
            let scale = Float(config.sensitivity) / 10
            for i in 0..<nBars { bars[i] = min(1, bars[i] * scale) }
        }

        // Noise reduction (temporal EMA). CAVA's noise_reduction ranges 0.15..0.95 and is smoothing weight on the previous frame.
        if prevBars.count != nBars { prevBars = [Float](repeating: 0, count: nBars) }
        let alpha = max(0, min(0.95, config.noiseReduction))
        for i in 0..<nBars {
            bars[i] = prevBars[i] * alpha + bars[i] * (1 - alpha)
        }

        // Monstercat smoothing: each bar pulls up its neighbors by a decreasing factor.
        if config.monstercat {
            let factor: Float = 1.5
            var smoothed = bars
            for i in 0..<nBars {
                for j in 0..<nBars where j != i {
                    let pull = bars[i] / pow(factor, Float(abs(i - j)))
                    if pull > smoothed[j] { smoothed[j] = pull }
                }
            }
            bars = smoothed
        }

        prevBars = bars
        return bars
    }
}
