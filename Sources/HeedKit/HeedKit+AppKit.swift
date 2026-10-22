#if os(macOS) && canImport(AppKit) && canImport(SwiftUI)
import AppKit
import SwiftUI

// MARK: - AppKit presentation
//
// Entry points for Mac apps that don't drive presentation from SwiftUI (AppKit
// windows, menu-bar apps, status items). A pure SwiftUI app should keep using
// `.sheet { HeedKitView() }` — see the README.

extension HeedKit {
    /// The widget window while it's on screen. Internal for tests.
    @MainActor static var presented: NSWindow?

    /// Opens the feedback widget. Attached as a sheet to `window` — defaulting to
    /// the key or main window — or opened as a standalone window when the app has
    /// none (menu-bar apps). Calling it while the widget is already open is a no-op.
    @MainActor
    public func present(in window: NSWindow? = nil) {
        guard Self.presented == nil else { return }
        let parent = window ?? NSApp.keyWindow ?? NSApp.mainWindow
        // Given an onClose, the view draws its own header (app icon, name, Close), so
        // the window needs no toolbar or visible title.
        let host = NSHostingController(rootView: HeedKitView(onClose: { self.dismiss() }))
        let widget = WidgetWindow(contentViewController: host)
        widget.isReleasedWhenClosed = false
        // Match the SwiftUI `.sheet` size; the window would otherwise open at the
        // view's minimum and clip the kind tabs.
        widget.setContentSize(NSSize(width: 520, height: 640))
        widget.title = displayName  // Window menu / accessibility only
        widget.titleVisibility = .hidden
        Self.presented = widget
        if let parent {
            parent.beginSheet(widget) { _ in if Self.presented === widget { Self.presented = nil } }
        } else {
            widget.center()
            widget.makeKeyAndOrderFront(nil)
        }
    }

    /// Closes the widget if `present(in:)` opened it.
    @MainActor
    public func dismiss() {
        guard let widget = Self.presented else { return }
        Self.presented = nil
        if let parent = widget.sheetParent { parent.endSheet(widget) } else { widget.close() }
    }

    /// A menu item that opens the widget — drop it into your Help menu or a
    /// status-bar menu. The item keeps its own target, so no retain is needed.
    @MainActor
    public func menuItem(title: String = "Send Feedback…", keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(MenuTarget.present(_:)), keyEquivalent: keyEquivalent)
        item.target = MenuTarget.shared
        return item
    }
}

/// Clears `HeedKit.presented` when the standalone window is closed from its
/// traffic-light button (sheets go through `endSheet`'s completion instead).
private final class WidgetWindow: NSWindow {
    override func close() {
        super.close()
        if HeedKit.presented === self { HeedKit.presented = nil }
    }
}

/// `NSMenuItem.target` is weak, so the menu item's action needs a long-lived object.
@MainActor
private final class MenuTarget: NSObject {
    static let shared = MenuTarget()
    @objc func present(_ sender: Any?) { HeedKit.shared.present() }
}
#endif
