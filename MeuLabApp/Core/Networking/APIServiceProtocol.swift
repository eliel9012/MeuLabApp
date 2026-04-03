import Foundation

/// Protocol que define a interface de um serviço de API
/// Permite testes com mocks e múltiplas implementações
protocol APIServiceProtocol: AnyObject {
    // MARK: - ADS-B

    func fetchADSBSummary() async throws -> ADSBSummary
    func fetchAircraftList(limit: Int) async throws -> AircraftList
    func fetchADSBLolAircraft() async throws -> [Aircraft]

    // MARK: - System

    func fetchSystemStatus() async throws -> SystemStatus

    // MARK: - Radio

    func fetchNowPlaying() async throws -> NowPlaying

    // MARK: - Weather

    func fetchWeather() async throws -> WeatherData

    // MARK: - Satellite

    func fetchLastImages() async throws -> LastImages
    func fetchPasses() async throws -> PassesList
    func imageURL(passName: String, folderName: String, imageName: String) -> URL?
    func fetchImageData(passName: String, folderName: String, imageName: String) async throws -> Data

    // MARK: - ACARS

    func fetchACARSSummary() async throws -> ACARSSummary
    func fetchACARSMessages(limit: Int) async throws -> ACARSMessageList
    func fetchACARSHourly() async throws -> ACARSHourlyStats
    func searchACARSMessages(query: String) async throws -> ACARSSearchResult
}
