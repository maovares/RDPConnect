import AppKit

final class SidebarViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private let store: ProfileStore
    private let tableView = NSTableView()
    private let optionsMenu = NSMenu()
    var onSelect: ((Profile?) -> Void)?

    init(store: ProfileStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let container = NSView()

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true

        let column = NSTableColumn(identifier: .init("name"))
        column.title = "Conexiones"
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowSizeStyle = .medium

        optionsMenu.addItem(withTitle: "Duplicar", action: #selector(duplicateProfile), keyEquivalent: "")
        optionsMenu.addItem(withTitle: "Eliminar", action: #selector(confirmRemoveProfile), keyEquivalent: "")
        for item in optionsMenu.items { item.target = self }
        tableView.menu = optionsMenu // click derecho, para quien lo prefiera
        scrollView.documentView = tableView

        let addButton = NSButton(image: NSImage(systemSymbolName: "plus", accessibilityDescription: "Agregar")!, target: self, action: #selector(addProfile))
        addButton.bezelStyle = .smallSquare
        addButton.isBordered = false

        let removeButton = NSButton(image: NSImage(systemSymbolName: "minus", accessibilityDescription: "Eliminar")!, target: self, action: #selector(confirmRemoveProfile))
        removeButton.bezelStyle = .smallSquare
        removeButton.isBordered = false

        // Botón de "más opciones" con click izquierdo normal, para que duplicar no
        // dependa de que el usuario sepa hacer click derecho (poco descubrible).
        let optionsButton = NSButton(image: NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "Más opciones")!, target: self, action: #selector(showOptionsMenu(_:)))
        optionsButton.bezelStyle = .smallSquare
        optionsButton.isBordered = false

        let buttonBar = NSStackView(views: [addButton, removeButton, NSView(), optionsButton])
        buttonBar.translatesAutoresizingMaskIntoConstraints = false
        buttonBar.orientation = .horizontal
        buttonBar.spacing = 4
        buttonBar.edgeInsets = NSEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)

        container.addSubview(scrollView)
        container.addSubview(buttonBar)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: buttonBar.topAnchor),

            buttonBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            buttonBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            buttonBar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            buttonBar.heightAnchor.constraint(equalToConstant: 24),
        ])

        view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        reload(selecting: store.profiles.first?.id)
    }

    func reload(selecting id: UUID?) {
        tableView.reloadData()
        if let id, let index = store.profiles.firstIndex(where: { $0.id == id }) {
            tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        }
    }

    @objc private func addProfile() {
        let profile = store.addProfile()
        reload(selecting: profile.id)
        onSelect?(profile)
    }

    @objc private func showOptionsMenu(_ sender: NSButton) {
        guard tableView.selectedRow >= 0 else { return }
        optionsMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }

    @objc private func duplicateProfile() {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard row >= 0, row < store.profiles.count else { return }
        let copy = store.duplicate(store.profiles[row])
        reload(selecting: copy.id)
        onSelect?(copy)
    }

    @objc private func confirmRemoveProfile() {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard row >= 0, row < store.profiles.count else { return }
        let profile = store.profiles[row]

        let alert = NSAlert()
        alert.messageText = "¿Eliminar \"\(profile.name)\"?"
        alert.informativeText = "Esta acción no se puede deshacer."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Eliminar")
        alert.addButton(withTitle: "Cancelar")
        alert.buttons.first?.hasDestructiveAction = true
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        store.delete(profile)
        let newSelection = store.profiles[safe: min(row, store.profiles.count - 1)]
        reload(selecting: newSelection?.id)
        onSelect?(newSelection)
    }

    func numberOfRows(in tableView: NSTableView) -> Int { store.profiles.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellId = NSUserInterfaceItemIdentifier("nameCell")
        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: cellId, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = cellId

            let label = NSTextField(labelWithString: "")
            label.translatesAutoresizingMaskIntoConstraints = false
            label.lineBreakMode = .byTruncatingTail
            cell.addSubview(label)
            cell.textField = label

            // El label no traía constraints propias, así que AppKit lo dejaba pegado
            // arriba del row en vez de centrarlo verticalmente.
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                label.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -4),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }
        cell.textField?.stringValue = store.profiles[row].name
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        onSelect?(store.profiles[safe: row])
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
