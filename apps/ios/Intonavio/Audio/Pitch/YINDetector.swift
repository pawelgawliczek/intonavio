import Accelerate
import Foundation

/// YIN pitch detection algorithm for monophonic audio.
///
/// Steps:
/// 1. Difference function d(tau)
/// 2. Cumulative mean normalized difference d'(tau)
/// 3. Absolute threshold — first tau where d'(tau) < threshold
/// 4. Parabolic interpolation for sub-sample accuracy
/// 5. frequency = sampleRate / interpolatedLag
struct YINDetector {
    let sampleRate: Float
    let threshold: Float
    let minLag: Int
    let maxLag: Int

    init(
        sampleRate: Float = PitchConstants.sampleRate,
        threshold: Float = PitchConstants.yinThreshold,
        minLag: Int = PitchConstants.minLag,
        maxLag: Int = PitchConstants.maxLag
    ) {
        self.sampleRate = sampleRate
        self.threshold = threshold
        self.minLag = minLag
        self.maxLag = maxLag
    }

    /// Detect pitch from a raw buffer pointer (no array copy).
    /// Returns (frequency, confidence) or nil if unvoiced.
    func detect(
        _ buffer: UnsafePointer<Float>,
        count: Int
    ) -> (Float, Float)? {
        let halfLen = count / 2
        guard maxLag < halfLen else { return nil }

        let diff = differenceFunction(buffer, halfLen: halfLen)
        let cmnd = cumulativeMeanNormalized(diff)

        guard let bestTau = findThresholdTau(cmnd) else {
            return nil
        }

        let refined = parabolicInterpolation(cmnd, tau: bestTau)
        let frequency = sampleRate / refined
        let confidence = 1.0 - cmnd[bestTau]

        guard frequency >= PitchConstants.minFrequency,
              frequency <= PitchConstants.maxFrequency else {
            return nil
        }

        return (frequency, confidence)
    }
}

// MARK: - YIN Steps

private extension YINDetector {
    /// Step 1: Difference function using Accelerate vDSP.
    func differenceFunction(
        _ samples: UnsafePointer<Float>,
        halfLen: Int
    ) -> [Float] {
        var diff = [Float](repeating: 0, count: halfLen)
        var delta = [Float](repeating: 0, count: halfLen)

        for tau in 1..<halfLen {
            let count = vDSP_Length(halfLen - tau)

            vDSP_vsub(
                samples + tau, 1,
                samples, 1,
                &delta, 1,
                count
            )

            var sum: Float = 0
            vDSP_dotpr(delta, 1, delta, 1, &sum, count)
            diff[tau] = sum
        }
        return diff
    }

    /// Step 2: Cumulative mean normalized difference.
    func cumulativeMeanNormalized(_ diff: [Float]) -> [Float] {
        var cmnd = [Float](repeating: 1.0, count: diff.count)
        var runningSum: Float = 0

        for tau in 1..<diff.count {
            runningSum += diff[tau]
            if runningSum > 0 {
                cmnd[tau] = diff[tau] * Float(tau) / runningSum
            } else {
                cmnd[tau] = 1.0
            }
        }
        return cmnd
    }

    /// Step 3: Find first tau in [minLag, maxLag] where
    /// d'(tau) < threshold, picking the local minimum.
    func findThresholdTau(_ cmnd: [Float]) -> Int? {
        let searchEnd = min(maxLag, cmnd.count - 2)
        guard minLag < searchEnd else { return nil }

        var tau = minLag
        while tau <= searchEnd {
            if cmnd[tau] < threshold {
                while tau + 1 <= searchEnd,
                      cmnd[tau + 1] < cmnd[tau] {
                    tau += 1
                }
                return tau
            }
            tau += 1
        }

        // Fallback: global minimum in range
        var bestTau = minLag
        for i in minLag...searchEnd {
            if cmnd[i] < cmnd[bestTau] {
                bestTau = i
            }
        }
        return cmnd[bestTau] < 0.5 ? bestTau : nil
    }

    /// Step 4: Parabolic interpolation for sub-sample accuracy.
    func parabolicInterpolation(
        _ cmnd: [Float],
        tau: Int
    ) -> Float {
        guard tau > 0, tau < cmnd.count - 1 else {
            return Float(tau)
        }

        let s0 = cmnd[tau - 1]
        let s1 = cmnd[tau]
        let s2 = cmnd[tau + 1]

        let denominator = 2.0 * s1 - s2 - s0
        guard abs(denominator) > 1e-10 else {
            return Float(tau)
        }

        let adjustment = (s2 - s0) / (2.0 * denominator)
        return Float(tau) + adjustment
    }
}
