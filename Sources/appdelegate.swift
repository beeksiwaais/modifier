import Cocoa


class AppDelegate: NSObject, NSApplicationDelegate, NSTableViewDelegate, NSTableViewDataSource {
    let completion: (String) -> Void
    var previousClipboardContent: String?
    var window: NSWindow?
    
    init(completion: @escaping (String) -> Void) {
        self.completion = completion
        super.init()
        // Observe clipboard updates
        NotificationCenter.default.addObserver(self, selector: #selector(handleClipboardUpdate), name: .clipboardUpdated, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        setupWindow()
        setupContentView()

        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = window, let customView = window.contentView as? CustomView {
            window.makeFirstResponder(customView)
        }
    }
    
    private func setupWindow() {
        let window = createWindow()
        self.window = window
    }
    
    private func setupContentView() {
        guard let window = window else { return }
        
        let customView = createCustomView(frame: window.contentView!.bounds)
        
        addTextField(to: customView)
        addButton(to: customView)
        addClipboardLabel(to: customView)
        addModifiedLabel(to: customView)
        addTableView(to: customView)

        window.contentView = customView
        window.makeFirstResponder(customView)
    }
    
    private func createWindow() -> NSWindow {
        guard let screen = NSScreen.main else {
            fatalError("No main screen found")
        }

        let screenFrame = screen.frame
        let windowWidth = screenFrame.width * 0.3
        let windowHeight = screenFrame.height * 0.7

        let window = NSWindow(contentRect: NSMakeRect(0, 0, windowWidth, windowHeight), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.center()
        window.title = "Clipboard Modifier"
        
        let visualEffect = NSVisualEffectView()
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .dark
        window.contentView = visualEffect

        window.styleMask.insert(.titled)
        window.makeKeyAndOrderFront(nil)

        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden

        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = true

        window.isMovableByWindowBackground = true
        window.makeKeyAndOrderFront(nil)
        window.level = .normal // Ensure the window level is set to normal

        return window
    }

    private func createCustomView(frame: NSRect) -> CustomView {
        let customView = CustomView(frame: frame)
        customView.autoresizingMask = [.width, .height]
        return customView
    }

    private func addClipboardLabel(to customView: CustomView) {
        let padding: CGFloat = 20.0
        let labelWidth = (customView.bounds.width / 2) - (1.5 * padding)
        let labelHeight = customView.bounds.height * 0.6 + 300 // 60% height minus the space for text field and button
        
        let clipboardLabel = NSTextField(frame: NSMakeRect(padding, padding + 60 + padding, labelWidth, labelHeight))
        clipboardLabel.stringValue = ClipboardManager.shared.clipboardHistory.last?.content ?? ""
        clipboardLabel.isEditable = false
        clipboardLabel.isBordered = false
        clipboardLabel.backgroundColor = .clear
        clipboardLabel.autoresizingMask = [.width, .height]
        clipboardLabel.cell?.wraps = true
        clipboardLabel.cell?.isScrollable = false
        customView.addSubview(clipboardLabel)
        customView.clipboardLabel = clipboardLabel
    }

    private func addModifiedLabel(to customView: CustomView) {
        let padding: CGFloat = 20.0
        let labelWidth = (customView.bounds.width / 2) - (1.5 * padding)
        let labelHeight = customView.bounds.height * 0.6 + 300 // 60% height minus the space for text field and button
        
        let modifiedLabel = NSTextField(frame: NSMakeRect(customView.bounds.width / 2 + (padding / 2), padding + 60 + padding, labelWidth, labelHeight))
        modifiedLabel.stringValue = "Modified content will appear here"
        modifiedLabel.isEditable = false
        modifiedLabel.isBordered = false
        modifiedLabel.backgroundColor = .clear
        modifiedLabel.autoresizingMask = [.width, .height]
        modifiedLabel.cell?.wraps = true
        modifiedLabel.cell?.isScrollable = false
        customView.addSubview(modifiedLabel)
        customView.modifiedLabel = modifiedLabel
    }

    private func addTextField(to customView: CustomView) {
        let textField = NSTextField(frame: NSMakeRect(20, customView.bounds.height - 70, customView.bounds.width - 140, 30))
        textField.autoresizingMask = [.width, .minYMargin]
        customView.addSubview(textField)
        customView.textField = textField
    }

    private func addButton(to customView: CustomView) {
        let button = NSButton(frame: NSMakeRect(customView.bounds.width - 100, customView.bounds.height - 70, 80, 30))
        button.title = "Apply"
        button.target = self
        button.action = #selector(applyModifier(_:))
        button.autoresizingMask = [.minXMargin, .minYMargin]
        customView.addSubview(button)
    }

    private func addTableView(to customView: CustomView) {
        let padding: CGFloat = 20.0
        let tableViewHeight = customView.bounds.height * 0.4 - padding // 40% height
        let scrollViewFrame = NSMakeRect(padding, padding, customView.bounds.width - 2 * padding, tableViewHeight)
        let scrollView = NSScrollView(frame: scrollViewFrame)
        scrollView.autoresizingMask = [.width, .height]
        
        let tableView = NSTableView(frame: scrollView.bounds)
        
        let column1 = createTableColumn(identifier: "ClipboardContent", title: "Clipboard Content", width: scrollView.bounds.width * 0.7)
        let column2 = createTableColumn(identifier: "Timestamp", title: "Timestamp", width: scrollView.bounds.width * 0.3)
        
        tableView.addTableColumn(column1)
        tableView.addTableColumn(column2)
        
        tableView.delegate = self
        tableView.dataSource = self
        
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true

        customView.addSubview(scrollView)
        customView.tableView = tableView

        // Ensure data is reloaded after setting up
        tableView.reloadData()
    }

    private func createTableColumn(identifier: String, title: String, width: CGFloat) -> NSTableColumn {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
        column.title = title
        column.width = width
        return column
    }

    @objc func applyModifier(_ sender: Any?) {
        if let customView = window?.contentView as? CustomView,
           let text = customView.textField?.stringValue {
            let modifiedContent = applyJavaScriptModifier(script: utf8ToHexScript, input: text)
            customView.modifiedLabel?.stringValue = modifiedContent
            completion(text)
        }
    }
    
    @objc func handleClipboardUpdate() {
        if let customView = window?.contentView as? CustomView {
            customView.updateClipboardLabel()
            customView.tableView?.reloadData()
        }
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return ClipboardManager.shared.clipboardHistory.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = tableColumn else { return nil }
        
        let reversedRow = ClipboardManager.shared.clipboardHistory.count - row - 1
        let clipboardHistory = ClipboardManager.shared.clipboardHistory
        let cellIdentifier = tableColumn.identifier.rawValue
        let text: String
        
        if cellIdentifier == "ClipboardContent" {
            text = clipboardHistory[reversedRow].content
        } else {
            let interval = Date().timeIntervalSince(clipboardHistory[reversedRow].date)
            text = timeString(for: interval)
        }
        
        var cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: self) as? NSTableCellView
        
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = tableColumn.identifier
            
            let textField = NSTextField(frame: cell?.bounds ?? NSRect())
            textField.autoresizingMask = [.width, .height]
            textField.isBordered = false
            textField.isEditable = false
            textField.backgroundColor = .clear
            
            cell?.addSubview(textField)
            cell?.textField = textField
        }
        
        cell?.textField?.stringValue = text

        // Set color to systemBlue for the first element
        if row == 0 {
            cell?.textField?.textColor = NSColor.systemBlue
        } else {
            cell?.textField?.textColor = NSColor.labelColor
        }
        
        return cell
    }
    
    func timeString(for interval: TimeInterval) -> String {
        let seconds = Int(interval) % 60
        let minutes = (Int(interval) / 60) % 60
        let hours = (Int(interval) / 3600) % 24
        let days = Int(interval) / 86400

        if days > 7 {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMMM d"
            let date = Date().addingTimeInterval(-interval)
            return dateFormatter.string(from: date)
        } else if days > 1 {
            return "\(days)d \(hours)h ago"
        } else if days == 1 {
            return "yesterday"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m ago"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s ago"
        } else {
            return "\(seconds)s ago"
        }
    }
}
