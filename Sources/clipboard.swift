import Foundation
import AppKit
import CommonCrypto

struct ClipboardEntry: Codable {
    let content: String
    let date: Date
    private(set) var hash: String
    
    init(content: String, date: Date) {
        self.content = content
        self.date = date
        self.hash = ClipboardEntry.computeHash(for: content, date: date)
    }
    
    private static func computeHash(for content: String, date: Date) -> String {
        let input = content + "\(date.timeIntervalSince1970)"
        return sha256(input)
    }
    
    private static func sha256(_ input: String) -> String {
        guard let data = input.data(using: .utf8) else { return "" }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

class ClipboardManager {
    static let shared = ClipboardManager()
    private(set) var clipboardHistory: [ClipboardEntry] = []
    private var timer: Timer?
    private let pollingInterval: TimeInterval = 1.0 // Polling interval in seconds

    private init() {
        // Load clipboard history when the class is initialized
        self.clipboardHistory = loadClipboardHistory()
        // Start polling the clipboard
        startPolling()
    }

    private func getClipboardHistoryFilePath() -> URL {
        let fileManager = FileManager.default
        let appSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupportDirectory.appendingPathComponent("ClipboardModifier")

        if (!fileManager.fileExists(atPath: appDirectory.path)) {
            try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
        }

        return appDirectory.appendingPathComponent("clipboardHistory.json")
    }

    func saveClipboardHistory() {
        let filePath = getClipboardHistoryFilePath()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(clipboardHistory) {
            try? data.write(to: filePath)
        }
    }

    private func loadClipboardHistory() -> [ClipboardEntry] {
        let filePath = getClipboardHistoryFilePath()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let data = try? Data(contentsOf: filePath),
           let history = try? decoder.decode([ClipboardEntry].self, from: data) {
            return history
        }

        return []
    }

    func getClipboardContent() -> String? {
        let pasteboard = NSPasteboard.general

        if let content = pasteboard.string(forType: .string) {
            return content
        }

        // If pasteboard is empty, return the last entry from clipboard history
        return clipboardHistory.last?.content
    }

    func addCurrentClipboardToHistory() {
        if let currentContent = getClipboardContent() {
            
            let newEntry = ClipboardEntry(content: currentContent, date: Date())
            if let lastEntry = clipboardHistory.last, lastEntry.content == newEntry.content {
                // If the last entry is the same as the new entry, do not add it again
                return
            }
            print(newEntry)
            clipboardHistory.append(newEntry)
            saveClipboardHistory()
            NotificationCenter.default.post(name: .clipboardUpdated, object: nil)
        }
    }

    func setClipboardContent(_ content: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
        addCurrentClipboardToHistory()
    }

    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            print("polling clipboard")
            self?.addCurrentClipboardToHistory()
        }
    }

    private func stopPolling() {
        saveClipboardHistory()

        timer?.invalidate()
        timer = nil
    }

    deinit {
        stopPolling()
    }
}

extension Notification.Name {
    static let clipboardUpdated = Notification.Name("clipboardUpdated")
}
