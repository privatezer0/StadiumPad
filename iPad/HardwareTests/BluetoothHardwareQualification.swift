import XCTest

/// Opt-in read-only hardware qualification; excluded from routine UI tests.
@MainActor final class BluetoothHardwareQualification:XCTestCase {
    func testOptimisticSwitchRollsBackAfterDelayedRejection() {
        let app=XCUIApplication();app.launchArguments=["--optimistic-controls-harness"];app.launch()
        let control=app.switches.firstMatch
        XCTAssertTrue(control.waitForExistence(timeout:10));control.coordinate(withNormalizedOffset:CGVector(dx:0.94,dy:0.5)).tap()
        XCTAssertEqual(control.value as? String,"1")
        XCTAssertTrue(app.staticTexts["Awaiting confirmation"].exists)
        let restored=NSPredicate(format:"value == %@","0")
        expectation(for:restored,evaluatedWith:control);waitForExpectations(timeout:8)
        XCTAssertTrue(app.staticTexts["Native state unchanged"].exists)
    }
    func testModeChoiceAndRememberedStartup() {
        continueAfterFailure=false
        let app=XCUIApplication();app.launchEnvironment["STADIUM_VERIFY"]="1";app.launch()
        let hybrid=app.descendants(matching:.any).matching(identifier:"Hybrid connection").firstMatch
        let full=app.descendants(matching:.any).matching(identifier:"Full PedalBridge connection").firstMatch
        if hybrid.waitForExistence(timeout:40){hybrid.tap()}else{XCTAssertTrue(full.waitForExistence(timeout:10));full.tap()}
        let capture=XCTAttachment(screenshot:app.screenshot());capture.name="Connection preferences after badge tap";capture.lifetime = .keepAlways;add(capture)
        let picker=app.segmentedControls["stadium-connection-route"]
        XCTAssertTrue(picker.waitForExistence(timeout:5))
        picker.buttons["Full PedalBridge"].tap();XCTAssertTrue(full.waitForExistence(timeout:35))
        picker.buttons["Hybrid"].tap();XCTAssertTrue(hybrid.waitForExistence(timeout:35))
        app.buttons["Home"].tap()
        let modeCapture=XCTAttachment(screenshot:app.screenshot());modeCapture.name="Hybrid mode";modeCapture.lifetime = .keepAlways;add(modeCapture)
        app.terminate();app.launch()
        XCTAssertTrue(hybrid.waitForExistence(timeout:40))
        XCTAssertFalse(app.staticTexts["Stadium connection"].exists)
    }
    func testLeaveHybridHomeOpen() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app=XCUIApplication();app.launchEnvironment["STADIUM_VERIFY"]="1";app.launchArguments=["--capture-bluetooth-ui"];app.launch()
        let badge=app.descendants(matching:.any).matching(identifier:"Hybrid connection").firstMatch
        XCTAssertTrue(badge.waitForExistence(timeout:40))
        XCTAssertFalse(app.staticTexts["Stadium connection"].exists)
        let screenshot=XCUIScreen.main.screenshot()
        XCTAssertGreaterThan(screenshot.image.size.width,screenshot.image.size.height)
        let image=XCTAttachment(screenshot:screenshot);image.name="Final landscape Hybrid home";image.lifetime = .keepAlways;add(image)
    }
    func testInspectBluetoothSystemState() {
        let app=XCUIApplication();app.activate()
        let springboard=XCUIApplication(bundleIdentifier:"com.apple.springboard")
        for alert in app.alerts.allElementsBoundByIndex {for text in alert.staticTexts.allElementsBoundByIndex {print("App alert:",text.label)}}
        print("StadiumPad application state:",app.state.rawValue)
        for alert in springboard.alerts.allElementsBoundByIndex {print("System alert:",alert.label);for text in alert.staticTexts.allElementsBoundByIndex {print("Alert text:",text.label)}}
        if let cancel=springboard.alerts.buttons.matching(NSPredicate(format:"label == %@","Cancel")).allElementsBoundByIndex.first {cancel.tap()}
        let screen=XCTAttachment(screenshot:XCUIScreen.main.screenshot());screen.name="Current iPad system screen";screen.lifetime = .keepAlways;add(screen)
    }
    func testConnectionIndicatorAndHelperTab() {
        let app=XCUIApplication();app.launchEnvironment["STADIUM_VERIFY"]="1";app.activate()
        let badge=app.descendants(matching:.any).matching(identifier:"Full PedalBridge connection").firstMatch
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
