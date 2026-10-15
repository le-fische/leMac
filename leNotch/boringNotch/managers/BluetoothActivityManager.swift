//
//  BluetoothActivityManager.swift
//  boringNotch
//
//  Inert stub: Bluetooth peripheral tracking removed per user request.
//

import Foundation

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
    override private init() { super.init() }
}
