//
//  Braver_Search_macOS_Tests.swift
//  Braver Search macOS Tests
//
//  Created by Brenden Bishop on 1/21/25.
//

import XCTest
import AppKit
@testable import Braver_Search

@MainActor final class AccessSheetPresentationTests: XCTestCase {
    func testAppKitSheetClosesAndCanReopen() async throws {
        let presenter = NSViewController()
        presenter.view = NSView(frame: NSRect(x: 0, y: 0, width: 980, height: 820))
        let window = NSWindow(contentViewController: presenter)
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil) }

        for _ in 0..<2 {
            let sheet = LifetimeAccessView.makeSheetController()
            presenter.presentAsSheet(sheet)
            try await waitUntil { sheet.presentingViewController === presenter }
            XCTAssertNotNil(window.attachedSheet)
            // This is the action shared by Close, Escape, Done and trial completion.
            try XCTUnwrap(sheet.rootView.closeSheet)()
            try await waitUntil { window.attachedSheet == nil && presenter.presentedViewControllers?.isEmpty != false }
        }
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<100 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("AppKit sheet did not finish presenting or dismissing within five seconds")
    }
}
