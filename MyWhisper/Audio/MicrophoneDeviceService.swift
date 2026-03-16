import Foundation
import CoreAudio
import AVFoundation

struct AudioDeviceInfo: Identifiable {
    let id: AudioDeviceID
    let name: String
}

final class MicrophoneDeviceService {
    private let defaultsKey = "selectedMicrophoneID"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var selectedDeviceID: AudioDeviceID? {
        get {
            let raw = defaults.object(forKey: defaultsKey) as? UInt32
            return raw
        }
        set {
            if let value = newValue {
                defaults.set(value, forKey: defaultsKey)
            } else {
                defaults.removeObject(forKey: defaultsKey)
            }
        }
    }

    func availableInputDevices() -> [AudioDeviceInfo] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        ) == noErr else {
            return []
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        ) == noErr else {
            return []
        }

        return deviceIDs.compactMap { deviceID in
            guard hasInputChannels(deviceID: deviceID) else { return nil }
            let name = deviceName(deviceID: deviceID)
            return AudioDeviceInfo(id: deviceID, name: name)
        }
    }

    func setInputDevice(_ deviceID: AudioDeviceID, on engine: AVAudioEngine) throws {
        var id = deviceID
        let status = AudioUnitSetProperty(
            engine.inputNode.audioUnit!,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &id,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            throw MicrophoneDeviceError.setDeviceFailed(status)
        }
    }

    // MARK: - Private helpers

    private func hasInputChannels(deviceID: AudioDeviceID) -> Bool {
        var streamConfigAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &streamConfigAddress, 0, nil, &dataSize) == noErr,
              dataSize > 0 else {
            return false
        }

        let bufferListPtr = UnsafeMutableRawPointer.allocate(byteCount: Int(dataSize), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { bufferListPtr.deallocate() }

        guard AudioObjectGetPropertyData(deviceID, &streamConfigAddress, 0, nil, &dataSize, bufferListPtr) == noErr else {
            return false
        }

        let bufferList = bufferListPtr.bindMemory(to: AudioBufferList.self, capacity: 1)
        let buffers = UnsafeBufferPointer<AudioBuffer>(
            start: &bufferList.pointee.mBuffers,
            count: Int(bufferList.pointee.mNumberBuffers)
        )
        return buffers.contains(where: { $0.mNumberChannels > 0 })
    }

    private func deviceName(deviceID: AudioDeviceID) -> String {
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var name: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &dataSize, &name)
        return name as String
    }
}

enum MicrophoneDeviceError: Error {
    case setDeviceFailed(OSStatus)
}
