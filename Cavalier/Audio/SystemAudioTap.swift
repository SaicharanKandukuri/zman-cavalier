import CoreAudio
import AudioToolbox
import Foundation
import os

/// Captures mixed system audio output via Core Audio's process tap API (macOS 14.2+).
/// Delivers interleaved Float32 samples through a callback on the Core Audio IO thread.
final class SystemAudioTap {
    typealias SampleHandler = (_ samples: UnsafePointer<Float>, _ frameCount: Int, _ channels: Int, _ sampleRate: Double) -> Void

    private let log = Logger(subsystem: "com.zman.cavalier", category: "SystemAudioTap")

    private var tapID: AudioObjectID = kAudioObjectUnknown
    private var aggregateID: AudioObjectID = kAudioObjectUnknown
    private var ioProcID: AudioDeviceIOProcID?
    private var streamFormat = AudioStreamBasicDescription()
    private var handler: SampleHandler?

    enum TapError: Error, CustomStringConvertible {
        case createTapFailed(OSStatus)
        case readTapUIDFailed(OSStatus)
        case createAggregateFailed(OSStatus)
        case readStreamFormatFailed(OSStatus)
        case createIOProcFailed(OSStatus)
        case startFailed(OSStatus)

        var description: String {
            switch self {
            case .createTapFailed(let s): return "Create tap failed (\(s))"
            case .readTapUIDFailed(let s): return "Read tap UID failed (\(s))"
            case .createAggregateFailed(let s): return "Create aggregate failed (\(s))"
            case .readStreamFormatFailed(let s): return "Read stream format failed (\(s))"
            case .createIOProcFailed(let s): return "Create IO proc failed (\(s))"
            case .startFailed(let s): return "Start failed (\(s))"
            }
        }
    }

    func start(handler: @escaping SampleHandler) throws {
        self.handler = handler

        let tapDesc = CATapDescription()
        tapDesc.isExclusive = true
        tapDesc.isMixdown = true
        tapDesc.isMono = false
        tapDesc.muteBehavior = .unmuted
        tapDesc.isPrivate = true
        tapDesc.name = "Cavalier System Tap"

        var tap: AudioObjectID = kAudioObjectUnknown
        var status = AudioHardwareCreateProcessTap(tapDesc, &tap)
        guard status == noErr else { throw TapError.createTapFailed(status) }
        self.tapID = tap

        let tapUID = try readTapUID(tap)

        let aggUID = "com.zman.cavalier.aggregate." + UUID().uuidString
        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Cavalier System Tap Aggregate",
            kAudioAggregateDeviceUIDKey: aggUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[String: Any]](),
            kAudioAggregateDeviceTapListKey: [
                [
                    kAudioSubTapUIDKey: tapUID,
                    kAudioSubTapDriftCompensationKey: true
                ]
            ]
        ]
        var agg: AudioObjectID = kAudioObjectUnknown
        status = AudioHardwareCreateAggregateDevice(description as CFDictionary, &agg)
        guard status == noErr else { throw TapError.createAggregateFailed(status) }
        self.aggregateID = agg

        streamFormat = try readInputStreamFormat(agg)
        log.info("Aggregate device stream format: \(self.streamFormat.mSampleRate) Hz, \(self.streamFormat.mChannelsPerFrame) ch, flags \(self.streamFormat.mFormatFlags)")

        var procID: AudioDeviceIOProcID?
        status = AudioDeviceCreateIOProcIDWithBlock(&procID, agg, nil) { [weak self] _, inInputData, _, _, _ in
            self?.deliver(inInputData.pointee)
        }
        guard status == noErr, let procID else { throw TapError.createIOProcFailed(status) }
        self.ioProcID = procID

        status = AudioDeviceStart(agg, procID)
        guard status == noErr else { throw TapError.startFailed(status) }
    }

    func stop() {
        if let procID = ioProcID, aggregateID != kAudioObjectUnknown {
            AudioDeviceStop(aggregateID, procID)
            AudioDeviceDestroyIOProcID(aggregateID, procID)
        }
        ioProcID = nil
        if aggregateID != kAudioObjectUnknown {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = kAudioObjectUnknown
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = kAudioObjectUnknown
        }
    }

    deinit { stop() }

    private func deliver(_ abl: AudioBufferList) {
        let mNum = Int(abl.mNumberBuffers)
        guard mNum > 0 else { return }
        // AudioBufferList has a flexible array of mBuffers; withUnsafePointer to walk it.
        var list = abl
        withUnsafePointer(to: &list) { ptr in
            let ablPtr = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: ptr))
            guard let first = ablPtr.first, let data = first.mData else { return }
            let byteCount = Int(first.mDataByteSize)
            let sampleCount = byteCount / MemoryLayout<Float>.size
            let channels = Int(streamFormat.mChannelsPerFrame == 0 ? first.mNumberChannels : streamFormat.mChannelsPerFrame)
            let frameCount = channels > 0 ? sampleCount / channels : sampleCount
            let floats = data.bindMemory(to: Float.self, capacity: sampleCount)
            handler?(floats, frameCount, channels, streamFormat.mSampleRate)
        }
    }

    private func readTapUID(_ tap: AudioObjectID) throws -> String {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var uidRef: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = withUnsafeMutablePointer(to: &uidRef) { ptr -> OSStatus in
            AudioObjectGetPropertyData(tap, &addr, 0, nil, &size, ptr)
        }
        guard status == noErr, let uid = uidRef?.takeRetainedValue() else {
            throw TapError.readTapUIDFailed(status)
        }
        return uid as String
    }

    private func readInputStreamFormat(_ device: AudioObjectID) throws -> AudioStreamBasicDescription {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamFormat,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain)
        var fmt = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let status = AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &fmt)
        guard status == noErr else { throw TapError.readStreamFormatFailed(status) }
        return fmt
    }
}
