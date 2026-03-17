import Foundation
import CoreAudio

final class MicInputVolumeService: MicInputVolumeServiceProtocol {
    private var savedVolume: Float32?
    private var savedDeviceID: AudioDeviceID?
    private let microphoneService: MicrophoneDeviceService?

    init(microphoneService: MicrophoneDeviceService? = nil) {
        self.microphoneService = microphoneService
    }

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "maximizeMicVolumeEnabled")
    }

    func maximizeAndSave() {
        guard isEnabled else { return }
        guard let deviceID = resolveActiveDeviceID() else { return }
        guard let currentVolume = getVolume(deviceID: deviceID) else { return }
        savedVolume = currentVolume
        savedDeviceID = deviceID
        setVolume(1.0, deviceID: deviceID)
    }

    func restore() {
        guard let volume = savedVolume else { return }
        // Resolve device fresh — may have changed since maximize
        let deviceID = savedDeviceID ?? resolveActiveDeviceID()
        savedVolume = nil
        savedDeviceID = nil
        guard let deviceID else { return }
        setVolume(volume, deviceID: deviceID)
    }

    // MARK: - Private

    private func resolveActiveDeviceID() -> AudioDeviceID? {
        // Prefer user-selected device if still connected
        if let selectedID = microphoneService?.selectedDeviceID {
            let available = microphoneService?.availableInputDevices() ?? []
            if available.contains(where: { $0.id == selectedID }) {
                return selectedID
            }
        }
        // Fallback to system default input device
        return systemDefaultInputDeviceID()
    }

    private func systemDefaultInputDeviceID() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &deviceID
        ) == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    private func getVolume(deviceID: AudioDeviceID) -> Float32? {
        var volume = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = inputVolumeAddress()
        guard AudioObjectGetPropertyData(
            deviceID, &address, 0, nil, &size, &volume
        ) == noErr else { return nil }
        return volume
    }

    private func setVolume(_ volume: Float32, deviceID: AudioDeviceID) {
        var address = inputVolumeAddress()
        var isSettable: DarwinBoolean = false
        guard AudioObjectIsPropertySettable(deviceID, &address, &isSettable) == noErr,
              isSettable.boolValue else { return }  // Silent no-op for non-settable devices (VOL-04)
        var vol = volume
        AudioObjectSetPropertyData(deviceID, &address, 0, nil,
                                   UInt32(MemoryLayout<Float32>.size), &vol)
    }

    private func inputVolumeAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain  // NOT deprecated ElementMaster
        )
    }
}
