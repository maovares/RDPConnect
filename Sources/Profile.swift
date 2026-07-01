import Foundation

struct Profile: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String = "Nuevo perfil"
    var host: String = ""
    var port: String = "3389"
    var username: String = ""
    var password: String = ""
    var dynamicResolution: Bool = true
    var ignoreCert: Bool = true
    var extraFlags: String = ""

    /// La contraseña nunca se serializa a profiles.json: vive solo en memoria y en el
    /// Keychain (ver KeychainStore). ProfileStore sincroniza el campo en load()/save().
    enum CodingKeys: String, CodingKey {
        case id, name, host, port, username, dynamicResolution, ignoreCert, extraFlags
    }

    var validationError: String? {
        if host.trimmingCharacters(in: .whitespaces).isEmpty {
            return "El host es obligatorio"
        }
        guard let portNumber = Int(port), (1...65535).contains(portNumber) else {
            return "El puerto debe ser un número entre 1 y 65535"
        }
        return nil
    }

    var arguments: [String] {
        var args = [
            "/v:\(host):\(port)",
            "/u:\(username)",
            "/p:\(password)",
        ]
        if dynamicResolution { args.append("+dynamic-resolution") }
        if ignoreCert { args.append("/cert:ignore") }
        args.append(contentsOf: Profile.tokenize(extraFlags))
        return args
    }

    /// Tokeniza como una shell simple: separa por espacios pero respeta comillas
    /// simples/dobles, para poder escribir flags cuyo valor contiene espacios
    /// (ej. rutas en /drive:).
    private static func tokenize(_ input: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var quote: Character?
        var hasContent = false
        for char in input {
            if let q = quote {
                if char == q {
                    quote = nil
                } else {
                    current.append(char)
                }
                hasContent = true
            } else if char == "\"" || char == "'" {
                quote = char
                hasContent = true
            } else if char.isWhitespace {
                if hasContent {
                    tokens.append(current)
                    current = ""
                    hasContent = false
                }
            } else {
                current.append(char)
                hasContent = true
            }
        }
        if hasContent { tokens.append(current) }
        return tokens
    }
}
