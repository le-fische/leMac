//
//  ClipboardHistoryManager.swift
//  boringNotch
//
//  Created for boringNotch Supercharged Shelf.
//

import AppKit
import Combine
import Foundation

struct ClipboardItem: Identifiable, Equatable {
    let id: UUID = UUID()
    let text: String
    let timestamp: Date = Date()
    let isURL: Bool
    
    var preview: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 60 {
            return String(trimmed.prefix(60)) + "…"
        }
        return trimmed
    }
}

@MainActor
final class ClipboardHistoryManager: ObservableObject {
    static let shared = ClipboardHistoryManager()

    @Published var history: [ClipboardItem] = []
    @Published var isEnabled: Bool = true

    private var changeCount: Int = 0
    private var timer: AnyCancellable?
    private let maxItems = 15

    private init() {
        changeCount = NSPasteboard.general.changeCount
        startMonitoring()
    }

    func startMonitoring() {
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkForChanges()
            }
    }

    func checkForChanges() {
        guard isEnabled else { return }
        let currentCount = NSPasteboard.general.changeCount
        guard currentCount != changeCount else { return }
        changeCount = currentCount

        if let string = NSPasteboard.general.string(forType: .string),
           !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let isURL = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines))?.scheme != nil
            
            // Deduplicate if already top item
            if let first = history.first, first.text == string {
                return
            }
            
            let item = ClipboardItem(text: string, isURL: isURL)
            history.insert(item, at: 0)
            if history.count > maxItems {
                history.removeLast()
            }
        }
    }

    func copyToPasteboard(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(item.text, forType: .string)
        changeCount = pb.changeCount
    }

    func pinToShelf(_ item: ClipboardItem) {
        if item.isURL, let url = URL(string: item.text.trimmingCharacters(in: .whitespacesAndNewlines)) {
            let shelfItem = ShelfItem(kind: .link(url: url))
            ShelfStateViewModel.shared.add([shelfItem])
        } else {
            let shelfItem = ShelfItem(kind: .text(string: item.text))
            ShelfStateViewModel.shared.add([shelfItem])
        }
    }

    func clearHistory() {
        history.removeAll()
    }
}
