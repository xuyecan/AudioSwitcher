//
//  AudioSwitcherApp.swift
//  AudioSwitcher
//
//  Created by xuyecan on 2024/7/17.
//

import SwiftUI
import CoreAudio

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!
    var popover: NSPopover!
    var audioDeviceManager: AudioDeviceManager!
    var volumeObserver: Any?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        audioDeviceManager = AudioDeviceManager()

        // Create the SwiftUI view that provides the popover contents
        let contentView = PopoverView(audioDeviceManager: audioDeviceManager)

        // Create the popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 420) // Increased height to accommodate the quit button
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)
        self.popover = popover

        // Create the status item
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusBarItem.button {
            button.image = NSImage(systemSymbolName: "headphones", accessibilityDescription: "Audio Devices")
            button.action = #selector(togglePopover(_:))
        }

        // Set up volume observer
        let defaultOutputDeviceID = AudioDeviceID(0)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        volumeObserver = AudioObjectAddPropertyListenerBlock(defaultOutputDeviceID, &address, nil) { (_, _) in
            self.audioDeviceManager.updateVolume()
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Remove volume observer
        if let observer = volumeObserver as? AudioObjectPropertyListenerBlock {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(AudioDeviceID(0), &address, DispatchQueue.main, observer)
        }
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusBarItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)

                // Ensure the popover is the key window
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
}
