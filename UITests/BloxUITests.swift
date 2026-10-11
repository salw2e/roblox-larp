import XCTest

final class BloxUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app.launchArguments = ["-uitest"]
    }

    func testEveryScreen() throws {
        app.launch()
        XCTAssertTrue(app.buttons["tab-Home"].waitForExistence(timeout: 10))
        XCTAssertTrue(any("homeGame").waitForExistence(timeout: 40), "Home shows Roblox's games")
        sleep(4)   // let the pictures arrive
        shot("01 home new")

        app.buttons["menuButton"].tap()
        XCTAssertTrue(app.buttons["menuProfile"].waitForExistence(timeout: 5))
        shot("02 menu new")
        app.buttons["menuProfile"].tap()
        XCTAssertTrue(app.buttons["editProfile"].waitForExistence(timeout: 5))

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
        shot("03 edit profile")

        type("builderman", into: app.textFields["copyUserField"])
        dismissKeyboard()
        app.buttons["copyButton"].tap()
        let status = app.staticTexts["copyStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 60))
        XCTAssertTrue(status.label.hasPrefix("Copied builderman"), status.label)
        shot("04 avatar copied")

        type("roblox", into: app.textFields["friendUserField"])
        dismissKeyboard()
        app.buttons["addFriendButton"].tap()
        let added = app.staticTexts["friendStatus"]
        XCTAssertTrue(added.waitForExistence(timeout: 30))
        XCTAssertTrue(added.label.hasPrefix("Added"), added.label)
        type("11", into: app.textFields["notificationsField"])
        type("8", into: app.textFields["requestsField"])
        type("51", into: app.textFields["friendsBadgeField"])
        type("13", into: app.textFields["messagesField"])
        XCTAssertEqual(app.textFields["messagesField"].value as? String, "13")   // not "013"
        shot("05 friends and badges")

        reveal(app.buttons["manageGames"])
        app.buttons["manageGames"].tap()
        let search = app.textFields["gameSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("adopt me\n")
        XCTAssertTrue(app.buttons["addGame"].firstMatch.waitForExistence(timeout: 30))
        app.buttons["addGame"].firstMatch.tap()
        XCTAssertTrue(any("chosenGame").waitForExistence(timeout: 3))
        shot("06 games")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["closeEdit"].tap()

        XCTAssertTrue(app.staticTexts["followersChip"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["followersChip"].label, "5.6M Followers")
        XCTAssertEqual(app.staticTexts["friendsChip"].label, "1 Friends")
        XCTAssertEqual(app.staticTexts["displayName"].label, "salw2e")
        XCTAssertEqual(app.staticTexts["username"].label, "@salw2e")
        XCTAssertTrue(app.images["avatarImage"].exists)
        XCTAssertTrue(any("wornItem").exists)
        sleep(2)
        shot("07 profile")
        reveal(app.buttons["viewFullProfile"])
        shot("08 profile lower")
        app.buttons["viewFullProfile"].tap()
        sleep(2)
        shot("09 full profile")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.swipeDown(velocity: .fast)
        app.buttons["closeProfile"].tap()

        XCTAssertTrue(any("homeFriend").waitForExistence(timeout: 5))
        sleep(2)
        shot("10 home")
        app.buttons["home-Charts"].tap()
        sleep(2)
        shot("11 charts")

        app.buttons["menuButton"].tap()
        XCTAssertTrue(app.staticTexts["menuRobux"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["menuRobux"].label, "55,488")
        shot("12 menu")
        app.buttons["menu-Inventory"].tap()
        XCTAssertTrue(app.buttons["closePage"].waitForExistence(timeout: 5))
        shot("13 inventory")
        app.buttons["closePage"].tap()

        app.buttons["tab-Me"].tap()
        XCTAssertTrue(any("robuxPill").waitForExistence(timeout: 5))
        XCTAssertTrue(any("robuxPill").label.contains("55.5K"), any("robuxPill").label)
        let first = app.buttons["catalogItem"].firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 40))
        sleep(4)
        shot("14 marketplace")
        any("sheetHandle").tap()
        sleep(1)
        shot("14b sheet raised")
        any("sheetHandle").tap()
        sleep(1)
        first.tap()
        XCTAssertTrue(app.buttons["wearButton"].waitForExistence(timeout: 5))
        shot("15 item")
        app.buttons["wearButton"].tap()
        app.buttons["tab-Customize"].tap()
        XCTAssertTrue(app.buttons["inventoryItem"].firstMatch.waitForExistence(timeout: 5))
        shot("16 customize")

        app.buttons["tab-Chat"].tap()
        sleep(1)
        shot("17 chat")

        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.buttons["menuButton"].waitForExistence(timeout: 10))
        app.buttons["menuButton"].tap()
        XCTAssertTrue(app.staticTexts["menuRobux"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["menuRobux"].label, "55,488")
    }

    private func any(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }

    private func type(_ text: String, into field: XCUIElement) {
        reveal(field)
        field.tap()
        let old = (field.value as? String) ?? ""
        if !old.isEmpty, old != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count))
        }
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
        dismissKeyboard()
        let window = app.windows.firstMatch
        let top: CGFloat = 150, bottom = window.frame.height * 0.6
        func drag(from a: CGFloat, to b: CGFloat) {
            window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: a))
                .press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: b)))
        }
        var last = CGRect.null
        for _ in 0..<40 {
            let f = element.exists ? element.frame : .null
            if element.exists && element.isHittable && f.minY > top && f.maxY < bottom { return }
            if element.exists && f == last { break }
            last = f
            if element.exists && f.minY <= top { drag(from: 0.45, to: 0.6) } else { drag(from: 0.6, to: 0.45) }
        }
        XCTAssertTrue(element.exists && element.isHittable, "could not scroll to \(element)")
    }
}
