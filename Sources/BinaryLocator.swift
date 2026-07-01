import Foundation

enum BinaryLocator {
    /// Busca un ejecutable por nombre en $PATH y, si no aparece, en una lista de rutas
    /// conocidas. Las apps lanzadas desde Finder suelen heredar un PATH mínimo que no
    /// incluye /opt/homebrew/bin ni /usr/local/bin, así que los fallbacks siguen
    /// siendo necesarios además de la búsqueda en PATH.
    static func find(_ name: String, fallbacks: [String]) -> String? {
        let fm = FileManager.default
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            for dir in pathEnv.split(separator: ":") {
                let candidate = "\(dir)/\(name)"
                if fm.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            }
        }
        return fallbacks.first(where: { fm.isExecutableFile(atPath: $0) })
    }
}
