import Foundation

enum RDPLauncher {
    private static let candidatePaths = [
        "/opt/homebrew/bin/sdl-freerdp",
        "/usr/local/bin/sdl-freerdp",
    ]

    private static let argsEnvKey = "RDPCONNECT_ARGS"

    static var binaryPath: String? {
        BinaryLocator.find("sdl-freerdp", fallbacks: candidatePaths)
    }

    /// Lanza sdl-freerdp. Los argumentos (incluida la contraseña) se pasan por una
    /// variable de entorno vía `/args-from:env:`, no como argv directo, para que la
    /// contraseña no quede visible en `ps aux` para otros procesos del mismo usuario.
    ///
    /// Nota: se probó primero `/from-stdin`, pero tiene un bug conocido en FreeRDP 3.x
    /// que rompe la negociación NLA (ERRCONNECT_CONNECT_CANCELLED). `/args-from:env:`
    /// reutiliza el parsing estándar de `/p:`, que es el camino bien probado.
    ///
    /// `onExit` se invoca en el hilo principal solo si el proceso termina casi de
    /// inmediato con código de error (típico de un fallo al conectar), para no
    /// molestar al usuario cuando simplemente cierra una sesión que funcionó bien.
    static func launch(_ profile: Profile, onExit: ((String) -> Void)? = nil) throws {
        guard let binary = binaryPath else {
            throw LaunchError.binaryNotFound
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: binary)
        task.arguments = ["/args-from:env:\(argsEnvKey)"]

        var environment = ProcessInfo.processInfo.environment
        environment[argsEnvKey] = profile.arguments.joined(separator: "\n")
        task.environment = environment

        let stderrPipe = Pipe()
        task.standardOutput = FileHandle.nullDevice
        task.standardError = stderrPipe

        let launchedAt = Date()
        task.terminationHandler = { process in
            let elapsed = Date().timeIntervalSince(launchedAt)
            guard process.terminationStatus != 0, elapsed < 3, let onExit else { return }
            let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async {
                onExit(message?.isEmpty == false ? message! : "sdl-freerdp finalizó con error (código \(process.terminationStatus)).")
            }
        }

        try task.run()
    }

    enum LaunchError: LocalizedError {
        case binaryNotFound
        var errorDescription: String? {
            "No se encontró sdl-freerdp. Instalalo con: brew install freerdp"
        }
    }
}
