import SwiftUI

struct AircraftPhotoView: View {
    let aircraft: Aircraft
    
    @State private var imageURL: URL?
    @State private var isLoading = true
    @State private var photographer: String?
    @State private var sourceName: String?
    
    var body: some View {
        Group {
            if let imageURL {
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .success(let image):
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .clipped()
                        case .failure:
                            fallbackView
                        @unknown default:
                            EmptyView()
                        }
                    }
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        if let photographer {
                            Text("© \(photographer)")
                                .font(.system(size: 8))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        
                        if let sourceName {
                            Text(sourceName)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    .padding(6)
                }
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                noPhotoView
            }
        }
        .task {
            await loadPhoto()
        }
    }
    
    private var fallbackView: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Erro ao carregar imagem")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var noPhotoView: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Sem foto disponível")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func loadPhoto() async {
        let directReg = aircraft.registration?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hex = (aircraft.hex ?? aircraft.id).trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Tenta PlaneSpotters (pela matrícula já disponível)
        if let reg = directReg, !reg.isEmpty {
            if await tryPlaneSpotters(registration: reg) {
                return
            }
        }

        // 2. Se a matrícula não veio no payload, tenta resolver via HEX e buscar no PlaneSpotters
        if !hex.isEmpty, (directReg == nil || directReg?.isEmpty == true) {
            if let lookedUpReg = await HexLookupService.shared.lookup(hex: hex),
               await tryPlaneSpotters(registration: lookedUpReg) {
                return
            }
        }

        // 3. Tenta PlaneSpotters direto pelo HEX
        if !hex.isEmpty, await tryPlaneSpottersByHex(hex: hex) {
            return
        }

        // 4. Tenta OpenSky (pelo ICAO24/Hex)
        if !hex.isEmpty {
            if await tryOpenSky(icao24: hex) {
                return
            }
        }
        
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    private func tryPlaneSpotters(registration: String) async -> Bool {
        do {
            let encoded = registration.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? registration
            let url = URL(string: "https://api.planespotters.net/pub/photos/reg/\(encoded)")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let photos = json?["photos"] as? [[String: Any]]
            
            guard let first = photos?.first else { return false }
            
            let thumbLarge = (first["thumbnail_large"] as? [String: Any])?["src"] as? String
            let thumb = (first["thumbnail"] as? [String: Any])?["src"] as? String
            let photographerName = first["photographer"] as? String
            
            if let urlString = thumbLarge ?? thumb, let imgURL = URL(string: urlString) {
                await MainActor.run {
                    self.imageURL = imgURL
                    self.photographer = photographerName
                    self.sourceName = "PlaneSpotters"
                    self.isLoading = false
                }
                return true
            }
        } catch {
            print("[Photo] PlaneSpotters error: \(error.localizedDescription)")
        }
        return false
    }

    private func tryPlaneSpottersByHex(hex: String) async -> Bool {
        do {
            let encoded = hex.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? hex
            let url = URL(string: "https://api.planespotters.net/pub/photos/hex/\(encoded)")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let photos = json?["photos"] as? [[String: Any]]

            guard let first = photos?.first else { return false }

            let thumbLarge = (first["thumbnail_large"] as? [String: Any])?["src"] as? String
            let thumb = (first["thumbnail"] as? [String: Any])?["src"] as? String
            let photographerName = first["photographer"] as? String

            if let urlString = thumbLarge ?? thumb, let imgURL = URL(string: urlString) {
                await MainActor.run {
                    self.imageURL = imgURL
                    self.photographer = photographerName
                    self.sourceName = "PlaneSpotters"
                    self.isLoading = false
                }
                return true
            }
        } catch {
            print("[Photo] PlaneSpotters HEX error: \(error.localizedDescription)")
        }
        return false
    }
    
    private func tryOpenSky(icao24: String) async -> Bool {
        // OpenSky API para imagens de aeronaves
        // Nota: O endpoint de imagem retorna o binário diretamente ou 404
        let url = URL(string: "https://opensky-network.org/api/metadata/data/aircraft/icao24/\(icao24.lowercased())/image")!
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD" // Verifica apenas se existe
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                await MainActor.run {
                    self.imageURL = url
                    self.photographer = nil // OpenSky geralmente não provê o nome via este endpoint simples
                    self.sourceName = "OpenSky"
                    self.isLoading = false
                }
                return true
            }
        } catch {
            print("[Photo] OpenSky error: \(error.localizedDescription)")
        }
        return false
    }
}
