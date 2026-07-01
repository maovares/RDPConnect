import Foundation

enum TailscaleState {
    case connected
    case disconnected
    case notInstalled
    case unknown
}

enum TailscaleChecker {
    private static let candidatePaths = [
        "/usr/local/bin/tailscale",
        "/opt/homebrew/bin/tailscale",
        "/Applications/Tailscale.app/Contents/MacOS/Tailscale",
    ]

    static func check() async -> TailscaleState {
        guard let binary = candidatePaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return .notInstalled
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: binary)
        task.arguments = ["status", "--json"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
        } catch {
            return .unknown
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        guard task.terminationStatus == 0,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let backendState = json["BackendState"] as? String
        else {
            return .unknown
        }

        return backendState == "Running" ? .connected : .disconnected
    }
}
