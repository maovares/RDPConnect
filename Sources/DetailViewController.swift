import AppKit

final class DetailViewController: NSViewController, NSTextFieldDelegate {
    var onChange: ((Profile) -> Void)?
    var onConnect: ((Profile) -> Void)?

    private var profile: Profile?

    private let nameField = NSTextField(string: "")
    private let hostField = NSTextField(string: "")
    private let portField = NSTextField(string: "")
    private let userField = NSTextField(string: "")
    private let passwordField = NSSecureTextField(string: "")
    private let dynResCheckbox = NSButton(checkboxWithTitle: "Resolución dinámica (+dynamic-resolution)", target: nil, action: nil)
    private let certCheckbox = NSButton(checkboxWithTitle: "Ignorar certificado (/cert:ignore)", target: nil, action: nil)
    private let extraFlagsField = NSTextField(string: "")
    private let tailscaleLabel = NSTextField(labelWithString: "Verificando Tailscale…")
    private let connectButton = NSButton(title: "Conectar", target: nil, action: nil)
    private let emptyLabel = NSTextField(labelWithString: "Elegí un perfil o creá uno nuevo con +")
    private let formContainer = NSView()

    override func loadView() {
        let container = NSView()

        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        buildForm()
        formContainer.translatesAutoresizingMaskIntoConstraints = false
        formContainer.isHidden = true

        container.addSubview(emptyLabel)
        container.addSubview(formContainer)

        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            formContainer.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
            formContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            formContainer.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -24),
        ])

        view = container
    }

    private func buildForm() {
        for field in [nameField, hostField, portField, userField, passwordField, extraFlagsField] {
            field.delegate = self
        }
        portField.placeholderString = "3389"
        extraFlagsField.placeholderString = "/multimon /drive:home,~"

        dynResCheckbox.target = self
        dynResCheckbox.action = #selector(fieldsChanged)
        certCheckbox.target = self
        certCheckbox.action = #selector(fieldsChanged)

        connectButton.bezelStyle = .rounded
        connectButton.keyEquivalent = "\r"
        connectButton.target = self
        connectButton.action = #selector(connectTapped)

        let grid = NSGridView(views: [
            [label("Nombre"), nameField],
            [label("Host"), hostField],
            [label("Puerto"), portField],
            [label("Usuario"), userField],
            [label("Contraseña"), passwordField],
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 10
        grid.columnSpacing = 12
        grid.column(at: 1).width = 320

        let bottomRow = NSStackView(views: [tailscaleLabel, NSView(), connectButton])
        bottomRow.orientation = .horizontal
        bottomRow.translatesAutoresizingMaskIntoConstraints = false
        bottomRow.distribution = .fill

        let stack = NSStackView(views: [grid, dynResCheckbox, certCheckbox, extraFlagsField, spacer(height: 8), bottomRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        formContainer.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: formContainer.topAnchor),
            stack.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: formContainer.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: formContainer.bottomAnchor),
            extraFlagsField.widthAnchor.constraint(equalToConstant: 320),
            bottomRow.widthAnchor.constraint(equalToConstant: 320),
        ])
    }

    private func label(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.alignment = .right
        return l
    }

    private func spacer(height: CGFloat) -> NSView {
        let v = NSView()
        v.heightAnchor.constraint(equalToConstant: height).isActive = true
        return v
    }

    func setProfile(_ profile: Profile?) {
        self.profile = profile
        formContainer.isHidden = profile == nil
        emptyLabel.isHidden = profile != nil
        guard let profile else { return }
        nameField.stringValue = profile.name
        hostField.stringValue = profile.host
        portField.stringValue = profile.port
        userField.stringValue = profile.username
        passwordField.stringValue = profile.password
        dynResCheckbox.state = profile.dynamicResolution ? .on : .off
        certCheckbox.state = profile.ignoreCert ? .on : .off
        extraFlagsField.stringValue = profile.extraFlags
        view.window?.title = profile.name.isEmpty ? "RDPConnect" : profile.name
    }

    func setTailscaleState(_ state: TailscaleState) {
        switch state {
        case .connected:
            tailscaleLabel.stringValue = "🟢 Tailscale conectado"
        case .disconnected:
            tailscaleLabel.stringValue = "🔴 Tailscale desconectado"
        case .notInstalled:
            tailscaleLabel.stringValue = "🟠 Tailscale no encontrado"
        case .unknown:
            tailscaleLabel.stringValue = "⚪️ Verificando Tailscale…"
        }
    }

    func controlTextDidChange(_ obligation: Notification) {
        fieldsChanged()
    }

    @objc private func fieldsChanged() {
        guard var profile else { return }
        profile.name = nameField.stringValue
        profile.host = hostField.stringValue
        profile.port = portField.stringValue.isEmpty ? "3389" : portField.stringValue
        profile.username = userField.stringValue
        profile.password = passwordField.stringValue
        profile.dynamicResolution = dynResCheckbox.state == .on
        profile.ignoreCert = certCheckbox.state == .on
        profile.extraFlags = extraFlagsField.stringValue
        self.profile = profile
        view.window?.title = profile.name.isEmpty ? "RDPConnect" : profile.name
        onChange?(profile)
    }

    @objc private func connectTapped() {
        guard let profile else { return }
        onConnect?(profile)
    }
}
