//
//  MenuBarView.swift
//  AudioSwitcher
//
//  Created by xuyecan on 2024/7/17.
//

import SwiftUI

struct MenuBarView: View {
    @StateObject private var audioDeviceManager = AudioDeviceManager()

    var body: some View {
        VStack {
            Text("Output Devices")
                .font(.headline)
            ForEach(audioDeviceManager.outputDevices, id: \.0) { device in
                DeviceRow(name: device.1, isActive: device.2) {
                    audioDeviceManager.switchAudioDevice(to: device.0, isOutput: true)
                }
            }

            Divider()

            Text("Input Devices")
                .font(.headline)
            ForEach(audioDeviceManager.inputDevices, id: \.0) { device in
                DeviceRow(name: device.1, isActive: device.2) {
                    audioDeviceManager.switchAudioDevice(to: device.0, isOutput: false)
                }
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

struct DeviceRow: View {
    let name: String
    let isActive: Bool
    let switchAction: () -> Void

    private let buttonWidth: CGFloat = 70

    var body: some View {
        HStack {
            Text(name)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            HStack {
                Spacer()
                if isActive {
                    Button("Active") {
                        // noting to do
                    }
                    .frame(width: buttonWidth)
                    .foregroundColor(.gray)
                    .padding(.vertical, 2)
                    .cornerRadius(4)
                    .disabled(true)
                } else {
                    Button("Switch") {
                        switchAction()
                    }
                    .frame(width: buttonWidth)
                    .padding(.vertical, 2)
                    .foregroundColor(.white)
                    .cornerRadius(4)
                }
            }
            .frame(width: buttonWidth + 16)
        }
        .padding(.vertical, 2)
    }
}
