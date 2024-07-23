//
//  AudioDeviceManager.swift
//  AudioSwitcher
//
//  Created by xuyecan on 2024/7/17.
//

import Foundation
import CoreAudio
import Cocoa
import SwiftUI
import AudioToolbox

class AudioDeviceManager: ObservableObject {
    @Published var outputDevices: [(AudioDeviceID, String, Bool)] = []
    @Published var inputDevices: [(AudioDeviceID, String, Bool)] = []
    @Published var volume: Float = 0.0

    init() {
        updateDevices()
        setupAudioDeviceChangeObserver()

        updateVolume()
    }

    func updateDevices() {
        let devices = getAudioDevices()
        let currentOutputID = getCurrentDefaultDeviceID(isOutput: true)
        let currentInputID = getCurrentDefaultDeviceID(isOutput: false)

        outputDevices = devices.filter { $0.2 }.map { ($0.0, $0.1, $0.0 == currentOutputID) }
        inputDevices = devices.filter { !$0.2 }.map { ($0.0, $0.1, $0.0 == currentInputID) }
    }

    private func setupAudioDeviceChangeObserver() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let status = AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            { (_, _, propertyAddress, clientData) -> OSStatus in
                let audioDeviceManager = Unmanaged<AudioDeviceManager>.fromOpaque(clientData!).takeUnretainedValue()
                DispatchQueue.main.async {
                    audioDeviceManager.updateDevices()
                    audioDeviceManager.updateVolume()
                }
                return noErr
            },
            selfPtr
        )

        if status != noErr {
            print("Error setting up audio device change listener: \(status)")
        }
    }

    private func getCurrentDefaultDeviceID(isOutput: Bool) -> AudioDeviceID {
        var address = AudioObjectPropertyAddress(
            mSelector: isOutput ? kAudioHardwarePropertyDefaultOutputDevice : kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)

        var deviceID: AudioDeviceID = 0
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let result = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                                &address,
                                                0,
                                                nil,
                                                &propertySize,
                                                &deviceID)

        if result != noErr {
            print("Error getting current default device: \(result)")
        }

        return deviceID
    }

    func getAudioDevices() -> [(AudioDeviceID, String, Bool)] {
        var propertySize: UInt32 = 0

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)

        var result = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject),
                                                    &address,
                                                    0,
                                                    nil,
                                                    &propertySize)

        guard result == noErr else {
            print("Error getting property size: \(result)")
            return []
        }

        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        result = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                            &address,
                                            0,
                                            nil,
                                            &propertySize,
                                            &deviceIDs)

        guard result == noErr else {
            print("Error getting device IDs: \(result)")
            return []
        }

        var devices: [(AudioDeviceID, String, Bool)] = []

        for deviceID in deviceIDs {
            var name: CFString = "" as CFString
            var propertySize = UInt32(MemoryLayout<CFString>.size)
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)

            result = AudioObjectGetPropertyData(deviceID,
                                                &nameAddress,
                                                0,
                                                nil,
                                                &propertySize,
                                                &name)

            guard result == noErr else {
                print("Error getting device name: \(result)")
                continue
            }

            // Check if the device has output channels
            var outputChannelCount: UInt32 = 0
            var outputChannelCountSize = UInt32(MemoryLayout<UInt32>.size)
            var outputChannelCountAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain)

            result = AudioObjectGetPropertyDataSize(deviceID,
                                                    &outputChannelCountAddress,
                                                    0,
                                                    nil,
                                                    &outputChannelCountSize)

            if result == noErr {
                var outputStreamConfiguration = AudioBufferList()
                result = AudioObjectGetPropertyData(deviceID,
                                                    &outputChannelCountAddress,
                                                    0,
                                                    nil,
                                                    &outputChannelCountSize,
                                                    &outputStreamConfiguration)

                if result == noErr {
                    outputChannelCount = outputStreamConfiguration.mBuffers.mNumberChannels
                }
            }

            let isOutput = outputChannelCount > 0
            devices.append((deviceID, name as String, isOutput))
        }

        return devices
    }

    func switchAudioDevice(to deviceID: AudioDeviceID, isOutput: Bool) {
        let propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let selector = isOutput ? kAudioHardwarePropertyDefaultOutputDevice : kAudioHardwarePropertyDefaultInputDevice

        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)

        var mutableDeviceID = deviceID  // Create a mutable copy

        let result = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                                &address,
                                                0,
                                                nil,
                                                propertySize,
                                                &mutableDeviceID)

        if result == noErr {
            print("Successfully switched \(isOutput ? "output" : "input") device")
            // Optionally update the AudioDeviceManager's state
            DispatchQueue.main.async {
                self.updateDevices()
            }
        } else {
            print("Error switching audio device: \(result)")
            // Optionally handle the error (e.g., show an alert to the user)
        }
    }

    func setVolume(_ newVolume: Float) {
        let defaultOutputDeviceID = getCurrentDefaultDeviceID(isOutput: true)

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var newVolumeValue = max(0.0, min(1.0, newVolume)) // Ensure volume is between 0 and 1
        let size = UInt32(MemoryLayout<Float32>.size)

        let status = AudioObjectSetPropertyData(
            defaultOutputDeviceID,
            &address,
            0,
            nil,
            size,
            &newVolumeValue
        )

        if status == noErr {
            DispatchQueue.main.async {
                self.volume = newVolumeValue
            }
        } else {
            let error = NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
            print("Error setting volume: \(error.localizedDescription) (Code: \(status))")
            updateVolume()
        }
    }

    func updateVolume() {
        let defaultOutputDeviceID = getCurrentDefaultDeviceID(isOutput: true)

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var volume: Float32 = 0.0
        var size = UInt32(MemoryLayout<Float32>.size)

        let status = AudioObjectGetPropertyData(defaultOutputDeviceID, &address, 0, nil, &size, &volume)

        if status == noErr {
            DispatchQueue.main.async {
                self.volume = volume
            }
        } else {
            let error = NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
            print("Error getting volume: \(error.localizedDescription) (Code: \(status))")
        }
    }
}
