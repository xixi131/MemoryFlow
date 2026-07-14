import Accelerate
import Combine
import CoreAudio
import Foundation

enum MusicWaveformCaptureState: String, Codable, Equatable {
    case idle
    case resolvingPlayer
    case capturing
    case unavailable
}

struct MusicWaveformFrame: Equatable {
    static let bandCount = 10
    static let resting = MusicWaveformFrame(
        timestamp: .distantPast,
        bands: Array(repeating: 0, count: bandCount),
        rms: 0,
        captureState: .idle
    )

    let timestamp: Date
    let bands: [Float]
    let rms: Float
    let captureState: MusicWaveformCaptureState

    func level(forBar index: Int, barCount: Int) -> Float {
        guard bands.isEmpty == false, barCount > 0, index >= 0, index < barCount else { return 0 }
        let range = Self.bandRange(forBar: index, barCount: barCount, bandCount: bands.count)
        guard range.isEmpty == false else { return 0 }
        let total = range.reduce(Float.zero) { $0 + bands[$1] }
        return total / Float(range.count)
    }

    private static func bandRange(
        forBar index: Int,
        barCount: Int,
        bandCount: Int
    ) -> Range<Int> {
        if bandCount == MusicWaveformFrame.bandCount {
            switch barCount {
            case 4:
                return [0..<2, 2..<5, 5..<7, 7..<10][index]
            case 5:
                return [0..<2, 2..<4, 4..<6, 6..<8, 8..<10][index]
            default:
                break
            }
        }
        let lower = index * bandCount / barCount
        let upper = max((index + 1) * bandCount / barCount, lower + 1)
        return min(lower, bandCount)..<min(upper, bandCount)
    }
}

final class MusicWaveformModel: ObservableObject {
    @Published private(set) var frame = MusicWaveformFrame.resting
    private var settleTimer: Timer?

    func publish(_ frame: MusicWaveformFrame) {
        precondition(Thread.isMainThread)
        settleTimer?.invalidate()
        settleTimer = nil
        self.frame = frame
    }

    func settleToRest(captureState: MusicWaveformCaptureState = .idle) {
        precondition(Thread.isMainThread)
        settleTimer?.invalidate()
        var remainingSteps = 8
        settleTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            remainingSteps -= 1
            let nextBands = self.frame.bands.map { $0 * 0.58 }
            self.frame = MusicWaveformFrame(
                timestamp: Date(),
                bands: nextBands,
                rms: self.frame.rms * 0.58,
                captureState: captureState
            )
            if remainingSteps == 0 {
                timer.invalidate()
                self.settleTimer = nil
                self.frame = MusicWaveformFrame(
                    timestamp: Date(),
                    bands: Array(repeating: 0, count: MusicWaveformFrame.bandCount),
                    rms: 0,
                    captureState: captureState
                )
            }
        }
    }
}

protocol MusicAudioCaptureProviding: AnyObject {
    var onFrame: ((MusicWaveformFrame) -> Void)? { get set }
    var onStateChange: ((MusicWaveformCaptureState) -> Void)? { get set }
    func startCapturing(bundleIdentifier: String)
    func stopCapturing()
}

struct MusicAudioProcessDescriptor: Equatable {
    let objectID: AudioObjectID
    let bundleIdentifier: String
    let isRunningOutput: Bool
}

enum MusicAudioProcessMatcher {
    static func objectIDs(
        matching bundleIdentifier: String,
        in processes: [MusicAudioProcessDescriptor]
    ) -> [AudioObjectID] {
        processes.compactMap { process in
            let matchesBundle = process.bundleIdentifier == bundleIdentifier ||
                process.bundleIdentifier.hasPrefix(bundleIdentifier + ".")
            return matchesBundle && process.isRunningOutput ? process.objectID : nil
        }
    }
}

final class MusicSpectrumAnalyzer {
    static let fftSize = 2_048
    static let frequencyBands: [ClosedRange<Float>] = [
        50...100,
        100...180,
        180...300,
        300...500,
        500...800,
        800...1_300,
        1_300...2_200,
        2_200...3_800,
        3_800...7_000,
        7_000...12_000
    ]

    private let fftSetup: FFTSetup
    private let log2Size = vDSP_Length(log2(Float(fftSize)))
    private var window = [Float](repeating: 0, count: fftSize)
    private var timeDomain = [Float](repeating: 0, count: fftSize)
    private var gained = [Float](repeating: 0, count: fftSize)
    private var windowed = [Float](repeating: 0, count: fftSize)
    private var real = [Float](repeating: 0, count: fftSize / 2)
    private var imaginary = [Float](repeating: 0, count: fftSize / 2)
    private var magnitudes = [Float](repeating: 0, count: fftSize / 2)
    private var bandDecibels = [Float](repeating: -120, count: MusicWaveformFrame.bandCount)
    private var bandPeakDecibels = [Float](repeating: -24, count: MusicWaveformFrame.bandCount)
    private var previousBandDecibels = [Float](repeating: -120, count: MusicWaveformFrame.bandCount)
    private var smoothed = [Float](repeating: 0, count: MusicWaveformFrame.bandCount)
    private var referenceRMS: Float = 0.01

    init?() {
        guard let setup = vDSP_create_fftsetup(log2Size, FFTRadix(kFFTRadix2)) else { return nil }
        fftSetup = setup
        vDSP_hann_window(&window, vDSP_Length(Self.fftSize), Int32(vDSP_HANN_NORM))
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    func reset() {
        bandDecibels = Array(repeating: -120, count: MusicWaveformFrame.bandCount)
        bandPeakDecibels = Array(repeating: -24, count: MusicWaveformFrame.bandCount)
        previousBandDecibels = Array(repeating: -120, count: MusicWaveformFrame.bandCount)
        smoothed = Array(repeating: 0, count: MusicWaveformFrame.bandCount)
        referenceRMS = 0.01
    }

    func analyze(samples: UnsafeBufferPointer<Float>, sampleRate: Float) -> MusicWaveformFrame {
        let copiedCount = min(samples.count, Self.fftSize)
        timeDomain.withUnsafeMutableBufferPointer { destination in
            destination.baseAddress?.update(repeating: 0, count: destination.count)
            guard copiedCount > 0,
                  let sourceBase = samples.baseAddress,
                  let destinationBase = destination.baseAddress else { return }
            destinationBase.advanced(by: Self.fftSize - copiedCount)
                .update(from: sourceBase.advanced(by: samples.count - copiedCount), count: copiedCount)
        }

        var inputRMS: Float = 0
        vDSP_rmsqv(timeDomain, 1, &inputRMS, vDSP_Length(Self.fftSize))
        let inputDB = 20 * log10(max(inputRMS, 0.000_001))
        let hasAudibleSignal = inputDB > -90
        let referenceSmoothing: Float = inputRMS > referenceRMS ? 0.22 : 0.008
        referenceRMS += (inputRMS - referenceRMS) * referenceSmoothing
        let automaticGain = hasAudibleSignal
            ? min(max(0.22 / max(referenceRMS, 0.000_5), 1), 32)
            : 1
        vDSP_vsmul(timeDomain, 1, [automaticGain], &gained, 1, vDSP_Length(Self.fftSize))

        var rms: Float = 0
        vDSP_rmsqv(gained, 1, &rms, vDSP_Length(Self.fftSize))
        vDSP_vmul(gained, 1, window, 1, &windowed, 1, vDSP_Length(Self.fftSize))

        real.withUnsafeMutableBufferPointer { realBuffer in
            imaginary.withUnsafeMutableBufferPointer { imaginaryBuffer in
                var split = DSPSplitComplex(
                    realp: realBuffer.baseAddress!,
                    imagp: imaginaryBuffer.baseAddress!
                )
                windowed.withUnsafeBytes { bytes in
                    let complex = bytes.bindMemory(to: DSPComplex.self)
                    vDSP_ctoz(complex.baseAddress!, 2, &split, 1, vDSP_Length(Self.fftSize / 2))
                }
                vDSP_fft_zrip(fftSetup, &split, 1, log2Size, FFTDirection(kFFTDirection_Forward))
                vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(Self.fftSize / 2))
            }
        }

        let rmsDB = 20 * log10(max(rms, 0.000_001))
        let rmsLevel = Self.normalizedDecibels(rmsDB, floor: -48, ceiling: -4)
        let isBelowNoiseGate = hasAudibleSignal == false
        let binWidth = sampleRate / Float(Self.fftSize)

        for (bandIndex, frequencyRange) in Self.frequencyBands.enumerated() {
            let lower = max(1, Int(frequencyRange.lowerBound / binWidth))
            let upper = min(magnitudes.count - 1, Int(frequencyRange.upperBound / binWidth))
            var sum: Float = 0
            var peakPower: Float = 0
            if lower <= upper {
                for index in lower...upper {
                    let power = magnitudes[index]
                    sum += power
                    peakPower = max(peakPower, power)
                }
            }
            let meanPower = sum / Float(max(upper - lower + 1, 1))
            let representativePower = (peakPower * 0.70) + (meanPower * 0.30)
            let normalizedPower = representativePower / Float(Self.fftSize * Self.fftSize)
            bandDecibels[bandIndex] = 10 * log10(max(normalizedPower, 0.000_000_000_1))
        }

        let strongestBandDB = bandDecibels.max() ?? -120
        let relativeGateDB = max(-76, strongestBandDB - 20)

        for bandIndex in bandDecibels.indices {
            let bandDB = bandDecibels[bandIndex]
            let positiveChangeDB = max(0, bandDB - previousBandDecibels[bandIndex])
            previousBandDecibels[bandIndex] = bandDB
            if bandDB > bandPeakDecibels[bandIndex] {
                bandPeakDecibels[bandIndex] = bandDB
            } else {
                bandPeakDecibels[bandIndex] = max(
                    bandDB,
                    bandPeakDecibels[bandIndex] - 0.24
                )
            }

            let bandFloorDB = max(relativeGateDB, bandPeakDecibels[bandIndex] - 30)
            let availableRange = max(bandPeakDecibels[bandIndex] - bandFloorDB, 8)
            let independentLevel = bandDB <= bandFloorDB
                ? 0
                : min(max((bandDB - bandFloorDB) / availableRange, 0), 1)
            let transientLevel = min(positiveChangeDB / 7, 1)
            let transientScale = 0.42 + (transientLevel * 0.58)
            var target = isBelowNoiseGate ? 0 : independentLevel * transientScale
            if target < 0.04 { target = 0 }
            target = min(target, 1)

            let hasCurrentBandEnergy = isBelowNoiseGate == false && independentLevel >= 0.08
            let smoothing: Float
            if target > smoothed[bandIndex] {
                smoothing = 0.88
            } else {
                smoothing = hasCurrentBandEnergy ? 0.14 : 0.36
            }
            smoothed[bandIndex] += (target - smoothed[bandIndex]) * smoothing
            if smoothed[bandIndex] < 0.01 { smoothed[bandIndex] = 0 }
        }

        return MusicWaveformFrame(
            timestamp: Date(),
            bands: smoothed,
            rms: isBelowNoiseGate ? 0 : rmsLevel,
            captureState: .capturing
        )
    }

    private static func normalizedDecibels(_ value: Float, floor: Float, ceiling: Float) -> Float {
        min(max((value - floor) / (ceiling - floor), 0), 1)
    }
}

private final class MusicAudioRingBuffer {
    private var storage: [Float]
    private var writeIndex = 0
    private var availableCount = 0
    private let lock = NSLock()

    init(capacity: Int = 16_384) {
        storage = Array(repeating: 0, count: capacity)
    }

    func write(_ value: Float) {
        storage[writeIndex] = value
        writeIndex = (writeIndex + 1) % storage.count
        availableCount = min(availableCount + 1, storage.count)
    }

    func withWriteLock(_ body: () -> Void) {
        lock.lock()
        body()
        lock.unlock()
    }

    func copyLatest(into destination: inout [Float]) -> Int {
        lock.lock()
        defer { lock.unlock() }
        let count = min(destination.count, availableCount)
        guard count > 0 else { return 0 }
        let start = (writeIndex - count + storage.count) % storage.count
        for offset in 0..<count {
            destination[offset] = storage[(start + offset) % storage.count]
        }
        return count
    }

    func reset() {
        lock.lock()
        storage.withUnsafeMutableBufferPointer {
            $0.baseAddress?.update(repeating: 0, count: $0.count)
        }
        writeIndex = 0
        availableCount = 0
        lock.unlock()
    }
}

final class CoreAudioMusicCapture: MusicAudioCaptureProviding {
    var onFrame: ((MusicWaveformFrame) -> Void)?
    var onStateChange: ((MusicWaveformCaptureState) -> Void)?

    private let controlQueue = DispatchQueue(label: "com.memoryflow.island.music-audio-capture")
    private let controlQueueKey = DispatchSpecificKey<Void>()
    private let analysisQueue = DispatchQueue(label: "com.memoryflow.island.music-audio-analysis", qos: .userInteractive)
    private let ringBuffer = MusicAudioRingBuffer()
    private let analyzer = MusicSpectrumAnalyzer()
    private var analysisSamples = [Float](repeating: 0, count: MusicSpectrumAnalyzer.fftSize)
    private var analysisTimer: DispatchSourceTimer?
    private var activeBundleIdentifier: String?
    private var capturedProcessIDs: [AudioObjectID] = []
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private var streamFormat = AudioStreamBasicDescription()

    init() {
        controlQueue.setSpecific(key: controlQueueKey, value: ())
    }

    func startCapturing(bundleIdentifier: String) {
        let normalized = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else {
            stopCapturing()
            return
        }
        controlQueue.async { [weak self] in
            guard let self else { return }
            if self.activeBundleIdentifier == normalized,
               self.aggregateDeviceID != AudioObjectID(kAudioObjectUnknown),
               let currentProcessIDs = try? Self.audioProcessObjectIDs(matching: normalized),
               Set(currentProcessIDs) == Set(self.capturedProcessIDs) {
                return
            }
            self.tearDownCapture()
            self.activeBundleIdentifier = normalized
            self.publishState(.resolvingPlayer)
            do {
                try self.setUpCapture(bundleIdentifier: normalized)
                self.startAnalysisTimer()
                self.publishState(.capturing)
            } catch {
                self.tearDownCapture()
                self.activeBundleIdentifier = normalized
                self.publishState(.unavailable)
                print("[MusicWaveform] Capture unavailable bundle=\(normalized) error=\(error)")
            }
        }
    }

    func stopCapturing() {
        let stop = { [self] in
            self.activeBundleIdentifier = nil
            self.tearDownCapture()
            self.publishState(.idle)
        }
        if DispatchQueue.getSpecific(key: controlQueueKey) != nil {
            stop()
        } else {
            controlQueue.sync(execute: stop)
        }
    }

    private func setUpCapture(bundleIdentifier: String) throws {
        let processIDs = try Self.audioProcessObjectIDs(matching: bundleIdentifier)
        guard processIDs.isEmpty == false else { throw MusicAudioCaptureError.playerProcessNotFound }
        capturedProcessIDs = processIDs

        let description = CATapDescription(stereoMixdownOfProcesses: processIDs)
        description.name = "MemoryFlow Music Waveform"
        description.uuid = UUID()
        description.muteBehavior = CATapMuteBehavior(rawValue: 0)!
        description.isPrivate = true

        try Self.check(AudioHardwareCreateProcessTap(description, &tapID), operation: "create process tap")
        streamFormat = try Self.streamFormat(objectID: tapID)

        let aggregateDescription: [String: Any] = [
            kAudioAggregateDeviceNameKey: "MemoryFlow Music Waveform",
            kAudioAggregateDeviceUIDKey: "com.memoryflow.island.waveform.\(UUID().uuidString)",
            kAudioAggregateDeviceMainSubDeviceKey: "",
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapListKey: [[kAudioSubTapUIDKey: description.uuid.uuidString]]
        ]
        try Self.check(
            AudioHardwareCreateAggregateDevice(aggregateDescription as CFDictionary, &aggregateDeviceID),
            operation: "create aggregate device"
        )

        try Self.check(
            AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateDeviceID, nil) { [weak self] _, inputData, _, _, _ in
                self?.consume(inputData)
            },
            operation: "create IO proc"
        )
        try Self.check(AudioDeviceStart(aggregateDeviceID, ioProcID), operation: "start aggregate device")
    }

    private func consume(_ audioBufferList: UnsafePointer<AudioBufferList>) {
        let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: audioBufferList))
        guard buffers.isEmpty == false else { return }
        let isFloat = streamFormat.mFormatFlags & kAudioFormatFlagIsFloat != 0
        guard streamFormat.mFormatID == kAudioFormatLinearPCM, isFloat else { return }

        ringBuffer.withWriteLock {
            let isInterleaved = streamFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved == 0
            if isInterleaved, let data = buffers[0].mData {
                let channelCount = max(Int(streamFormat.mChannelsPerFrame), 1)
                let sampleCount = Int(buffers[0].mDataByteSize) / MemoryLayout<Float>.size
                let frames = sampleCount / channelCount
                let samples = data.assumingMemoryBound(to: Float.self)
                for frame in 0..<frames {
                    var mono: Float = 0
                    for channel in 0..<channelCount { mono += samples[(frame * channelCount) + channel] }
                    ringBuffer.write(mono / Float(channelCount))
                }
            } else {
                let channelCount = buffers.count
                guard channelCount > 0 else { return }
                var frameCount = Int.max
                for buffer in buffers where buffer.mData != nil {
                    frameCount = min(
                        frameCount,
                        Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
                    )
                }
                guard frameCount != Int.max else { return }
                for frame in 0..<frameCount {
                    var mono: Float = 0
                    for buffer in buffers {
                        guard let data = buffer.mData else { continue }
                        mono += data.assumingMemoryBound(to: Float.self)[frame]
                    }
                    ringBuffer.write(mono / Float(channelCount))
                }
            }
        }
    }

    private func startAnalysisTimer() {
        guard analysisTimer == nil, analyzer != nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: analysisQueue)
        timer.schedule(deadline: .now(), repeating: 1.0 / 30.0, leeway: .milliseconds(4))
        timer.setEventHandler { [weak self] in
            guard let self, let analyzer = self.analyzer else { return }
            let count = self.ringBuffer.copyLatest(into: &self.analysisSamples)
            guard count > 0 else { return }
            self.analysisSamples.withUnsafeBufferPointer { samples in
                let frame = analyzer.analyze(
                    samples: UnsafeBufferPointer(rebasing: samples.prefix(count)),
                    sampleRate: Float(self.streamFormat.mSampleRate)
                )
                self.onFrame?(frame)
            }
        }
        analysisTimer = timer
        timer.resume()
    }

    private func tearDownCapture() {
        analysisTimer?.setEventHandler {}
        analysisTimer?.cancel()
        analysisTimer = nil
        analysisQueue.sync { [analyzer, ringBuffer] in
            analyzer?.reset()
            ringBuffer.reset()
        }
        if aggregateDeviceID != AudioObjectID(kAudioObjectUnknown), let ioProcID {
            AudioDeviceStop(aggregateDeviceID, ioProcID)
            AudioDeviceDestroyIOProcID(aggregateDeviceID, ioProcID)
        }
        ioProcID = nil
        if aggregateDeviceID != AudioObjectID(kAudioObjectUnknown) {
            AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
        }
        if tapID != AudioObjectID(kAudioObjectUnknown) {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
        capturedProcessIDs = []
    }

    private func publishState(_ state: MusicWaveformCaptureState) {
        onStateChange?(state)
    }

    private static func audioProcessObjectIDs(matching bundleIdentifier: String) throws -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        try check(
            AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize),
            operation: "read audio process list size"
        )
        var processIDs = [AudioObjectID](
            repeating: AudioObjectID(kAudioObjectUnknown),
            count: Int(dataSize) / MemoryLayout<AudioObjectID>.size
        )
        try check(
            AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &processIDs),
            operation: "read audio process list"
        )
        let descriptors = processIDs.compactMap { processID -> MusicAudioProcessDescriptor? in
            guard let processBundleIdentifier = processBundleIdentifier(for: processID) else { return nil }
            let runningOutput = (try? uint32Property(
                objectID: processID,
                selector: kAudioProcessPropertyIsRunningOutput
            )) ?? 0
            return MusicAudioProcessDescriptor(
                objectID: processID,
                bundleIdentifier: processBundleIdentifier,
                isRunningOutput: runningOutput != 0
            )
        }
        return MusicAudioProcessMatcher.objectIDs(matching: bundleIdentifier, in: descriptors)
    }

    private static func processBundleIdentifier(for processID: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyBundleID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var unmanaged: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(processID, &address, 0, nil, &dataSize, &unmanaged) == noErr,
              let unmanaged else { return nil }
        return unmanaged.takeRetainedValue() as String
    }

    private static func streamFormat(objectID: AudioObjectID) throws -> AudioStreamBasicDescription {
        var value = AudioStreamBasicDescription()
        var dataSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        try check(
            AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, &value),
            operation: "read tap stream format"
        )
        return value
    }

    private static func uint32Property(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector
    ) throws -> UInt32 {
        var value: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        try check(
            AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, &value),
            operation: "read Core Audio UInt32 property \(selector)"
        )
        return value
    }

    private static func check(_ status: OSStatus, operation: String) throws {
        guard status == noErr else { throw MusicAudioCaptureError.coreAudio(operation: operation, status: status) }
    }
}

enum MusicAudioCaptureError: Error, CustomStringConvertible {
    case playerProcessNotFound
    case coreAudio(operation: String, status: OSStatus)

    var description: String {
        switch self {
        case .playerProcessNotFound:
            return "No active Core Audio output process matched the current player."
        case let .coreAudio(operation, status):
            return "\(operation) failed with OSStatus \(status)."
        }
    }
}
