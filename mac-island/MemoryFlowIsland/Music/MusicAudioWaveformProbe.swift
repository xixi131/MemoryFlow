import CoreAudio
import Foundation

enum MusicAudioWaveformProbe {
    static func validate() throws {
        try validateFrameMapping()
        try validateProcessMatching()
        try validateSpectrumResponse()
        try validateIndependentBandActivity()
        try validateTransientDynamics()
        try validateIndependentMotionSequences()
        try validateBandHandoff()
        try validateReleaseSmoothing()
    }

    private static func validateFrameMapping() throws {
        let frame = MusicWaveformFrame(
            timestamp: Date(timeIntervalSince1970: 1),
            bands: [0, 0.2, 0.4, 0.6, 0.8, 1, 0.5, 0.3, 0.7, 0.1],
            rms: 0.5,
            captureState: .capturing
        )
        guard approximatelyEqual(frame.level(forBar: 0, barCount: 5), 0.1),
              approximatelyEqual(frame.level(forBar: 1, barCount: 5), 0.5),
              approximatelyEqual(frame.level(forBar: 2, barCount: 5), 0.9),
              approximatelyEqual(frame.level(forBar: 3, barCount: 5), 0.4),
              approximatelyEqual(frame.level(forBar: 4, barCount: 5), 0.4),
              approximatelyEqual(frame.level(forBar: 0, barCount: 4), 0.1),
              approximatelyEqual(frame.level(forBar: 1, barCount: 4), 0.6),
              approximatelyEqual(frame.level(forBar: 2, barCount: 4), 0.75),
              approximatelyEqual(frame.level(forBar: 3, barCount: 4), 1.1 / 3) else {
            throw MusicAudioWaveformProbeError.invalidFrameMapping
        }
    }

    private static func validateIndependentBandActivity() throws {
        let sampleRate: Float = 48_000
        let low = try analyze(
            sineWave(frequency: 100, amplitude: 0.4, sampleRate: sampleRate),
            sampleRate: sampleRate
        )
        let mid = try analyze(
            sineWave(frequency: 1_000, amplitude: 0.4, sampleRate: sampleRate),
            sampleRate: sampleRate
        )
        let allBands = try analyze(
            mixedWave(
                frequencies: [75, 140, 240, 400, 650, 1_000, 1_700, 3_000, 5_200, 9_000],
                amplitudePerFrequency: 0.055,
                sampleRate: sampleRate
            ),
            sampleRate: sampleRate
        )

        let lowActive = low.bands.indices.filter { low.bands[$0] > 0.08 }
        let midActive = mid.bands.indices.filter { mid.bands[$0] > 0.08 }
        let broadbandActive = allBands.bands.filter { $0 > 0.08 }.count
        guard lowActive.contains(0),
              lowActive.allSatisfy({ $0 <= 1 }),
              midActive.contains(5),
              midActive.allSatisfy({ $0 == 5 }),
              broadbandActive >= 7 else {
            throw MusicAudioWaveformProbeError.invalidIndependentBandActivity
        }
    }

    private static func validateProcessMatching() throws {
        let rows = [
            MusicAudioProcessDescriptor(objectID: 11, bundleIdentifier: "com.apple.Music", isRunningOutput: true),
            MusicAudioProcessDescriptor(objectID: 12, bundleIdentifier: "com.apple.Music.helper", isRunningOutput: true),
            MusicAudioProcessDescriptor(objectID: 13, bundleIdentifier: "com.apple.Music", isRunningOutput: false),
            MusicAudioProcessDescriptor(objectID: 14, bundleIdentifier: "com.apple.Safari", isRunningOutput: true)
        ]
        guard MusicAudioProcessMatcher.objectIDs(matching: "com.apple.Music", in: rows) == [11, 12],
              MusicAudioProcessMatcher.objectIDs(matching: "com.spotify.client", in: rows).isEmpty else {
            throw MusicAudioWaveformProbeError.invalidProcessMatching
        }
    }

    private static func validateSpectrumResponse() throws {
        let sampleRate: Float = 48_000
        let silence = Array(repeating: Float.zero, count: MusicSpectrumAnalyzer.fftSize)
        let low = sineWave(frequency: 100, amplitude: 0.8, sampleRate: sampleRate)
        let mid = sineWave(frequency: 1_000, amplitude: 0.8, sampleRate: sampleRate)
        let quiet = sineWave(frequency: 100, amplitude: 0.05, sampleRate: sampleRate)
        let veryQuiet = sineWave(frequency: 100, amplitude: 0.001, sampleRate: sampleRate)

        let silenceFrame = try analyze(silence, sampleRate: sampleRate)
        let lowFrame = try analyze(low, sampleRate: sampleRate)
        let midFrame = try analyze(mid, sampleRate: sampleRate)
        let quietFrame = try analyze(quiet, sampleRate: sampleRate)
        let veryQuietFrame = try analyze(veryQuiet, sampleRate: sampleRate)

        guard silenceFrame.bands.allSatisfy({ $0 == 0 }),
              max(lowFrame.bands[0], lowFrame.bands[1]) > lowFrame.bands[5],
              midFrame.bands[5] > midFrame.bands[0],
              lowFrame.rms > quietFrame.rms,
              max(veryQuietFrame.bands[0], veryQuietFrame.bands[1]) > 0.15 else {
            throw MusicAudioWaveformProbeError.invalidSpectrumResponse
        }
    }

    private static func validateReleaseSmoothing() throws {
        guard let analyzer = MusicSpectrumAnalyzer() else {
            throw MusicAudioWaveformProbeError.analyzerUnavailable
        }
        let sampleRate: Float = 48_000
        let loud = sineWave(frequency: 100, amplitude: 0.8, sampleRate: sampleRate)
        let silence = Array(repeating: Float.zero, count: MusicSpectrumAnalyzer.fftSize)
        let loudFrame = loud.withUnsafeBufferPointer { analyzer.analyze(samples: $0, sampleRate: sampleRate) }
        let firstRelease = silence.withUnsafeBufferPointer { analyzer.analyze(samples: $0, sampleRate: sampleRate) }
        var settled = firstRelease
        for _ in 0..<50 {
            settled = silence.withUnsafeBufferPointer { analyzer.analyze(samples: $0, sampleRate: sampleRate) }
        }
        guard loudFrame.bands[0] > firstRelease.bands[0],
              firstRelease.bands[0] > settled.bands[0],
              settled.bands[0] < 0.01 else {
            throw MusicAudioWaveformProbeError.invalidReleaseSmoothing
        }
    }

    private static func validateBandHandoff() throws {
        guard let analyzer = MusicSpectrumAnalyzer() else {
            throw MusicAudioWaveformProbeError.analyzerUnavailable
        }
        let sampleRate: Float = 48_000
        let low = sineWave(frequency: 100, amplitude: 0.4, sampleRate: sampleRate)
        let mid = sineWave(frequency: 1_000, amplitude: 0.4, sampleRate: sampleRate)
        let lowFrame = low.withUnsafeBufferPointer {
            analyzer.analyze(samples: $0, sampleRate: sampleRate)
        }
        var handoffFrame = lowFrame
        for _ in 0..<16 {
            handoffFrame = mid.withUnsafeBufferPointer {
                analyzer.analyze(samples: $0, sampleRate: sampleRate)
            }
        }
        guard lowFrame.bands[0] > 0.2,
              handoffFrame.bands[0] == 0,
              handoffFrame.bands[5] > 0.12 else {
            throw MusicAudioWaveformProbeError.invalidBandHandoff
        }
    }

    private static func validateTransientDynamics() throws {
        guard let analyzer = MusicSpectrumAnalyzer() else {
            throw MusicAudioWaveformProbeError.analyzerUnavailable
        }
        let sampleRate: Float = 48_000
        let steadyInput = sineWave(frequency: 1_000, amplitude: 0.2, sampleRate: sampleRate)
        let pulseInput = sineWave(frequency: 1_000, amplitude: 0.8, sampleRate: sampleRate)
        let onset = steadyInput.withUnsafeBufferPointer {
            analyzer.analyze(samples: $0, sampleRate: sampleRate)
        }
        var steady = onset
        for _ in 0..<12 {
            steady = steadyInput.withUnsafeBufferPointer {
                analyzer.analyze(samples: $0, sampleRate: sampleRate)
            }
        }
        let pulse = pulseInput.withUnsafeBufferPointer {
            analyzer.analyze(samples: $0, sampleRate: sampleRate)
        }
        guard onset.bands[5] > steady.bands[5],
              steady.bands[5] > onset.bands[5] * 0.35,
              pulse.bands[5] > steady.bands[5] else {
            throw MusicAudioWaveformProbeError.invalidTransientDynamics
        }
    }

    private static func validateIndependentMotionSequences() throws {
        guard let analyzer = MusicSpectrumAnalyzer() else {
            throw MusicAudioWaveformProbeError.analyzerUnavailable
        }
        let sampleRate: Float = 48_000
        let frequencies: [Float] = [75, 240, 650, 1_700, 5_200]
        let rates: [Float] = [0.31, 0.47, 0.63, 0.79, 0.97]
        let phases: [Float] = [0, 0.8, 1.6, 2.4, 3.2]
        var differentiatedFrameCount = 0
        var hasRestingAndActiveBars = false

        for step in 0..<36 {
            let amplitudes = frequencies.indices.map { index in
                Float(0.01) + Float(0.18) * max(
                    0,
                    sin((Float(step) * rates[index]) + phases[index])
                )
            }
            let samples = mixedWave(
                frequencies: frequencies,
                amplitudes: amplitudes,
                sampleRate: sampleRate
            )
            let frame = samples.withUnsafeBufferPointer {
                analyzer.analyze(samples: $0, sampleRate: sampleRate)
            }
            let bars = (0..<5).map { frame.level(forBar: $0, barCount: 5) }
            if (bars.max() ?? 0) - (bars.min() ?? 0) > 0.12 {
                differentiatedFrameCount += 1
            }
            if bars.contains(where: { $0 < 0.04 }),
               bars.contains(where: { $0 > 0.25 }) {
                hasRestingAndActiveBars = true
            }
        }

        guard differentiatedFrameCount >= 24, hasRestingAndActiveBars else {
            throw MusicAudioWaveformProbeError.invalidIndependentMotionSequences
        }
    }

    private static func analyze(_ samples: [Float], sampleRate: Float) throws -> MusicWaveformFrame {
        guard let analyzer = MusicSpectrumAnalyzer() else {
            throw MusicAudioWaveformProbeError.analyzerUnavailable
        }
        return samples.withUnsafeBufferPointer { analyzer.analyze(samples: $0, sampleRate: sampleRate) }
    }

    private static func sineWave(
        frequency: Float,
        amplitude: Float,
        sampleRate: Float
    ) -> [Float] {
        (0..<MusicSpectrumAnalyzer.fftSize).map { index in
            amplitude * sin(2 * Float.pi * frequency * Float(index) / sampleRate)
        }
    }

    private static func mixedWave(
        frequencies: [Float],
        amplitudePerFrequency: Float,
        sampleRate: Float
    ) -> [Float] {
        mixedWave(
            frequencies: frequencies,
            amplitudes: Array(repeating: amplitudePerFrequency, count: frequencies.count),
            sampleRate: sampleRate
        )
    }

    private static func mixedWave(
        frequencies: [Float],
        amplitudes: [Float],
        sampleRate: Float
    ) -> [Float] {
        (0..<MusicSpectrumAnalyzer.fftSize).map { index in
            frequencies.indices.reduce(Float.zero) { partial, frequencyIndex in
                partial + amplitudes[frequencyIndex] * sin(
                    2 * Float.pi * frequencies[frequencyIndex] * Float(index) / sampleRate
                )
            }
        }
    }

    private static func approximatelyEqual(_ lhs: Float, _ rhs: Float) -> Bool {
        abs(lhs - rhs) < 0.001
    }
}

enum MusicAudioWaveformProbeError: Error {
    case analyzerUnavailable
    case invalidFrameMapping
    case invalidProcessMatching
    case invalidSpectrumResponse
    case invalidIndependentBandActivity
    case invalidTransientDynamics
    case invalidIndependentMotionSequences
    case invalidBandHandoff
    case invalidReleaseSmoothing
}
