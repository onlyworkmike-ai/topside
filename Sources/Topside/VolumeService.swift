import CoreAudio
import Foundation

/// Reads and sets the real system output volume and mute state through CoreAudio,
/// and tells the app when they change (keyboard keys, Control Center, switching to AirPods...).
final class VolumeService {
    var onChange: (() -> Void)?

    private var deviceID = AudioObjectID(kAudioObjectUnknown)
    private var systemListener: AudioObjectPropertyListenerBlock?
    private var deviceListener: AudioObjectPropertyListenerBlock?
    private var watched: [AudioObjectPropertyAddress] = []

    /// 'vmvc' = kAudioHardwareServiceDeviceProperty_VirtualMainVolume
    private let virtualMainVolume: AudioObjectPropertySelector = 0x766D7663

    private var unknownDevice: AudioObjectID { AudioObjectID(kAudioObjectUnknown) }

    // MARK: Lifecycle

    func start() {
        deviceListener = { [weak self] _, _ in
            self?.onChange?()
        }
        systemListener = { [weak self] _, _ in
            self?.attachToDefaultDevice()
            self?.onChange?()
        }

        var address = makeAddress(kAudioHardwarePropertyDefaultOutputDevice,
                                  scope: kAudioObjectPropertyScopeGlobal)
        if let block = systemListener {
            AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject),
                                                &address,
                                                DispatchQueue.main,
                                                block)
        }
        attachToDefaultDevice()
    }

    // MARK: Reading

    func volume() -> Float? {
        guard deviceID != unknownDevice else { return nil }

        var address = makeAddress(virtualMainVolume)
        if AudioObjectHasProperty(deviceID, &address) {
            var value: Float32 = 0
            var size = UInt32(MemoryLayout<Float32>.size)
            if AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value) == noErr {
                return value
            }
        }

        // Fallback for devices without a master volume: average the left/right channels.
        var values: [Float32] = []
        for channel: UInt32 in [1, 2] {
            var channelAddress = makeAddress(kAudioDevicePropertyVolumeScalar, element: channel)
            guard AudioObjectHasProperty(deviceID, &channelAddress) else { continue }
            var value: Float32 = 0
            var size = UInt32(MemoryLayout<Float32>.size)
            if AudioObjectGetPropertyData(deviceID, &channelAddress, 0, nil, &size, &value) == noErr {
                values.append(value)
            }
        }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Float(values.count)
    }

    func isMuted() -> Bool {
        guard deviceID != unknownDevice else { return false }
        var address = makeAddress(kAudioDevicePropertyMute)
        guard AudioObjectHasProperty(deviceID, &address) else { return false }
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &muted) == noErr else {
            return false
        }
        return muted != 0
    }

    // MARK: Writing

    func setVolume(_ newValue: Float) {
        guard deviceID != unknownDevice else { return }
        var value = max(0, min(1, newValue))

        var address = makeAddress(virtualMainVolume)
        if AudioObjectHasProperty(deviceID, &address) {
            AudioObjectSetPropertyData(deviceID, &address, 0, nil,
                                       UInt32(MemoryLayout<Float32>.size), &value)
            return
        }

        for channel: UInt32 in [1, 2] {
            var channelAddress = makeAddress(kAudioDevicePropertyVolumeScalar, element: channel)
            if AudioObjectHasProperty(deviceID, &channelAddress) {
                AudioObjectSetPropertyData(deviceID, &channelAddress, 0, nil,
                                           UInt32(MemoryLayout<Float32>.size), &value)
            }
        }
    }

    func setMuted(_ muted: Bool) {
        guard deviceID != unknownDevice else { return }
        var address = makeAddress(kAudioDevicePropertyMute)
        guard AudioObjectHasProperty(deviceID, &address) else { return }
        var value: UInt32 = muted ? 1 : 0
        AudioObjectSetPropertyData(deviceID, &address, 0, nil,
                                   UInt32(MemoryLayout<UInt32>.size), &value)
    }

    // MARK: Internals

    private func makeAddress(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeOutput,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }

    private func defaultOutputDevice() -> AudioObjectID {
        var address = makeAddress(kAudioHardwarePropertyDefaultOutputDevice,
                                  scope: kAudioObjectPropertyScopeGlobal)
        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                                &address, 0, nil, &size, &id)
        return status == noErr ? id : AudioObjectID(kAudioObjectUnknown)
    }

    private func attachToDefaultDevice() {
        detachFromDevice()
        deviceID = defaultOutputDevice()
        guard deviceID != unknownDevice, let block = deviceListener else { return }

        var addresses = [
            makeAddress(virtualMainVolume),
            makeAddress(kAudioDevicePropertyMute),
            makeAddress(kAudioDevicePropertyVolumeScalar, element: 1),
            makeAddress(kAudioDevicePropertyVolumeScalar, element: 2)
        ]
        for index in addresses.indices {
            let status = AudioObjectAddPropertyListenerBlock(deviceID,
                                                             &addresses[index],
                                                             DispatchQueue.main,
                                                             block)
            if status == noErr {
                watched.append(addresses[index])
            }
        }
    }

    private func detachFromDevice() {
        if deviceID != unknownDevice, let block = deviceListener {
            for var address in watched {
                AudioObjectRemovePropertyListenerBlock(deviceID, &address, DispatchQueue.main, block)
            }
        }
        watched = []
    }
}
