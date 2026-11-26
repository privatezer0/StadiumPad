import XCTest

/// Uses synthetic local faders: these tests cannot connect to a pedal or send MIDI.
@MainActor final class MatrixScrollingUITests:XCTestCase {
    func launch()->XCUIApplication {
        continueAfterFailure=false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app=XCUIApplication();app.launchArguments=["--matrix-scroll-harness"];app.launch()
        XCTAssertTrue(app.staticTexts["matrix-qa-changes"].waitForExistence(timeout:10))
        return app
    }
    func swipe(_ scroll:XCUIElement,left:Bool) {
        let start=scroll.coordinate(withNormalizedOffset:CGVector(dx:left ? 0.85:0.15,dy:0.5))
        let end=scroll.coordinate(withNormalizedOffset:CGVector(dx:left ? 0.15:0.85,dy:0.5))
        start.press(forDuration:0.05,thenDragTo:end)
    }
    func testExpandedHomeAndSongRemainScrollableAcrossFadersWithoutChangingLevels() {
        let app=launch(),scroll=app.scrollViews["matrix-qa-scroll"]
        app.buttons["Show Home paths"].tap()
        XCTAssertTrue(app.staticTexts["Path 1"].isHittable)
        app.buttons["Show Song tracks"].tap()
        for _ in 0..<5 {swipe(scroll,left:true)}
        XCTAssertTrue(app.staticTexts["AUX In"].isHittable)
        XCTAssertEqual(app.staticTexts["matrix-qa-changes"].label,"Changes: 0")
        for _ in 0..<5 {swipe(scroll,left:false)}
        XCTAssertTrue(app.buttons["Hide Home paths"].isHittable)
        app.buttons["Hide Home paths"].tap();app.buttons["Hide Song tracks"].tap()
        XCTAssertTrue(app.buttons["Show Home paths"].isHittable)
        XCTAssertTrue(app.buttons["Show Song tracks"].isHittable)
        XCTAssertEqual(app.staticTexts["matrix-qa-changes"].label,"Changes: 0")
    }
    func testVerticalFaderDragStillAdjustsTheLocalControl() {
        let app=launch()
        let fader=app.descendants(matching:.any).matching(identifier:"matrix-fader-5").firstMatch
        XCTAssertTrue(fader.waitForExistence(timeout:5))
        fader.coordinate(withNormalizedOffset:CGVector(dx:0.8,dy:0.5)).press(forDuration:0.05,thenDragTo:fader.coordinate(withNormalizedOffset:CGVector(dx:0.2,dy:0.5)))
        XCTAssertEqual(app.staticTexts["matrix-qa-changes"].label,"Changes: 0")
        fader.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.7)).press(forDuration:0.05,thenDragTo:fader.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.3)))
        XCTAssertNotEqual(app.staticTexts["matrix-qa-changes"].label,"Changes: 0")
    }
    func testUnavailableMatrixExplainsUSBWithoutOpeningMixer() {
        continueAfterFailure=false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app=XCUIApplication();app.launchArguments=["--matrix-unavailable"];app.launch()
        let button=app.buttons["Open Matrix Mixer"]
        XCTAssertTrue(button.waitForExistence(timeout:10))
        XCTAssertEqual(button.value as? String,"USB required")
        button.tap()
        let alert=app.alerts["USB connection required"]
        XCTAssertTrue(alert.waitForExistence(timeout:3))
        XCTAssertTrue(alert.staticTexts["Stadium must be connected via USB to either PedalBridge or your tablet to use Matrix Mixer."].exists)
        alert.buttons["OK"].tap()
        XCTAssertFalse(app.buttons["Close"].exists)
    }
    func testLastUserFolderRestoresAfterReloadAndOtherFoldersCollapse() {
        continueAfterFailure=false
        let app=XCUIApplication();app.launchArguments=["--preset-folder-harness","--reset-folder-memory"];app.launch()
        let working=app.buttons["Working, 0 presets, collapsed"]
        XCTAssertTrue(working.waitForExistence(timeout:10));working.tap()
        XCTAssertTrue(app.buttons["Working, 0 presets, expanded"].exists)
        XCTAssertTrue(app.buttons["All User Presets, 0 presets, collapsed"].exists)
        app.terminate();app.launchArguments=["--preset-folder-harness"];app.launch()
        XCTAssertTrue(app.buttons["Working, 0 presets, expanded"].waitForExistence(timeout:10))
        XCTAssertTrue(app.buttons["Practice, 0 presets, collapsed"].exists)
        app.buttons["Practice, 0 presets, collapsed"].tap()
        XCTAssertTrue(app.buttons["Practice, 0 presets, expanded"].exists)
        XCTAssertTrue(app.buttons["Working, 0 presets, collapsed"].exists)
    }
}
