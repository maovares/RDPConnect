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

    var arguments: [String] {
        var args = [
            "/v:\(host):\(port)",
            "/u:\(username)",
            "/p:\(password)",
        ]
        if dynamicResolution { args.append("+dynamic-resolution") }
        if ignoreCert { args.append("/cert:ignore") }
        let extra = extraFlags.split(separator: " ").map(String.init)
        args.append(contentsOf: extra)
        return args
    }
}
