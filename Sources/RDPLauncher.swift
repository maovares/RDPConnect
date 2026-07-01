import Foundation

enum RDPLauncher {
    private static let candidatePaths = [
        "/opt/homebrew/bin/sdl-freerdp",
        "/usr/local/bin/sdl-freerdp",
    ]

    static var binaryPath: String? {
        candidatePaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) })
    }

    static func launch(_ profile: Profile) throws {
        guard let binary = binaryPath else {
            throw LaunchError.binaryNotFound
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: binary)
        task.arguments = profile.arguments
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try task.run()
    }

    enum LaunchError: LocalizedError {
        case binaryNotFound
        var errorDescription: String? {
            "No se encontró sdl-freerdp. Instalalo con: brew install freerdp"
        }
    }
}
