import Cocoa
import InputOneLib

final class WhitelistWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private let whitelistManager: WhitelistManager
    private let manager: InputMethodManaging
    private let locker: InputLocker
    private let settings: Settings

    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let addButton = NSButton(title: "+ Add App", target: nil, action: nil)
    private let removeButton = NSButton(title: "− Remove", target: nil, action: nil)
    private let headerLabel = NSTextField(labelWithString: "App                                        Input Method")

    private var rules: [(bundleID: String, sourceID: String)] = []
    private var inputSources: [InputSourceInfo] = []
    private var appInfoCache: [String: (name: String, icon: NSImage?)] = [:]

    init(whitelistManager: WhitelistManager, manager: InputMethodManaging, locker: InputLocker, settings: Settings) {
        self.whitelistManager = whitelistManager
        self.manager = manager
        self.locker = locker
        self.settings = settings
        super.init(window: nil)
        setupWindow()
    }

    required init?(coder: NSCoder) { nil }

    private func setupWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: true
        )
        window.title = "Whitelist Rules"
        window.minSize = NSSize(width: 360, height: 240)
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
        setupViews()
    }

    private func setupViews() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true

        inputSources = manager.listInputSourceInfo()
        reloadRules()

        headerLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        headerLabel.textColor = .secondaryLabelColor
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headerLabel)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        contentView.addSubview(scrollView)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.headerView = nil
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.selectionHighlightStyle = .regular
        tableView.backgroundColor = .clear
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.rowHeight = 36

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("rule"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)

        scrollView.documentView = tableView

        addButton.bezelStyle = .push
        addButton.target = self
        addButton.action = #selector(showAppPicker)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(addButton)

        removeButton.bezelStyle = .push
        removeButton.target = self
        removeButton.action = #selector(removeSelected)
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(removeButton)

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            headerLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            headerLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 6),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: addButton.topAnchor, constant: -12),

            addButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            addButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),

            removeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            removeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
        ])
    }

    private func reloadRules() {
        let dict = whitelistManager.allRules()
        rules = dict.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
        tableView.reloadData()
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int { rules.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < rules.count else { return nil }
        let rule = rules[row]
        let identifier = NSUserInterfaceItemIdentifier("RuleCell")
        var cell = tableView.makeView(withIdentifier: identifier, owner: self) as? RuleCellView
        if cell == nil {
            cell = RuleCellView()
            cell?.identifier = identifier
        }

        let bundleID = rule.bundleID
        let appName = displayName(for: bundleID)
        let icon = appIcon(for: bundleID)

        cell?.configure(
            appName: appName,
            appIcon: icon,
            bundleID: bundleID,
            selectedSourceID: rule.sourceID,
            inputSources: inputSources
        ) { [weak self] newSourceID in
            self?.whitelistManager.setRule(bundleID: bundleID, sourceID: newSourceID)
            self?.settings.mode = .whitelist
            if self?.settings.isLocking == true {
                self?.locker.enforceLock()
            }
        }

        return cell
    }

    // MARK: - Actions

    @objc private func showAppPicker() {
        let picker = AppPickerViewController()
        guard let window = self.window else { return }
        picker.showAsSheet(on: window) { [weak self] bundleID in
            guard let self else { return }
            let defaultSourceID = self.settings.lockedInputSourceID ?? self.inputSources.first?.id ?? ""
            self.whitelistManager.setRule(bundleID: bundleID, sourceID: defaultSourceID)
            self.settings.mode = .whitelist
            if self.settings.isLocking {
                self.locker.enforceLock()
            }
            self.reloadRules()
        }
    }

    @objc private func removeSelected() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < rules.count else { return }
        let bundleID = rules[selectedRow].bundleID
        whitelistManager.removeRule(bundleID: bundleID)
        reloadRules()
    }

    private func displayName(for bundleID: String) -> String {
        if let cached = appInfoCache[bundleID] { return cached.name }
        let name = resolveDisplayName(for: bundleID)
        let icon = resolveAppIcon(for: bundleID)
        appInfoCache[bundleID] = (name, icon)
        return name
    }

    private func appIcon(for bundleID: String) -> NSImage? {
        if let cached = appInfoCache[bundleID] { return cached.icon }
        let name = resolveDisplayName(for: bundleID)
        let icon = resolveAppIcon(for: bundleID)
        appInfoCache[bundleID] = (name, icon)
        return icon
    }

    private func resolveDisplayName(for bundleID: String) -> String {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            return app.localizedName ?? bundleID
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           let bundle = Bundle(url: url) {
            let name = bundle.localizedInfoDictionary?[kCFBundleNameKey as String] as? String
            return name ?? bundleID
        }
        return bundleID
    }

    private func resolveAppIcon(for bundleID: String) -> NSImage? {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            return app.icon
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return nil
    }
}

// MARK: - RuleCellView

final class RuleCellView: NSTableCellView {
    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let popUpButton = NSPopUpButton()
    private var onChange: ((String) -> Void)?
    private var bundleID: String = ""

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { nil }

    private func setup() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        addSubview(iconView)

        nameLabel.font = NSFont.systemFont(ofSize: 13)
        nameLabel.textColor = .labelColor
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nameLabel)

        popUpButton.bezelStyle = .regularSquare
        popUpButton.target = self
        popUpButton.action = #selector(popUpChanged)
        popUpButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(popUpButton)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: popUpButton.leadingAnchor, constant: -8),

            popUpButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            popUpButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            popUpButton.widthAnchor.constraint(equalToConstant: 150),
        ])
    }

    func configure(
        appName: String,
        appIcon: NSImage?,
        bundleID: String,
        selectedSourceID: String,
        inputSources: [InputSourceInfo],
        onChange: @escaping (String) -> Void
    ) {
        self.bundleID = bundleID
        self.onChange = onChange

        iconView.image = appIcon
        nameLabel.stringValue = appName

        popUpButton.removeAllItems()
        var selectedIndex = 0
        for (i, source) in inputSources.enumerated() {
            popUpButton.addItem(withTitle: source.name)
            popUpButton.lastItem?.representedObject = source.id
            if source.id == selectedSourceID {
                selectedIndex = i
            }
        }
        popUpButton.selectItem(at: selectedIndex)
    }

    @objc private func popUpChanged() {
        guard let sourceID = popUpButton.selectedItem?.representedObject as? String else { return }
        onChange?(sourceID)
    }
}
