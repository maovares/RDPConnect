import AppKit

final class SidebarViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private let store: ProfileStore
    private let tableView = NSTableView()
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
        scrollView.documentView = tableView

        let addButton = NSButton(image: NSImage(systemSymbolName: "plus", accessibilityDescription: "Agregar")!, target: self, action: #selector(addProfile))
        addButton.bezelStyle = .smallSquare
        addButton.isBordered = false

        let removeButton = NSButton(image: NSImage(systemSymbolName: "minus", accessibilityDescription: "Eliminar")!, target: self, action: #selector(removeProfile))
        removeButton.bezelStyle = .smallSquare
        removeButton.isBordered = false

        let buttonBar = NSStackView(views: [addButton, removeButton, NSView()])
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

    @objc private func removeProfile() {
        let row = tableView.selectedRow
        guard row >= 0, row < store.profiles.count else { return }
        store.delete(store.profiles[row])
        let newSelection = store.profiles[safe: min(row, store.profiles.count - 1)]
        reload(selecting: newSelection?.id)
        onSelect?(newSelection)
    }

    func numberOfRows(in tableView: NSTableView) -> Int { store.profiles.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellId = NSUserInterfaceItemIdentifier("nameCell")
        let cell: NSTableCellField
        if let reused = tableView.makeView(withIdentifier: cellId, owner: self) as? NSTableCellField {
            cell = reused
        } else {
            cell = NSTableCellField(labelWithString: "")
            cell.identifier = cellId
        }
        cell.stringValue = store.profiles[row].name
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        onSelect?(store.profiles[safe: row])
    }
}

private final class NSTableCellField: NSTextField {}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
