//
//  PopoverView.swift
//  AudioSwitcher
//
//  Created by xuyecan on 2024/7/17.
//

import SwiftUI

struct PopoverView: View {
    @ObservedObject var audioDeviceManager: AudioDeviceManager

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                HStack {
                    Spacer()
                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        Text("Quit")
                            .foregroundColor(.black)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.blue)
                    .cornerRadius(4)
                }

                Text("Audio Switcher")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
            }
            .padding(.bottom, 5)

            HStack {
                Text("Output Devices")
                    .font(.headline)
                Spacer()
            }
            ForEach(audioDeviceManager.outputDevices, id: \.0) { device in
                DeviceRow(name: device.1, isActive: device.2) {
                    audioDeviceManager.switchAudioDevice(to: device.0, isOutput: true)
                }
            }

            // Add volume slider here
            VStack {
                HStack {
                    Image(systemName: "speaker.fill")

                    Slider(value: Binding(
                        get: { self.audioDeviceManager.volume },
                        set: { self.audioDeviceManager.setVolume($0) }
                    ), in: 0...1)
                    .tint(.blue)

                    Image(systemName: "speaker.wave.3.fill")
                }
                .padding(.top, 5)
            }

            Divider()

            HStack {
                Text("Input Devices")
                    .font(.headline)
                Spacer()
            }
            ForEach(audioDeviceManager.inputDevices, id: \.0) { device in
                DeviceRow(name: device.1, isActive: device.2) {
                    audioDeviceManager.switchAudioDevice(to: device.0, isOutput: false)
                }
            }
        }
        .padding()
        .frame(width: 300)
    }
}
