import XCTest

final class StockTrackerUITests: XCTestCase {
    func testSearchFiltersStocksAndDetailShowsSelectedStock() {
        let app = launchApp()
        let appleRow = app.buttons["stockRow_AAPL"]
        XCTAssertTrue(appleRow.waitForExistence(timeout: 5))

        let searchField = app.searchFields.firstMatch
        searchField.tap()
        searchField.typeText("Microsoft")

        XCTAssertTrue(app.buttons["stockRow_MSFT"].waitForExistence(timeout: 3))
        XCTAssertFalse(appleRow.exists)

        app.buttons["stockRow_MSFT"].tap()
        XCTAssertTrue(app.staticTexts["stockDetailSymbol"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["stockDetailSymbol"].label, "MSFT")
        XCTAssertEqual(app.staticTexts["stockDetailName"].label, "Microsoft Corporation")
        XCTAssertTrue(app.staticTexts["stockDetailAbsoluteChangeLabel"].exists)
        XCTAssertTrue(app.staticTexts["stockDetailAbsoluteChange"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["stockDetailPercentageChange"].exists)
    }

    func testFeedControlsStartAndStopDeterministicFeed() {
        let app = launchApp()
        let feedButton = app.buttons["feedToggleButton"]
        XCTAssertTrue(feedButton.waitForExistence(timeout: 5))
        XCTAssertEqual(feedButton.label, "Start Feed")

        feedButton.tap()
        XCTAssertTrue(app.staticTexts["feedConnectionState"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["feedConnectionState"].label, "Connected")
        XCTAssertEqual(feedButton.label, "Stop Feed")

        feedButton.tap()
        XCTAssertEqual(app.staticTexts["feedConnectionState"].label, "Disconnected")
        XCTAssertEqual(feedButton.label, "Start Feed")
    }

    func testSortMenuChangesStockOrder() {
        let app = launchApp()
        let appleRow = app.buttons["stockRow_AAPL"]
        let microsoftRow = app.buttons["stockRow_MSFT"]
        XCTAssertTrue(appleRow.waitForExistence(timeout: 5))
        XCTAssertTrue(microsoftRow.exists)
        XCTAssertLessThan(microsoftRow.frame.minY, appleRow.frame.minY)

        app.buttons["sortMenuButton"].tap()
        app.buttons["Price: Lowest first"].tap()

        XCTAssertLessThan(appleRow.frame.minY, microsoftRow.frame.minY)
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        return app
    }
}
