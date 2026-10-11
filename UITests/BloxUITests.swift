import XCTest

final class BloxUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app.launchArguments = ["-uitest"]
    }

    func testEveryScreen() throws {
        app.launch()
        XCTAssertTrue(app.buttons["editProfile"].waitForExistence(timeout: 10))
        shot("01 new profile")

        app.buttons["editProfile"].tap()
        type("salw2e", into: app.textFields["usernameField"])
        type("salw2e", into: app.textFields["displayNameField"])
        type("55488", into: app.textFields["robuxField"])
        type("1", into: app.textFields["friendsField"])
        type("5585545", into: app.textFields["followersField"])
        type("0", into: app.textFields["followingField"])
        type("yo", into: app.textViews["bioField"])
        reveal(app.buttons["verifiedToggle"])
        app.buttons["verifiedToggle"].tap()
        app.buttons["badge-pro"].tap()
        shot("02 edit profile")

        reveal(app.textFields["copyUserField"])
        type("builderman", into: app.textFields["copyUserField"])
        app.buttons["copyButton"].tap()
        let status = app.staticTexts["copyStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 60))
        XCTAssertTrue(status.label.hasPrefix("Copied builderman"), status.label)
        shot("03 avatar copied")

        reveal(app.buttons["manageGames"])
        app.buttons["manageGames"].tap()
        let search = app.textFields["gameSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("adopt me\n")
        XCTAssertTrue(app.buttons["addGame"].firstMatch.waitForExistence(timeout: 30))
        app.buttons["addGame"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["chosenGame"].firstMatch.waitForExistence(timeout: 3))
        shot("04 games")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["closeEdit"].tap()

        XCTAssertTrue(app.staticTexts["followersChip"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["followersChip"].label, "5.6M Followers")
        XCTAssertEqual(app.staticTexts["friendsChip"].label, "1 Friends")
        XCTAssertEqual(app.staticTexts["displayName"].label, "salw2e")
        XCTAssertEqual(app.staticTexts["username"].label, "@salw2e")
        XCTAssertTrue(app.images["avatarImage"].exists)
        XCTAssertGreaterThan(app.descendants(matching: .any).matching(identifier: "wornItem").count, 0)
        shot("05 profile")
        app.swipeUp(velocity: .slow)
        shot("06 profile lower")
        app.swipeDown(velocity: .fast)

        app.buttons["editAppearance"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["robuxPill"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["robuxPill"].label.contains("55.5K"))
        let first = app.buttons["catalogItem"].firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 30))
        sleep(3)
        shot("07 marketplace")
        first.tap()
        XCTAssertTrue(app.buttons["wearButton"].waitForExistence(timeout: 5))
        shot("08 item")
        app.buttons["wearButton"].tap()
        app.buttons["tab-Customize"].tap()
        XCTAssertTrue(app.buttons["inventoryItem"].firstMatch.waitForExistence(timeout: 5))
        shot("09 customize")
        app.buttons["appearanceBack"].tap()

        reveal(app.buttons["viewFullProfile"])
        app.buttons["viewFullProfile"].tap()
        sleep(2)
        shot("10 full profile")

        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.staticTexts["followersChip"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["followersChip"].label, "5.6M Followers")
        XCTAssertTrue(app.images["avatarImage"].exists)
    }

    private func type(_ text: String, into field: XCUIElement) {
        dismissKeyboard()
        reveal(field)
        field.tap()
        let old = (field.value as? String) ?? ""
        if !old.isEmpty { field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count)) }
        field.typeText(text)
    }

    private func dismissKeyboard() {
        guard app.keyboards.count > 0 else { return }
        if app.buttons["Done"].exists { app.buttons["Done"].tap() }
        _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 3)
    }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func reveal(_ element: XCUIElement) {
        for _ in 0..<12 {
            if element.exists && element.isHittable && element.frame.maxY < app.windows.firstMatch.frame.height * 0.6 { return }
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(element.isHittable, "could not scroll to \(element)")
    }
}
