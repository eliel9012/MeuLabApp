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

    func testInteractiveMapOpensAndCanClose() {
        let app = XCUIApplication()
        app.launch()

        let open = app.buttons["Mapa interativo"]
        XCTAssertTrue(open.waitForExistence(timeout: 15))
        open.tap()
        XCTAssertTrue(app.staticTexts["Mapa interativo"].waitForExistence(timeout: 10))
        let close = app.buttons["Fechar mapa"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        close.tap()
        app.activate()
        XCTAssertTrue(open.waitForExistence(timeout: 10))
    }

    func testFlightSearchOpensWithLiveAndAirportModes() {
        let app = XCUIApplication()
        app.launch()

        let open = app.buttons["Buscar voos"]
        XCTAssertTrue(open.waitForExistence(timeout: 15))
        open.tap()
        XCTAssertTrue(app.textFields["Número, matrícula ou ICAO"].waitForExistence(timeout: 10))
        app.buttons["Aeroportos"].tap()
        XCTAssertTrue(app.buttons["Atualizar"].waitForExistence(timeout: 10))
    }
}
