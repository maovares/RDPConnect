import Foundation
import Security

/// Guarda las contraseñas de los perfiles en el Keychain de macOS en vez de en
/// profiles.json en texto plano. Cada perfil usa su UUID como cuenta dentro del
/// mismo servicio.
enum KeychainStore {
    private static let service = "com.maovares.rdpconnect"

    static func savePassword(_ password: String, for id: UUID) {
        if password.isEmpty {
            deletePassword(for: id)
            return
        }
        let data = Data(password.utf8)
        let query = baseQuery(account: id.uuidString)

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        } else {
            var attributes = query
            attributes[kSecValueData as String] = data
            SecItemAdd(attributes as CFDictionary, nil)
        }
    }

    static func loadPassword(for id: UUID) -> String {
        var query = baseQuery(account: id.uuidString)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func deletePassword(for id: UUID) {
        SecItemDelete(baseQuery(account: id.uuidString) as CFDictionary)
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}