import SwiftUI
import Photos

struct SatelliteView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedImage: SatelliteImage?
    @State private var showFullscreen = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let lastImages = appState.lastImages {
                        lastPassSection(lastImages)
                    } else if let error = appState.satelliteError {
                        ErrorCard(message: error)
                    } else {
                        LoadingCard()
                    }

                    // Recent passes
                    if !appState.passes.isEmpty {
                        recentPassesSection
                    }
                }
                .padding()
            }
            .navigationTitle("Satélite")
            .sheet(isPresented: $showFullscreen) {
                if let image = selectedImage {
                    SatelliteImageFullscreen(image: image)
                }
            }
        }
    }

    @ViewBuilder
    private func lastPassSection(_ lastImages: LastImages) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(.green)
                Text("Último Passe")
                    .font(.headline)
            }

            // Pass info
            VStack(alignment: .leading, spacing: 4) {
                Text(formatPassName(lastImages.passName))
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(lastImages.images.count) imagens")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Image gallery
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(lastImages.images) { image in
                        SatelliteImageCard(image: image) {
                            selectedImage = image
                            showFullscreen = true
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var recentPassesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Passes Recentes")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(appState.passes.prefix(10)) { pass in
                    PassRow(pass: pass)
                }
            }
        }
    }

    private func formatPassName(_ name: String) -> String {
        // Format: 2026-01-07_04-53_meteor_m2-x_lrpt_137.9 MHz
        let components = name.split(separator: "_")
        guard components.count >= 4 else { return name }

        let dateStr = String(components[0])
        let timeStr = String(components[1]).replacingOccurrences(of: "-", with: ":")

        var satellite = "Meteor M2"
        if name.contains("m2-x") {
            satellite = "Meteor M2-x"
        } else if name.contains("m2-4") {
            satellite = "Meteor M2-4"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateStr) {
            formatter.dateFormat = "dd/MM/yyyy"
            return "\(satellite) - \(formatter.string(from: date)) \(timeStr)"
        }

        return "\(satellite) - \(dateStr) \(timeStr)"
    }
}

struct SatelliteImageCard: View {
    let image: SatelliteImage
    let onTap: () -> Void

    @State private var imageData: Data?
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image
            ZStack {
                if let data = imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if isLoading {
                    ProgressView()
                } else {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 200, height: 150)
            .background(Color(.systemGray5))
            .cornerRadius(8)
            .clipped()

            // Legend
            Text(image.shortName)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .frame(width: 200, alignment: .leading)
        }
        .onTapGesture {
            onTap()
        }
        .task {
            await loadImage()
        }
    }

    private func loadImage() async {
        do {
            let data = try await APIService.shared.fetchImageData(
                passName: image.passName,
                folderName: image.folderName,
                imageName: image.name
            )
            await MainActor.run {
                self.imageData = data
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

struct SatelliteImageFullscreen: View {
    let image: SatelliteImage
    @Environment(\.dismiss) var dismiss

    @State private var imageData: Data?
    @State private var isLoading = true
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var isSaving = false
    @State private var showSaveSuccess = false
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let data = imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                    if scale < 1.0 {
                                        withAnimation {
                                            scale = 1.0
                                            lastScale = 1.0
                                        }
                                    }
                                }
                        )
                        .gesture(
                            TapGesture(count: 2)
                                .onEnded {
                                    withAnimation {
                                        if scale > 1.0 {
                                            scale = 1.0
                                            lastScale = 1.0
                                        } else {
                                            scale = 2.0
                                            lastScale = 2.0
                                        }
                                    }
                                }
                        )
                } else if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Erro ao carregar imagem")
                        .foregroundStyle(.white)
                }

                // Save success overlay
                if showSaveSuccess {
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                        Text("Salvo na Galeria")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .padding(30)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .navigationTitle(image.shortName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        saveToGallery()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Label("Salvar", systemImage: "square.and.arrow.down")
                        }
                    }
                    .disabled(imageData == nil || isSaving)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") {
                        dismiss()
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task {
            await loadImage()
        }
        .alert("Erro ao Salvar", isPresented: $showSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveErrorMessage)
        }
    }

    private func loadImage() async {
        do {
            let data = try await APIService.shared.fetchImageData(
                passName: image.passName,
                folderName: image.folderName,
                imageName: image.name
            )
            await MainActor.run {
                self.imageData = data
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    private func saveToGallery() {
        guard let data = imageData, let uiImage = UIImage(data: data) else { return }

        isSaving = true

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    PHPhotoLibrary.shared().performChanges {
                        PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
                    } completionHandler: { success, error in
                        DispatchQueue.main.async {
                            isSaving = false
                            if success {
                                withAnimation {
                                    showSaveSuccess = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation {
                                        showSaveSuccess = false
                                    }
                                }
                            } else {
                                saveErrorMessage = error?.localizedDescription ?? "Erro desconhecido"
                                showSaveError = true
                            }
                        }
                    }
                case .denied, .restricted:
                    isSaving = false
                    saveErrorMessage = "Permissão negada. Vá em Ajustes > Privacidade > Fotos para permitir."
                    showSaveError = true
                case .notDetermined:
                    isSaving = false
                @unknown default:
                    isSaving = false
                }
            }
        }
    }
}

struct PassRow: View {
    let pass: SatellitePass

    var body: some View {
        HStack {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .foregroundStyle(.green)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(pass.satelliteName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(pass.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "photo")
                    .font(.caption)
                Text("\(pass.imageCount)")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    SatelliteView()
        .environmentObject(AppState())
}
