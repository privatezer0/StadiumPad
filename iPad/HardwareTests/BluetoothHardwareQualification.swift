import XCTest

/// Opt-in read-only hardware qualification; excluded from routine UI tests.
@MainActor final class BluetoothHardwareQualification:XCTestCase {
    func testConnectionIndicatorAndHelperTab() {
        let app=XCUIApplication();app.launchEnvironment["STADIUM_VERIFY"]="1";app.launch()
        let badge=app.buttons["Bluetooth connection"]
        XCTAssertTrue(badge.waitForExistence(timeout:40));XCTAssertEqual(badge.value as? String,"Connected")
        let home=XCTAttachment(screenshot:app.screenshot());home.name="Bluetooth connected";home.lifetime = .keepAlways;add(home)
        badge.tap()
        app.segmentedControls["pedalbridge-settings-tabs"].buttons["PedalBridge"].tap()
        XCTAssertTrue(app.staticTexts["Online · USB"].waitForExistence(timeout:20))
        let settings=XCTAttachment(screenshot:app.screenshot());settings.name="PedalBridge settings";settings.lifetime = .keepAlways;add(settings)
    }
    func testBluetoothReadOnlyQualification() {
        continueAfterFailure=false
        let app=XCUIApplication();app.launchArguments=["--verify-bluetooth"];app.launchEnvironment["STADIUM_VERIFY"]="1";app.launch()
        let springboard=XCUIApplication(bundleIdentifier:"com.apple.springboard")
        for _ in 0..<8 {
            let allow=springboard.buttons["Allow"]
            if allow.waitForExistence(timeout:2) {allow.tap()}
            let ok=springboard.buttons["OK"]
            if ok.exists {ok.tap()}
        }
        XCTAssertTrue(app.wait(for:.runningForeground,timeout:5))
    }
}
