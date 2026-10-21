#if os(macOS)
import XCTest
import AppKit
import SwiftUI
@testable import HeedKit

@MainActor
final class AppKitPresentationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        _ = NSApplication.shared
        HeedKit.shared.dismiss()
    }

    private func makeParentWindow() -> NSWindow {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
                         styleMask: [.titled], backing: .buffered, defer: false)
        w.isReleasedWhenClosed = false
        return w
    }

    func testPresentAttachesSheetToGivenWindow() {
        let parent = makeParentWindow()
        HeedKit.shared.present(in: parent)

        XCTAssertEqual(parent.sheets.count, 1)
        XCTAssertTrue(parent.sheets.first === HeedKit.presented)
        XCTAssertTrue(HeedKit.presented?.contentViewController is NSHostingController<HeedKitView>)

        HeedKit.shared.dismiss()
        XCTAssertTrue(parent.sheets.isEmpty)
        XCTAssertNil(HeedKit.presented)
    }

    func testPresentWithoutWindowOpensStandaloneWindow() {
        HeedKit.shared.present(in: nil)

        let widget = try! XCTUnwrap(HeedKit.presented)
        XCTAssertNil(widget.sheetParent)
        XCTAssertTrue(widget.isVisible)
        XCTAssertEqual(widget.title, "Feedback")

        widget.close()  // traffic-light close, not dismiss()
        XCTAssertNil(HeedKit.presented)
    }

    func testPresentWhileOpenIsNoOp() {
        let parent = makeParentWindow()
        HeedKit.shared.present(in: parent)
        let first = HeedKit.presented
        HeedKit.shared.present(in: parent)
        XCTAssertTrue(HeedKit.presented === first)
        XCTAssertEqual(parent.sheets.count, 1)
        HeedKit.shared.dismiss()
    }

    func testMenuItemPresentsWidget() {
        let item = HeedKit.shared.menuItem()
        XCTAssertEqual(item.title, "Send Feedback…")
        XCTAssertNotNil(item.target)
        XCTAssertNotNil(item.action)

        _ = item.target?.perform(item.action, with: item)
        XCTAssertNotNil(HeedKit.presented)
        HeedKit.shared.dismiss()
    }
}
#endif
