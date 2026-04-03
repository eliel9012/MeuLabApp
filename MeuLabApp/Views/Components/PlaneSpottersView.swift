import SwiftUI

struct PlaneSpottersView: View {
    let registration: String
    @State private var imageURL: URL?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var photographer: String?

    var body: some View {
        Group {
            if let imageURL {
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .empty: ProgressView()
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        case .failure:
                            Text("Imagem indisponivel").font(.caption).foregroundStyle(.secondary)
                        @unknown default: EmptyView()
                        }
                    }
                    
                    if let photographer {
                        Text("© \(photographer)")
                            .font(.system(size: 8))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Color.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(4)
                    }
                }
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Sem foto disponível")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task { await loadImage() }
    }

    private func loadImage() async {
        do {
            let encoded = registration.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? registration
            let url = URL(string: "https://api.planespotters.net/pub/photos/reg/\(encoded)")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let photos = json?["photos"] as? [[String: Any]]
            
            guard let first = photos?.first else {
                await MainActor.run { 
                    errorMessage = "Imagem indisponivel"; 
                    isLoading = false 
                }
                return
            }
            
            let thumbLarge = (first["thumbnail_large"] as? [String: Any])?["src"] as? String
            let thumb = (first["thumbnail"] as? [String: Any])?["src"] as? String
            let photographerName = first["photographer"] as? String
            
            if let urlString = thumbLarge ?? thumb, let imgURL = URL(string: urlString) {
                await MainActor.run { 
                    self.imageURL = imgURL
                    self.photographer = photographerName
                    self.isLoading = false 
                }
                return
            }
            
            await MainActor.run { errorMessage = "Imagem indisponivel"; isLoading = false }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription; isLoading = false }
        }
    }
}
