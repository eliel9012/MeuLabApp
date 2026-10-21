import XCTest

final class MeuLabVisionUITests: XCTestCase {
    func testRadar3DOpensAutomaticallyAndCanReopen() {
        let app = XCUIApplication()
        app.launch()

        let close = app.buttons["Fechar radar"]
        XCTAssertTrue(close.waitForExistence(timeout: 15))
        close.tap()
        let open = app.buttons["Radar 3D"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        open.tap()
        XCTAssertTrue(close.waitForExistence(timeout: 10))
    }
}
