//
//  MurmurixUITests.swift
//  MurmurixUITests
//
//  Created by Alexey Masyukov on 17.12.2025.
//

import XCTest

final class MurmurixUITests: XCTestCase {
    private enum MenuLabels {
        static let settings = ["Settings...", "Настройки...", "Ajustes..."]
        static let history = ["History...", "История...", "Historial..."]
    }

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // Smoke test: app starts without crashing.
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }

    @MainActor
    func testOpenSettingsFromStatusMenu() throws {
        let app = XCUIApplication()
        app.launch()

        openStatusMenu(app)
        tapStatusMenuItem(app, titles: MenuLabels.settings)

        XCTAssertTrue(waitForAnyWindow(app, timeout: 5))
        app.typeKey("w", modifierFlags: .command)
    }

    @MainActor
    func testOpenHistoryFromStatusMenu() throws {
        let app = XCUIApplication()
        app.launch()

        openStatusMenu(app)
        tapStatusMenuItem(app, titles: MenuLabels.history)

        XCTAssertTrue(waitForAnyWindow(app, timeout: 5))
        app.typeKey("w", modifierFlags: .command)
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }

    @MainActor
    private func openStatusMenu(_ app: XCUIApplication) {
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()
    }

    @MainActor
    private func tapStatusMenuItem(_ app: XCUIApplication, titles: [String]) {
        let predicate = NSPredicate(format: "label IN %@", titles)
        let menuItem = app.menuItems.matching(predicate).firstMatch
        XCTAssertTrue(menuItem.waitForExistence(timeout: 5))
        menuItem.click()
    }

    @MainActor
    private func waitForAnyWindow(_ app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "count > 0")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: app.windows)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
