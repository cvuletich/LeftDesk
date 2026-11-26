import AppKit
import Foundation
import ServiceManagement
import Darwin

final class LeftDesk: NSObject, NSApplicationDelegate {
    var status: NSStatusItem!
    var checkingUpdates = false
    var autoUpdates: Bool { defaults.bool(forKey: "autoUpdates") }
    var timer: Timer?
    var immediateScanQueued = false
    var retryGeneration = 0
    var aboutWindow: NSWindow?
    let retryDelays: [Double] = [0.10, 0.25, 0.50, 1.0, 2.0]
    var desktopSource: DispatchSourceFileSystemObject?
    var observers = [NSObjectProtocol]()
    var direction: String { defaults.string(forKey: "direction") ?? "Left" }
    var preserveOrder: Bool { defaults.object(forKey: "preserveOrder") as? Bool ?? true }
    var fillGaps: Bool { defaults.object(forKey: "fillGaps") as? Bool ?? true }
    var lastLayoutError = ""
    var eventMode = "Starting"
    var seen = Set<String>()
    var initialized = false
    var busy = false
    let defaults = UserDefaults.standard
    var enabled: Bool { defaults.object(forKey: "enabled") as? Bool ?? true }
    var spacing: Int { defaults.object(forKey: "spacing") as? Int ?? 120 }
    var margin: Int { defaults.object(forKey: "margin") as? Int ?? 75 }
    var message = "Starting…"
    var lastMove = "No moves yet"
    func applicationDidFinishLaunching(_ notification: Notification) {
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "align.horizontal.left", accessibilityDescription: "LeftDesk")
        rebuild()
        startEvents()
        scan()
        if autoUpdates { checkUpdates(manual: false) }
    }
    func rebuild() {
        let menu = NSMenu()
        add(menu, "Automatic alignment", #selector(toggle), checked: enabled)
        add(menu, "Align All Icons Now…", #selector(alignAll))
        add(menu, "Launch at Login", #selector(login), checked: SMAppService.mainApp.status == .enabled)
        add(menu, "Settings…", #selector(settings))
        menu.addItem(.separator())
        add(menu, "Check for Updates…", #selector(checkForUpdates))
        add(menu, "About", #selector(showAbout))
        add(menu, "Quit LeftDesk", #selector(quit))
        status.menu = menu
    }
    func add(_ menu: NSMenu, _ title: String, _ action: Selector, checked: Bool = false) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); item.target = self; item.state = checked ? .on : .off; menu.addItem(item)
    }
    // Finder may not expose a new file immediately. Try at once, then reconcile
    // at short intervals. A newer event supersedes the previous retry burst.
    func scheduleScan() {
        retryGeneration += 1
        let generation = retryGeneration
        if !immediateScanQueued {
            immediateScanQueued = true
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.immediateScanQueued = false
                self.scan()
            }
        }
        for delay in retryDelays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self, self.retryGeneration == generation else { return }
                self.scan()
            }
        }
    }
    func startEvents() {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let fd = open(desktop.path, O_EVTONLY)
        if fd >= 0 {
            let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete, .revoke], queue: .main)
            source.setEventHandler { [weak self] in self?.scheduleScan() }
            source.setCancelHandler { close(fd) }
            desktopSource = source
            source.resume()
            eventMode = "Filesystem + volume notifications; 15-second reconciliation"
        } else { eventMode = "Polling fallback (2 seconds); desktop event access unavailable" }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification, NSWorkspace.didWakeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.scheduleScan() })
        }
        timer = Timer.scheduledTimer(withTimeInterval: fd >= 0 ? 15 : 2, repeats: true) { [weak self] _ in self?.scan() }
    }
    @objc func showAbout() {
        if let window = aboutWindow {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 370, height: 320),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "About LeftDesk"
        window.isReleasedWhenClosed = false
        let content = NSView()
        window.contentView = content
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.widthAnchor.constraint(equalToConstant: 88).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 88).isActive = true
        let name = NSTextField(labelWithString: "LeftDesk")
        name.font = .systemFont(ofSize: 24, weight: .semibold)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let versionLabel = NSTextField(labelWithString: "Version \(version)")
        versionLabel.textColor = .secondaryLabelColor
        let tagline = NSTextField(labelWithString: "Your desktop, just a little more organized.")
        let credit = NSTextField(labelWithString: "Developed by Chris Vuletich")
        let link = NSButton(title: "leftdesk.cvuletich.com", target: self, action: #selector(openWebsite))
        link.isBordered = false
        link.attributedTitle = NSAttributedString(string: "leftdesk.cvuletich.com", attributes: [
            .foregroundColor: NSColor.linkColor, .underlineStyle: NSUnderlineStyle.single.rawValue,
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize)
        ])
        let copyright = NSTextField(labelWithString: "Copyright © 2026 Chris Vuletich")
        copyright.font = .systemFont(ofSize: 11)
        copyright.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [icon, name, versionLabel, tagline, credit, link, copyright])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 7
        stack.setCustomSpacing(15, after: tagline)
        stack.setCustomSpacing(13, after: link)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: content.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -16)
        ])
        aboutWindow = window
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
    @objc func openWebsite() {
        if let url = URL(string: "https://leftdesk.cvuletich.com") { NSWorkspace.shared.open(url) }
    }
    @objc func checkForUpdates() { checkUpdates(manual: true) }
    func checkUpdates(manual: Bool) {
        guard !checkingUpdates else { if manual { alert("An update check is already in progress.") }; return }
        checkingUpdates = true
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.urlCache = nil
        let session = URLSession(configuration: config)
        let url = URL(string: "https://leftdesk.cvuletich.com/updates.json")!
        session.dataTask(with: url) { [weak self] data, response, error in
            defer { session.finishTasksAndInvalidate() }
            let result: Result<UpdateFeed, Error> = Result {
                guard error == nil, let http = response as? HTTPURLResponse,
                      http.statusCode == 200, http.url == url, let data = data, data.count <= 65536 else {
                    throw error ?? URLError(.badServerResponse)
                }
                let feed = try JSONDecoder().decode(UpdateFeed.self, from: data)
                guard LeftDeskVersion.validVersion(feed.version) else { throw URLError(.cannotParseResponse) }
                return feed
            }
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.checkingUpdates = false
                switch result {
                case .failure:
                    if manual { NSApp.activate(ignoringOtherApps: true); self.alert("Unable to check for updates. Please try again later.") }
                case .success(let feed):
                    let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1"
                    if LeftDeskVersion.isNewer(feed.version, than: current) {
                        NSApp.activate(ignoringOtherApps: true)
                        let a = NSAlert(); a.messageText = "LeftDesk \(feed.version) is available"
                        a.informativeText = String(feed.release_notes.prefix(1000)) + "\n\nYou have version \(current). Visit the official website to download the update."
                        a.addButton(withTitle: "Visit Website"); a.addButton(withTitle: "Later")
                        if a.runModal() == .alertFirstButtonReturn { self.openWebsite() }
                    } else if manual { NSApp.activate(ignoringOtherApps: true); self.alert("You have the latest version of LeftDesk (\(current)).") }
                }
            }
        }.resume()
    }
    @objc func toggle() { defaults.set(!enabled, forKey: "enabled"); rebuild(); scan() }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func login() {
        do { if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() } else { try SMAppService.mainApp.register() } } catch { alert(error.localizedDescription) }; rebuild()
    }
    func alert(_ text: String) { let a = NSAlert(); a.messageText = "LeftDesk"; a.informativeText = text; a.runModal() }
    @objc func settings() {
        let a = NSAlert(); a.messageText = "LeftDesk Settings"
        a.informativeText = "Choose how new icons and manual alignment behave."
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10
        let picker = NSPopUpButton(); picker.addItems(withTitles: ["Left", "Right", "Top", "Bottom"]); picker.selectItem(withTitle: direction)
        let space = NSTextField(string: String(spacing)); space.widthAnchor.constraint(equalToConstant: 90).isActive = true
        let edge = NSTextField(string: String(margin)); edge.widthAnchor.constraint(equalToConstant: 90).isActive = true
        let gaps = NSButton(checkboxWithTitle: "Fill empty grid positions", target: nil, action: nil); gaps.state = fillGaps ? .on : .off
        let preserve = NSButton(checkboxWithTitle: "Preserve existing icon order", target: nil, action: nil); preserve.state = preserveOrder ? .on : .off
        func line(_ label: String, _ control: NSView) -> NSStackView {
            let row = NSStackView(views: [NSTextField(labelWithString: label), control]); row.orientation = .horizontal; row.spacing = 12; return row
        }
        stack.addArrangedSubview(line("Alignment:", picker)); stack.addArrangedSubview(line("Spacing (points):", space)); stack.addArrangedSubview(line("Edge margin (points):", edge)); stack.addArrangedSubview(gaps); stack.addArrangedSubview(preserve)
        let updates = NSButton(checkboxWithTitle: "Check for updates at launch", target: nil, action: nil); updates.state = autoUpdates ? .on : .off
        stack.addArrangedSubview(updates)
        stack.frame = NSRect(x: 0, y: 0, width: 320, height: 195); a.accessoryView = stack
        a.addButton(withTitle: "Save"); a.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if a.runModal() == .alertFirstButtonReturn {
            guard let v = Int(space.stringValue), let m = Int(edge.stringValue), (70...300).contains(v), (40...300).contains(m) else { alert("Spacing must be 70–300 and margin 40–300."); return }
            defaults.set(v, forKey: "spacing"); defaults.set(m, forKey: "margin"); defaults.set(picker.titleOfSelectedItem ?? "Left", forKey: "direction"); defaults.set(gaps.state == .on, forKey: "fillGaps"); defaults.set(preserve.state == .on, forKey: "preserveOrder"); defaults.set(updates.state == .on, forKey: "autoUpdates")
        }
    }
    @objc func alignAll() { let a = NSAlert(); a.messageText = "Reposition all desktop icons?"; a.informativeText = preserveOrder ? "Icons will snap to the selected edge while keeping their relative order and filling grid positions from the beginning without gaps." : "Icons will be arranged in name order. This changes icon positions, not files."; a.addButton(withTitle: "Align All"); a.addButton(withTitle: "Cancel"); if a.runModal() == .alertFirstButtonReturn { scan(all: true) } }
    func apple(_ source: String) throws -> NSAppleEventDescriptor {
        var error: NSDictionary?; guard let script = NSAppleScript(source: source) else { throw NSError(domain: "LeftDesk", code: 1) }; let result = script.executeAndReturnError(&error); if let error = error { throw NSError(domain: "LeftDesk", code: 2, userInfo: [NSLocalizedDescriptionKey: error.description]) }; return result
    }
    struct Item { let name: String; let key: String; let x: Int; let y: Int; let index: Int }
    func scan(all: Bool = false) {
        guard !busy, let screen = NSScreen.screens.first else { return }; busy = true; defer { busy = false }
        do {
            let result = try apple("""
            tell application "Finder"
                set desktopItems to every item of desktop
                set recordsList to {}
                repeat with itemRef in desktopItems
                    set desktopItem to contents of itemRef
                    set itemName to name of desktopItem as text
                    set itemPosition to desktop position of desktopItem
                    set itemKey to itemName
                    try
                        set itemURL to URL of desktopItem
                        if itemURL is not missing value then set itemKey to itemURL as text
                    end try
                    set end of recordsList to {itemName, itemKey, item 1 of itemPosition, item 2 of itemPosition}
                end repeat
                return recordsList
            end tell
            """)
            var items = [Item]()
            if result.numberOfItems > 0 {
                for i in 1...result.numberOfItems {
                    guard let r = result.atIndex(i), let n = r.atIndex(1)?.stringValue, let k = r.atIndex(2)?.stringValue, let x = r.atIndex(3), let y = r.atIndex(4) else {
                        throw NSError(domain: "LeftDesk", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot decode Finder item \(i): \(result)"])
                    }
                    items.append(Item(name: n, key: k, x: Int(x.int32Value), y: Int(y.int32Value), index: i))
                }
            }
            let current = Set(items.map(\.key))
            if !initialized && !all { seen = current; initialized = true; message = "Ready (\(items.count) icons)"; return }
            if !enabled && !all { seen = current; message = "Paused"; return }
            let targets = items.filter { all || !seen.contains($0.key) }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            var occupied = items.filter { !all && seen.contains($0.key) }.map { ($0.x,$0.y) }
            var completed = current.subtracting(Set(targets.map(\.key)))
            let f = screen.visibleFrame, full = screen.frame
            let left = Int(f.minX) + margin, top = Int(full.maxY - f.maxY) + (direction == "Top" ? margin : 65)
            let bottom = Int(full.maxY - f.minY) - (direction == "Bottom" ? margin : 65), right = Int(f.maxX) - (direction == "Right" ? margin : 65)
            let slots = Grid.slots(left: left, right: right, top: top, bottom: bottom, spacing: spacing, direction: direction)
            // Match existing icons to their nearest grid positions with tolerance for Finder rounding.
            // A small inset in the collision threshold avoids skipping adjacent rows by a pixel.
            let clearance = Grid.clearance(spacing: spacing)
            func blocked(_ slot: (Int, Int)) -> Bool {
                Grid.blocked(slot, by: occupied, clearance: clearance)
            }
            var planned: [(Int, Int)]? = nil
            if all {
                guard targets.count <= slots.count else { alert("Not enough grid space. Reduce icon spacing or margins and try again."); return }
                if preserveOrder {
                    guard let positions = Grid.preservedSlots(points: targets.map { ($0.x, $0.y) }, slots: slots, direction: direction) else { alert("Unable to plan alignment."); return }
                    planned = positions
                }
            }
            var nextIndex = 0
            if !fillGaps && !all, let last = slots.lastIndex(where: { slot in occupied.contains { abs($0.0-slot.0) <= spacing/3 && abs($0.1-slot.1) <= spacing/3 } }) { nextIndex = last + 1 }
            for (targetIndex, item) in targets.enumerated() {
                let slot = planned.map { $0[targetIndex] } ?? slots.dropFirst(nextIndex).first(where: { !blocked($0) })
                guard let (x,y) = slot else { message = "No available icon space"; if !all { seen = completed }; return }
                if all && item.x == x && item.y == y { occupied.append((x,y)); completed.insert(item.key); continue }
                let escaped = item.name.replacingOccurrences(of:"\\",with:"\\\\").replacingOccurrences(of:"\"",with:"\\\"").replacingOccurrences(of:"\n",with:"\\n").replacingOccurrences(of:"\r",with:"\\r")
                do { _ = try apple("tell application \"Finder\" to set desktop position of item \"\(escaped)\" of desktop to {\(x), \(y)}"); occupied.append((x,y)); completed.insert(item.key); lastMove = "\(item.name) → {\(x), \(y)}" } catch { message = "Cannot move: \(item.name)"; lastMove = error.localizedDescription; NSLog("LeftDesk: %@",error.localizedDescription); if !all { seen = completed }; return }
            }
            seen = completed; initialized = true; message = enabled ? "Ready (\(items.count) icons)" : "Paused"
        } catch { message = "Finder scan failed"; NSLog("LeftDesk: %@",error.localizedDescription) }
    }
}
let app = NSApplication.shared
let delegate = LeftDesk()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
