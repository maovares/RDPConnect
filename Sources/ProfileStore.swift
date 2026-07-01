import Foundation

final class ProfileStore {
    private(set) var profiles: [Profile] = []

    private let fileURL: URL
    private var pendingSaveWorkItem: DispatchWorkItem?
    private var pendingPasswordProfile: Profile?

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("RDPConnect", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("profiles.json")
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        guard var decoded = try? JSONDecoder().decode([Profile].self, from: data) else { return }
        for index in decoded.indices {
            decoded[index].password = KeychainStore.loadPassword(for: decoded[index].id)
        }
        profiles = decoded
    }

    /// Persiste inmediatamente, cancelando cualquier guardado diferido pendiente.
    func save() {
        pendingSaveWorkItem?.cancel()
        pendingSaveWorkItem = nil
        pendingPasswordProfile = nil
        writeToDisk()
    }

    /// Fuerza que un guardado diferido pendiente se aplique ya (usado al salir de la app).
    func flush() {
        guard pendingSaveWorkItem != nil else { return }
        pendingSaveWorkItem?.cancel()
        pendingSaveWorkItem = nil
        commitPendingPassword()
        writeToDisk()
    }

    func addProfile() -> Profile {
        let profile = Profile()
        profiles.append(profile)
        save()
        return profile
    }

    func duplicate(_ profile: Profile) -> Profile {
        var copy = profile
        copy.id = UUID()
        copy.name = profile.name + " copia"
        profiles.append(copy)
        KeychainStore.savePassword(copy.password, for: copy.id)
        save()
        return copy
    }

    func delete(_ profile: Profile) {
        profiles.removeAll { $0.id == profile.id }
        KeychainStore.deletePassword(for: profile.id)
        save()
    }

    /// Actualiza el perfil en memoria y difiere el guardado a disco/Keychain unos
    /// milisegundos, para no golpearlos en cada tecla presionada en el formulario.
    func update(_ profile: Profile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index] = profile

        pendingSaveWorkItem?.cancel()
        pendingPasswordProfile = profile
        let work = DispatchWorkItem { [weak self] in
            self?.pendingSaveWorkItem = nil
            self?.commitPendingPassword()
            self?.writeToDisk()
        }
        pendingSaveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func exportJSON() -> Data? {
        try? JSONEncoder().encode(profiles)
    }

    func importJSON(_ data: Data) throws {
        let imported = try JSONDecoder().decode([Profile].self, from: data)
        for var profile in imported {
            profile.id = UUID()
            profiles.append(profile)
        }
        save()
    }

    private func commitPendingPassword() {
        guard let profile = pendingPasswordProfile else { return }
        pendingPasswordProfile = nil
        KeychainStore.savePassword(profile.password, for: profile.id)
    }

    private func writeToDisk() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
