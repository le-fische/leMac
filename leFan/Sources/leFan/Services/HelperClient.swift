import Foundation

public enum HelperStatus: Equatable {
    case connected
    case notInstalled
    case authorizing
    case error(String)

    public var isReady: Bool {
        return self == .connected
    }

    public var title: String {
        switch self {
        case .connected: return "Helper Active"
        case .notInstalled: return "Authorization Required"
        case .authorizing: return "Authorizing..."
        case .error(let msg): return "Helper Error: \(msg)"
        }
    }
}

public final class HelperClient {
    public static let shared = HelperClient()

    private let primarySocketPath = "/var/run/lefan.sock"
    private let fallbackSocketPath = "/tmp/lefan.sock"

    private init() {}

    public func checkStatus() -> HelperStatus {
        if testSocketConnection(primarySocketPath) || testSocketConnection(fallbackSocketPath) {
            return .connected
        }

        let installedPath = "/Library/PrivilegedHelperTools/com.le.lefan.helper"
        if FileManager.default.fileExists(atPath: installedPath) {
            return .notInstalled
        }

        return .notInstalled
    }

    private func testSocketConnection(_ path: String) -> Bool {
        guard FileManager.default.fileExists(atPath: path) else { return false }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let maxLen = MemoryLayout.size(ofValue: addr.sun_path)
        withUnsafeMutablePointer(to: &addr.sun_path.0) { ptr in
            path.withCString { cstr in
                _ = strncpy(ptr, cstr, maxLen - 1)
            }
        }

        let size = socklen_t(MemoryLayout<sockaddr_un>.size)
        let res = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                connect(fd, sa, size)
            }
        }

        if res == 0 {
            let msg = "ping\n"
            _ = write(fd, msg, msg.utf8.count)
            var buf = [CChar](repeating: 0, count: 128)
            let n = read(fd, &buf, 127)
            return n > 0
        }
        return false
    }

    private func sendSocketCommand(_ cmd: String) -> Bool {
        let paths = [primarySocketPath, fallbackSocketPath]
        for path in paths {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let fd = socket(AF_UNIX, SOCK_STREAM, 0)
            guard fd >= 0 else { continue }

            var addr = sockaddr_un()
            addr.sun_family = sa_family_t(AF_UNIX)
            let maxLen = MemoryLayout.size(ofValue: addr.sun_path)
            withUnsafeMutablePointer(to: &addr.sun_path.0) { ptr in
                path.withCString { cstr in
                    _ = strncpy(ptr, cstr, maxLen - 1)
                }
            }

            let size = socklen_t(MemoryLayout<sockaddr_un>.size)
            let res = withUnsafePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    connect(fd, sa, size)
                }
            }

            if res == 0 {
                let formatted = cmd.hasSuffix("\n") ? cmd : cmd + "\n"
                _ = write(fd, formatted, formatted.utf8.count)
                var buf = [CChar](repeating: 0, count: 256)
                let n = read(fd, &buf, 255)
                close(fd)
                if n > 0 {
                    let resp = String(cString: buf)
                    return resp.contains("\"status\":\"ok\"")
                }
            } else {
                close(fd)
            }
        }
        return false
    }

    public func setFanMode(fanIndex: Int, mode: FanControlMode, targetRPM: Double) -> Bool {
        switch mode {
        case .auto:
            return sendSocketCommand("set \(fanIndex) auto 0")
        case .constant, .sensorCurve:
            return sendSocketCommand("set \(fanIndex) manual \(Int(targetRPM))")
        }
    }

    public func setAllFansAuto() -> Bool {
        return sendSocketCommand("set-all auto 0")
    }

    public func installHelper(scriptPath: String, completion: @escaping (Bool, String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let possibleBins = [
                Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/lefan-helper").path,
                "/Applications/leFan.app/Contents/MacOS/lefan-helper",
                "/Users/le/Documents/Projects/leMac/leFan/.build/release/lefan-helper",
                "/Users/le/Documents/Projects/leMac/leFan/.build/debug/lefan-helper",
                "/Users/le/Documents/Projects/leMac/leFan/Sources/Helper/lefan-helper",
                "/Users/le/Downloads/leFan/.build/release/lefan-helper"
            ]
            guard let helperSource = possibleBins.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
                DispatchQueue.main.async { completion(false, "Helper binary not found") }
                return
            }

            let possiblePlists = [
                Bundle.main.path(forResource: "com.le.lefan.helper", ofType: "plist"),
                "/Applications/leFan.app/Contents/Resources/com.le.lefan.helper.plist",
                "/Users/le/Documents/Projects/leMac/leFan/Sources/Helper/com.le.lefan.helper.plist",
                "/Users/le/Downloads/leFan/Sources/Helper/com.le.lefan.helper.plist"
            ].compactMap { $0 }
            guard let plistSource = possiblePlists.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
                DispatchQueue.main.async { completion(false, "Helper plist not found") }
                return
            }

            let stagedBin = "/tmp/lefan-helper-staged"
            let stagedPlist = "/tmp/lefan-helper-staged.plist"
            try? FileManager.default.removeItem(atPath: stagedBin)
            try? FileManager.default.removeItem(atPath: stagedPlist)
            do {
                try FileManager.default.copyItem(atPath: helperSource, toPath: stagedBin)
                try FileManager.default.copyItem(atPath: plistSource, toPath: stagedPlist)
            } catch {
                DispatchQueue.main.async { completion(false, "Failed to stage installer files: \(error.localizedDescription)") }
                return
            }

            let shellCmd = """
            mkdir -p /Library/PrivilegedHelperTools /Library/LaunchDaemons && \
            cp -f '\(stagedBin)' /Library/PrivilegedHelperTools/com.le.lefan.helper && \
            chown root:wheel /Library/PrivilegedHelperTools/com.le.lefan.helper && \
            chmod 755 /Library/PrivilegedHelperTools/com.le.lefan.helper && \
            cp -f '\(stagedPlist)' /Library/LaunchDaemons/com.le.lefan.helper.plist && \
            chown root:wheel /Library/LaunchDaemons/com.le.lefan.helper.plist && \
            chmod 644 /Library/LaunchDaemons/com.le.lefan.helper.plist && \
            (launchctl kickstart -k system/com.le.lefan.helper 2>/dev/null || launchctl bootstrap system /Library/LaunchDaemons/com.le.lefan.helper.plist 2>/dev/null || launchctl load -w /Library/LaunchDaemons/com.le.lefan.helper.plist 2>/dev/null) && \
            rm -f '\(stagedBin)' '\(stagedPlist)'
            """

            let appleScript = "do shell script \"\(shellCmd)\" with administrator privileges"
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: appleScript) {
                let output = scriptObject.executeAndReturnError(&error)
                DispatchQueue.main.async {
                    if let error = error {
                        let errMsg = error[NSAppleScript.errorMessage] as? String ?? "Authorization canceled"
                        completion(false, errMsg)
                    } else {
                        Thread.sleep(forTimeInterval: 1.0)
                        completion(true, output.stringValue)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(false, "Failed to create AppleScript authorization")
                }
            }
        }
    }
}
