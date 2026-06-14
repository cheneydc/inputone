import Cocoa
import InputOneLib

final class AppPickerViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    private let searchField = NSSearchField()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)
    private let addButton = NSButton(title: "Add Selected", target: nil, action: nil)

    private static var cachedApps: [(bundleID: String, name: String, icon: NSImage?)]?
    private var allApps: [(bundleID: String, name: String, icon: NSImage?)] = []
    private var filteredApps: [(bundleID: String, name: String, icon: NSImage?)] = []
    private var onSelect: ((String) -> Void)?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 360))
        view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        loadApps()
    }

    private func setupViews() {
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Search applications..."
        searchField.delegate = self
        view.addSubview(searchField)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        view.addSubview(scrollView)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.headerView = nil
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.selectionHighlightStyle = .regular
        tableView.rowHeight = 36
        tableView.target = self
        tableView.doubleAction = #selector(addSelected)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        scrollView.documentView = tableView

        cancelButton.bezelStyle = .push
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.target = self
        cancelButton.action = #selector(cancel)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancelButton)

        addButton.bezelStyle = .push
        addButton.keyEquivalent = "\r"
        addButton.target = self
        addButton.action = #selector(addSelected)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(addButton)

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: cancelButton.topAnchor, constant: -12),

            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            cancelButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),

            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            addButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
        ])
    }

    private func loadApps() {
        if let cached = Self.cachedApps {
            allApps = cached
            filterApps()
            return
        }

        var seen = Set<String>()
        var apps: [(bundleID: String, name: String, icon: NSImage?)] = []

        let dirs = [
            "/Applications",
            "/Applications/Utilities",
            NSHomeDirectory() + "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            "/System/Library/CoreServices",
        ]

        for dir in dirs {
            scanForApps(in: dir, seen: &seen, apps: &apps)
        }

        allApps = apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        Self.cachedApps = allApps
        filterApps()
    }

    private func scanForApps(in directory: String, seen: inout Set<String>, apps: inout [(bundleID: String, name: String, icon: NSImage?)]) {
        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: directory),
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return }

        for case let url as URL in enumerator {
            guard url.pathExtension == "app" else { continue }
            guard let bundle = Bundle(url: url),
                  let bundleID = bundle.bundleIdentifier,
                  !seen.contains(bundleID)
            else { continue }
            seen.insert(bundleID)
            let name = (bundle.localizedInfoDictionary?["CFBundleName"] as? String)
                ?? (bundle.infoDictionary?["CFBundleName"] as? String)
                ?? url.deletingPathExtension().lastPathComponent
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            apps.append((bundleID, name, icon))
        }
    }

    private func filterApps() {
        let query = searchField.stringValue.lowercased()
        if query.isEmpty {
            filteredApps = allApps
        } else {
            filteredApps = allApps.filter { $0.name.lowercased().contains(query) || $0.bundleID.lowercased().contains(query) }
        }
        tableView.reloadData()
    }

    func showAsSheet(on window: NSWindow, onSelect: @escaping (String) -> Void) {
        self.onSelect = onSelect
        window.beginSheet(NSWindow(contentViewController: self), completionHandler: nil)
    }

    // MARK: - NSTableView

    func numberOfRows(in tableView: NSTableView) -> Int { filteredApps.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < filteredApps.count else { return nil }
        let app = filteredApps[row]
        let id = NSUserInterfaceItemIdentifier("AppCell")
        var cell = tableView.makeView(withIdentifier: id, owner: self) as? AppCellView
        if cell == nil {
            cell = AppCellView()
            cell?.identifier = id
        }
        cell?.configure(icon: app.icon, name: app.name)
        return cell
    }

    // MARK: - Actions

    @objc private func addSelected() {
        let row = tableView.selectedRow
        guard row >= 0, row < filteredApps.count else { return }
        let bundleID = filteredApps[row].bundleID
        view.window?.sheetParent?.endSheet(view.window!)
        onSelect?(bundleID)
    }

    @objc private func cancel() {
        view.window?.sheetParent?.endSheet(view.window!)
    }

    // MARK: - NSSearchFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        filterApps()
    }
}

final class AppCellView: NSTableCellView {
    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        iconView.frame = NSRect(x: 4, y: 8, width: 20, height: 20)
        addSubview(iconView)

        nameLabel.font = NSFont.systemFont(ofSize: 13)
        nameLabel.textColor = .labelColor
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.frame = NSRect(x: 30, y: 8, width: 320, height: 20)
        addSubview(nameLabel)
    }

    required init?(coder: NSCoder) { nil }

    func configure(icon: NSImage?, name: String) {
        iconView.image = icon
        nameLabel.stringValue = name
    }
}
