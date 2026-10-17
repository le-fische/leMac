#!/usr/bin/env swift
import Foundation
import CryptoKit

// ==============================================================================
// Sparkle Update Signer & Appcast Generator for leMinibar
// ==============================================================================

struct SignerConfig {
    var archivePath: String = ""
    var version: String = "1.0.0"
    var buildNumber: String = "1"
    var appcastPath: String = ""
    var keyPath: String = ""
    var releaseNotes: String = "Maintenance release with performance and stability improvements."
}

var config = SignerConfig()

var args = CommandLine.arguments.dropFirst()
while let arg = args.first {
    args = args.dropFirst()
    switch arg {
    case "--archive":
        if let val = args.first { config.archivePath = val; args = args.dropFirst() }
    case "--version":
        if let val = args.first { config.version = val; args = args.dropFirst() }
    case "--build":
        if let val = args.first { config.buildNumber = val; args = args.dropFirst() }
    case "--appcast":
        if let val = args.first { config.appcastPath = val; args = args.dropFirst() }
    case "--key":
        if let val = args.first { config.keyPath = val; args = args.dropFirst() }
    case "--notes":
        if let val = args.first { config.releaseNotes = val; args = args.dropFirst() }
    default:
        break
    }
}

guard !config.archivePath.isEmpty else {
    print("Error: --archive path is required")
    exit(1)
}

let archiveURL = URL(fileURLWithPath: config.archivePath)
guard FileManager.default.fileExists(atPath: archiveURL.path) else {
    print("Error: Archive not found at \(archiveURL.path)")
    exit(1)
}

// 1. Resolve private key
var privateKeyBase64: String? = ProcessInfo.processInfo.environment["SPARKLE_PRIVATE_KEY"]

if privateKeyBase64 == nil || privateKeyBase64!.isEmpty {
    if !config.keyPath.isEmpty && FileManager.default.fileExists(atPath: config.keyPath) {
        privateKeyBase64 = try? String(contentsOfFile: config.keyPath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    } else {
        let scriptDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
        let localKey = scriptDir.appendingPathComponent("sparkle_priv.key").path
        let notchKey = scriptDir.appendingPathComponent("../leNotch/Configuration/sparkle/sparkle_priv.key").path
        if FileManager.default.fileExists(atPath: localKey) {
            privateKeyBase64 = try? String(contentsOfFile: localKey, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if FileManager.default.fileExists(atPath: notchKey) {
            privateKeyBase64 = try? String(contentsOfFile: notchKey, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

guard let privStr = privateKeyBase64, !privStr.isEmpty,
      let keyData = Data(base64Encoded: privStr),
      let signingKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: keyData) else {
    print("Warning: Valid Sparkle private key not found (checked SPARKLE_PRIVATE_KEY env and sparkle_priv.key files). Skipping appcast update.")
    exit(0)
}

// 2. Compute signature
let archiveData = try Data(contentsOf: archiveURL)
let signature = try signingKey.signature(for: archiveData)
let sigBase64 = signature.base64EncodedString()
let pubKey = signingKey.publicKey.rawRepresentation.base64EncodedString()

print("--> Successfully signed \(archiveURL.lastPathComponent)")
print("    Archive size:      \(archiveData.count) bytes")
print("    Public Key:        \(pubKey)")
print("    Ed25519 Signature: \(sigBase64)")

// 3. Update appcast.xml if requested
if !config.appcastPath.isEmpty {
    let appcastURL = URL(fileURLWithPath: config.appcastPath)
    let fileName = archiveURL.lastPathComponent
    let downloadURL = "https://github.com/le-fische/leMac/releases/download/v\(config.version)/\(fileName)"

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    let pubDate = formatter.string(from: Date())

    let newItemXML = """
        <item>
            <title>Version \(config.version)</title>
            <pubDate>\(pubDate)</pubDate>
            <sparkle:version>\(config.buildNumber)</sparkle:version>
            <sparkle:shortVersionString>\(config.version)</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
            <description><![CDATA[
                <h2>leMinibar \(config.version)</h2>
                <p>\(config.releaseNotes)</p>
            ]]></description>
            <enclosure
                url="\(downloadURL)"
                sparkle:edSignature="\(sigBase64)"
                length="\(archiveData.count)"
                type="application/octet-stream" />
        </item>
"""

    let fullXML = """
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>leMinibar Updates</title>
        <link>https://raw.githubusercontent.com/le-fische/leMac/main/leMinibar/appcast.xml</link>
        <description>Automatic software update feed for leMinibar.</description>
        <language>en</language>
\(newItemXML)
    </channel>
</rss>
"""

    try fullXML.write(to: appcastURL, atomically: true, encoding: .utf8)
    print("--> Updated appcast at \(appcastURL.path)")
}
