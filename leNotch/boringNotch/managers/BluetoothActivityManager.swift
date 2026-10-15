//
//  BluetoothActivityManager.swift
//  boringNotch
//
//  Created for boringNotch Bluetooth Live Activity.
//

import AppKit
import Combine
import Defaults
import Foundation
import IOBluetooth
import IOKit

struct BluetoothDeviceInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let isConnected: Bool
    let batteryLevel: Int?
    let iconName: String
}

final class BluetoothActivityManager: NSObject, ObservableObject {
    static let shared = BluetoothActivityManager()

    @Published var connectedDevices: [BluetoothDeviceInfo] = []
    private var connectNotification: IOBluetoothUserNotification?
    private var registeredDevices: [String: IOBluetoothUserNotification] = [:]

    override private init() {
        super.init()
        setupListeners()
    }

    func setupListeners() {
        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(deviceConnected(_:device:))
        )
        refreshDevices(notifyChanges: false)
    }

    @objc func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        let name = device.nameOrAddress ?? "Bluetooth Device"
        let icon = iconForDevice(name: name)
        let battery = queryBatteryForDevice(name: name)
        
        registerDisconnect(for: device)
        
        DispatchQueue.main.async {
            self.refreshDevices(notifyChanges: false)
            if Defaults[.enableBluetoothLiveActivity] {
                BoringViewCoordinator.shared.toggleSneakPeek(
                    status: true,
                    type: .bluetooth,
                    duration: 2.8,
                    value: battery != nil ? CGFloat(battery!) / 100.0 : 1.0,
                    icon: icon,
                    title: name,
                    subtitle: "Connected"
                )
            }
        }
    }

    @objc func deviceDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        let name = device.nameOrAddress ?? "Bluetooth Device"
        let icon = iconForDevice(name: name)
        
        DispatchQueue.main.async {
            self.refreshDevices(notifyChanges: false)
            if Defaults[.enableBluetoothLiveActivity] {
                BoringViewCoordinator.shared.toggleSneakPeek(
                    status: true,
                    type: .bluetooth,
                    duration: 2.5,
                    value: 0,
                    icon: icon,
                    title: name,
                    subtitle: "Disconnected"
                )
            }
        }
    }

    private func registerDisconnect(for device: IOBluetoothDevice) {
        guard let address = device.addressString else { return }
        if registeredDevices[address] == nil {
            let note = device.register(
                forDisconnectNotification: self,
                selector: #selector(deviceDisconnected(_:device:))
            )
            registeredDevices[address] = note
        }
    }

    func refreshDevices(notifyChanges: Bool = false) {
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return }
        var current: [BluetoothDeviceInfo] = []

        for device in paired where device.isConnected() {
            registerDisconnect(for: device)
            let name = device.nameOrAddress ?? "Bluetooth Device"
            let icon = iconForDevice(name: name)
            let battery = queryBatteryForDevice(name: name)
            current.append(
                BluetoothDeviceInfo(
                    id: device.addressString ?? name,
                    name: name,
                    isConnected: true,
                    batteryLevel: battery,
                    iconName: icon
                )
            )
        }

        DispatchQueue.main.async {
            self.connectedDevices = current
        }
    }

    func iconForDevice(name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("airpod") {
            if lower.contains("max") {
                return "headphones"
            }
            return "airpodspro"
        } else if lower.contains("beat") || lower.contains("headphone") || lower.contains("wh-") || lower.contains("qc") {
            return "headphones"
        } else if lower.contains("mouse") {
            return "magicmouse"
        } else if lower.contains("keyboard") {
            return "keyboard"
        } else if lower.contains("trackpad") {
            return "trackpad"
        } else if lower.contains("speaker") || lower.contains("sound") {
            return "hifispeaker"
        } else if lower.contains("watch") {
            return "applewatch"
        } else if lower.contains("phone") {
            return "iphone"
        } else if lower.contains("ipad") {
            return "ipad"
        }
        return "wave.3.right.circle.fill"
    }

    func queryBatteryForDevice(name: String) -> Int? {
        let matching = IOServiceMatching("AppleDeviceManagementHIDEventService")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == kIOReturnSuccess else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            var unmanagedDict: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &unmanagedDict, kCFAllocatorDefault, 0) == kIOReturnSuccess,
               let dict = unmanagedDict?.takeRetainedValue() as? [String: Any] {
                if let prod = dict["Product"] as? String, prod.localizedCaseInsensitiveContains(name) || name.localizedCaseInsensitiveContains(prod) {
                    if let battery = dict["BatteryPercent"] as? Int {
                        return battery
                    }
                }
            }
        }
        return nil
    }
}
