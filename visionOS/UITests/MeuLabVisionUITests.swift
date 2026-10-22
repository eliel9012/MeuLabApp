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
        let close = app.buttons["Fechar janela do mapa"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        close.tap()
        let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: close)
        wait(for: [closed], timeout: 10)
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

    func testTripShowsItineraryFlightsAndWeather() {
        let app = XCUIApplication()
        app.launch()

        let trip = app.buttons["Viagem"]
        XCTAssertTrue(trip.waitForExistence(timeout: 15))
        trip.tap()
        XCTAssertTrue(app.staticTexts["8 trechos confirmados"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Clima na rota"].exists)
        XCTAssertTrue(app.staticTexts["Roteiro"].exists)
    }

    func testRadioShowsHistorySection() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Rádio"].tap()
        XCTAssertTrue(app.staticTexts["Histórico recente"].waitForExistence(timeout: 20))
    }

    func testAnalyticsShowsSystemAndRadarSections() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Analytics"].tap()
        XCTAssertTrue(app.staticTexts["Sistema · dados do servidor"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Tráfego ADS-B · histórico do receptor"].exists)
    }

    func testAlertsShowsRulesAndTriggers() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Alertas"].tap()
        XCTAssertTrue(app.staticTexts["Disparos recentes"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Regras do servidor"].exists)
    }
}
