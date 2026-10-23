import XCTest
import StoreKitTest

/// Run only on a dedicated simulator. StoreKit purchases are local Xcode transactions.
@MainActor final class RecoveryUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testRecoveryHasVisibleActionAndKeepsSetupAvailable() {
        let app = XCUIApplication()
        app.launchArguments = ["-monetization-scenario", "verification-pending"]
        app.launch()
        XCTAssertTrue(app.buttons["access-summary"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Keep searching while we check access"].exists)
        XCTAssertTrue(app.buttons["setup-test-start"].exists)
        capture("Verification recovery home", app: app)
        app.buttons["access-summary"].tap()
        XCTAssertTrue(app.buttons["check-access"].waitForExistence(timeout: 5))
        capture("Verification recovery action", app: app)
        app.terminate()
    }

    func testTrialActivationLeadsToSafariSetupGuide() async throws {
        let session = try SKTestSession(configurationFileNamed: "Monetization")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        // Create a real acquisition receipt without granting trial/lifetime access.
        _ = try await session.buyProduct(identifier: "braversearch.tip.thanks", options: [])
        let app = XCUIApplication()
        app.launchArguments = ["-monetization-test-cohort", "new", "-monetization-test-cutoff", "2026-10-04T04:00:00Z", "-show-lifetime"]
        app.launch()
        let start = app.buttons["start-free-trial"]
        XCTAssertTrue(start.waitForExistence(timeout: 25), app.debugDescription)
        start.tap()
        let finish = app.buttons["finish-safari-setup"]
        XCTAssertTrue(finish.waitForExistence(timeout: 20), app.debugDescription)
        capture("Trial activated next step", app: app)
        finish.tap()
        XCTAssertTrue(app.navigationBars["Installation Guide"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Access ready — continue below"].exists)
        capture("Safari setup guide after activation", app: app)
        app.terminate()
        session.clearTransactions()
    }
}
