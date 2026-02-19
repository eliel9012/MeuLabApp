import SwiftUI
import Photos
import UIKit
import ImageIO
import MapKit
import CoreLocation

enum PassFilter: String, CaseIterable {
    case all = "Todos"
    case meteor = "Meteor"
    case noaa = "NOAA"

    var displayName: String {
        return rawValue
    }
}

struct SatelliteView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var passPredictor = SatellitePassPredictor.shared
    @StateObject private var satelliteMapVM = SatelliteMapViewModel()
    @State private var selectedImage: SatelliteImage?
    @State private var showFullscreen = false
    @State private var selectedPass: SatellitePass?
    @State private var passImages: LastImages?
    @State private var isLoadingPassImages = false
    @State private var passImagesError: String?
    @State private var fullscreenImages: [SatelliteImage] = []
    @State private var showAllPasses = false
    @State private var allPasses: PassesListPaginated?
    @State private var isLoadingAllPasses = false
    @State private var allPassesError: String?
    @State private var selectedFilter: PassFilter = .all
    @State private var currentPage = 1
    @State private var showPassPredictions = false
    @State private var showOrbcomm = false
    @State private var lastPassCarouselSelection: String?
    @State private var isMapFullscreen = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let status = appState.satDumpStatus {
                        satDumpStatusSection(status)
                    }

                    satelliteMapSection

                    if let lastImages = appState.lastImages {
                        lastPassSection(lastImages)
                    } else if let error = appState.satelliteError {
                        ErrorCard(message: error)
                    } else {
                        LoadingCard()
                    }

                    // Seção de Próximos Passes (Previsão)
                    upcomingPassesSection

                    // All Passes Section
                    if showAllPasses {
                        allPassesSection
                    }

                    // Recent passes with "Show All" option
                    if !appState.passes.isEmpty {
                        recentPassesSection
                    }
                }
                .padding()
            }
            .navigationTitle("Satélite")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showPassPredictions = true
                        } label: {
                            Label("Próximos Passes", systemImage: "calendar.badge.clock")
                        }

                        Button {
                            showAllPasses.toggle()
                        } label: {
                            Label(showAllPasses ? "Últimos Passes" : "Todos os Passes", systemImage: "list.bullet.rectangle.portrait")
                        }

                        Divider()

                        Button {
                            showOrbcomm = true
                        } label: {
                            Label("ORBCOMM", systemImage: "dot.radiowaves.left.and.right")
                        }

                        Button {
                            downloadAllImages()
                        } label: {
                            Label("Download Completo", systemImage: "square.and.arrow.down")
                        }
                        .disabled(allPasses?.passes.isEmpty != false)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .navigationDestination(isPresented: $showOrbcomm) {
                OrbcommView()
            }
            .onAppear {
                satelliteMapVM.startPolling()
            }
            .onDisappear {
                satelliteMapVM.stopPolling()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    satelliteMapVM.startPolling()
                } else {
                    satelliteMapVM.stopPolling()
                }
            }
            .task {
                if passPredictor.predictedPasses.isEmpty {
                    await passPredictor.fetchAndPredict()
                }
            }
            .sheet(item: $satelliteMapVM.selectedSatellite) { satellite in
                SatelliteStatusSheetView(
                    satellite: satellite,
                    viewModel: satelliteMapVM
                )
            }
            .sheet(isPresented: $showFullscreen) {
                if let image = selectedImage {
                    SatelliteImageFullscreen(
                        images: !fullscreenImages.isEmpty ? fullscreenImages : [image],
                        selectedImageID: image.id
                    )
                }
            }
            .sheet(item: $selectedPass) { pass in
                SatellitePassImagesSheet(
                    pass: pass,
                    images: passImages,
                    isLoading: isLoadingPassImages,
                    errorMessage: passImagesError,
                    onImageTap: { image in
                        selectedImage = image
                        fullscreenImages = passImages?.images ?? [image]
                        showFullscreen = true
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .fullScreenCover(isPresented: $isMapFullscreen) {
                SatelliteFullscreenMapView(viewModel: satelliteMapVM)
            }
            .sheet(isPresented: $showAllPasses) {
                AllPassesView()
            }
            .sheet(isPresented: $showPassPredictions) {
                PassPredictionsSheet(predictor: passPredictor)
            }
        }
    }

    private var satelliteMapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Mapa Satelital", systemImage: "globe.europe.africa.fill")
                    .font(.headline)

                Spacer()

                Text("Satélites captáveis acima do horizonte: \(satelliteMapVM.captureableCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }

            SatelliteCoverageMapView(viewModel: satelliteMapVM)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onTapGesture {
                    isMapFullscreen = true
                }

            HStack(spacing: 14) {
                Label("Meteor", systemImage: "satellite.fill")
                    .font(.caption)
                    .foregroundStyle(.cyan)
                Label("ORBCOMM", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if satelliteMapVM.isLoading && satelliteMapVM.satellites.isEmpty {
                ProgressView("Carregando mapa satelital...")
                    .font(.caption)
            }

            if let error = satelliteMapVM.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Upcoming Passes Section

    private var upcomingPassesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Text("Próximos Passes")
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Spacer()

                if passPredictor.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button {
                        Task {
                            await passPredictor.fetchAndPredict()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                }
            }

            if let error = passPredictor.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if passPredictor.predictedPasses.isEmpty && !passPredictor.isLoading {
                Text("Nenhum passe previsto")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                // Próximos 3 passes
                ForEach(passPredictor.predictedPasses.prefix(3)) { pass in
                    PredictedPassRow(pass: pass)
                }

                // Botão para ver todos
                if passPredictor.predictedPasses.count > 3 {
                    Button {
                        showPassPredictions = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Ver todos os \(passPredictor.predictedPasses.count) passes")
                                .font(.subheadline)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                            Spacer()
                        }
                        .foregroundStyle(.blue)
                        .padding(.vertical, 8)
                    }
                }
            }

            // Info sobre localização
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.caption2)
                Text("Franca, SP (-20.51°, -47.40°)")
                    .font(.caption2)
                Spacer()
                if let update = passPredictor.lastUpdate {
                    Text("Atualizado: \(update.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                }
            }
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
    }

    @ViewBuilder
    private func lastPassSection(_ lastImages: LastImages) -> some View {
        let carouselImages = Array(lastImages.images.prefix(6))
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: lastImages.iconName)
                        .font(.title2)
                        .foregroundStyle(.green)
                    Text("Último Passe")
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Spacer()

                // Pass info badge
                Text("\(lastImages.images.count) imagens")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .foregroundStyle(.green)
                    .cornerRadius(12)
            }

            // Satellite info card
            HStack(spacing: 12) {
                Image(systemName: lastImages.iconName)
                    .font(.system(size: 32))
                    .foregroundStyle(.blue.gradient)

                VStack(alignment: .leading, spacing: 2) {
                    Text(formatPassName(lastImages.passName))
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(formatPassDateTime(lastImages.passName))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)

            // Premium image carousel
            TabView(selection: $lastPassCarouselSelection) {
                // TabView nao e lazy: carregar apenas a pagina selecionada evita pico de CPU na troca de tab.
                ForEach(carouselImages) { image in
                    SatelliteImageCarouselCard(
                        image: image,
                        shouldLoad: lastPassCarouselSelection == image.id
                    ) {
                        selectedImage = image
                        fullscreenImages = lastImages.images
                        showFullscreen = true
                    }
                    .tag(image.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(height: 280)
            .cornerRadius(16)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
        .onAppear {
            // Select first page once to trigger exactly one initial image load.
            if lastPassCarouselSelection == nil {
                lastPassCarouselSelection = carouselImages.first?.id
            }
        }
    }

    @ViewBuilder
    private func satDumpStatusSection(_ status: SatDumpStatus) -> some View {
        HStack(spacing: 12) {
            // Status indicator
            Image(systemName: status.iconName)
                .font(.title2)
                .foregroundStyle(status.isRecent ? Color.green : Color.orange)
                .frame(width: 32, height: 32)
                .background((status.isRecent ? Color.green : Color.orange).opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(status.isRecent ? "Passe Recente" : "Último Passe")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(status.imageCount) imagens - \(String(format: "%.1f", status.sizeMb)) MB")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("há \(String(format: "%.0f", status.ageMinutes)) min")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray5))
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var allPassesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Todos os Passes")
                    .font(.headline)
                Spacer()
                if isLoadingAllPasses {
                    ProgressView()
                }
            }

            if let passes = allPasses?.passes {
                LazyVStack(spacing: 8) {
                    ForEach(passes) { pass in
                        Button {
                            loadPassImages(pass.toSatellitePass)
                        } label: {
                            PassRowPremium(pass: pass.toSatellitePass)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if let error = allPassesError {
                Text(error)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            if allPasses == nil && !isLoadingAllPasses {
                loadAllPasses()
            }
        }
    }

    private func loadAllPasses() {
        isLoadingAllPasses = true
        Task {
            do {
                let passes = try await APIService.shared.fetchAllPasses(page: currentPage)
                await MainActor.run {
                    allPasses = passes
                    isLoadingAllPasses = false
                }
            } catch {
                await MainActor.run {
                    allPassesError = error.localizedDescription
                    isLoadingAllPasses = false
                }
            }
        }
    }

    private func downloadAllImages() {
        guard let passes = allPasses?.passes else { return }
        // Implementation for downloading all images
        print("Downloading images for \(passes.count) passes")
    }

    private var recentPassesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Passes Recentes")
                    .font(.headline)

                Spacer()

                Button {
                    showAllPasses = true
                } label: {
                    HStack(spacing: 4) {
                        Text("Ver Todos")
                            .font(.subheadline)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundStyle(.blue)
                }
            }

            LazyVStack(spacing: 8) {
                ForEach(appState.passes.prefix(5)) { pass in
                    Button {
                        loadPassImages(pass)
                    } label: {
                        PassRowPremium(pass: pass)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func formatPassName(_ name: String) -> String {
        var satellite = "Meteor M2"
        if name.contains("m2-x") {
            satellite = "Meteor M2-x"
        } else if name.contains("m2-4") {
            satellite = "Meteor M2-4"
        }
        return satellite
    }

    private func formatPassDateTime(_ name: String) -> String {
        let components = name.split(separator: "_")
        guard components.count >= 2 else { return name }

        let dateStr = String(components[0])
        let timeStr = String(components[1]).replacingOccurrences(of: "-", with: ":")

        if let date = Formatters.apiDate.date(from: dateStr) {
            let dateFormatted = Formatters.date.string(from: date).components(separatedBy: " ")[0]
            return "\(dateFormatted) as \(timeStr) BRT"
        }

        return "\(dateStr) \(timeStr)"
    }

    private func loadPassImages(_ pass: SatellitePass) {
        selectedPass = pass
        passImages = nil
        passImagesError = nil
        isLoadingPassImages = true

        Task {
            do {
                let images = try await APIService.shared.fetchPassImagesLossless(passName: pass.name)
                await MainActor.run {
                    passImages = images
                    isLoadingPassImages = false
                }
            } catch {
                await MainActor.run {
                    if let apiError = error as? APIError {
                        switch apiError {
                        case .unauthorized:
                            passImagesError = "Nao autorizado. Verifique o token da API."
                        case .serverError(let code) where code == 404:
                            passImagesError = "Passe nao encontrado (404)."
                        default:
                            passImagesError = apiError.localizedDescription
                        }
                    } else {
                        passImagesError = error.localizedDescription
                    }
                    isLoadingPassImages = false
                }
            }
        }
    }
}

// MARK: - Premium Carousel Card

struct SatelliteImageCarouselCard: View {
    let image: SatelliteImage
    let shouldLoad: Bool
    let onTap: () -> Void

    @State private var uiImage: UIImage?
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            // Image area
            ZStack {
                if let uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray5))
            .clipped()

            // Info bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(image.shortName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    if !image.cleanLegend.isEmpty {
                        Text(image.cleanLegend.components(separatedBy: "\n").first ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color(.systemBackground))
        }
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 4)
        .onTapGesture {
            onTap()
        }
        .task(id: shouldLoad) {
            guard shouldLoad else { return }
            await loadImageIfNeeded()
        }
    }

    private func loadImageIfNeeded() async {
        if uiImage != nil { return }
        do {
            // Use JPEG format for faster loading
            let data = try await APIService.shared.fetchImageLightJPEG(
                passName: image.passName,
                folderName: image.folderName,
                imageName: image.name,
                max: 512,
                quality: 75
            )
            if Task.isCancelled { return }

            // Decode off the main actor; decoding in `body` is expensive and repeats on recomposition.
            let decodeTask = Task.detached(priority: .utility) {
                ImageDownsampler.downsample(data: data, maxPixelSize: 900)
            }
            let decoded: UIImage? = await decodeTask.value

            if Task.isCancelled { return }

            await MainActor.run {
                self.uiImage = decoded
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

private enum ImageDownsampler {
    /// Decode image data as a thumbnail to reduce CPU/memory vs `UIImage(data:)`.
    static func downsample(data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let cfData = data as CFData
        let options: CFDictionary = [
            kCGImageSourceShouldCache: false
        ] as CFDictionary

        guard let source = CGImageSourceCreateWithData(cfData, options) else {
            return UIImage(data: data)
        }

        let thumbnailOptions: CFDictionary = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return UIImage(data: data)
        }

        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Premium Pass Row

struct PassRowPremium: View {
    let pass: SatellitePass

    var body: some View {
        HStack(spacing: 12) {
            // Satellite icon with gradient
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 44, height: 44)

                Image(systemName: pass.iconName)
                    .font(.system(size: 18))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(pass.satelliteName)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(pass.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Image count badge
            HStack(spacing: 4) {
                Image(systemName: "photo.stack")
                    .font(.caption)
                Text("\(pass.imageCount)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.systemGray5))
            .cornerRadius(8)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Fullscreen View

struct SatelliteImageFullscreen: View {
    let images: [SatelliteImage]
    @State var selectedImageID: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedImageID) {
                ForEach(images) { image in
                    SatelliteZoomableImage(image: image)
                        .tag(image.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(selectedImage?.shortName ?? "Imagem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let image = selectedImage,
                       let urlStr = image.imageLosslessUrl ?? image.imageLightUrl,
                       let url = URL(string: urlStr) {
                        ShareLink(item: url) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var selectedImage: SatelliteImage? {
        images.first { $0.id == selectedImageID }
    }
}

// MARK: - Zoomable Image with Legend Button

struct SatelliteZoomableImage: View {
    let image: SatelliteImage

    @State private var imageData: Data?
    @State private var isLoading = true
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isSaving = false
    @State private var isLoadingLegend = false
    @State private var showSaveSuccess = false
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let data = imageData, let uiImage = UIImage(data: data) {
                GeometryReader { proxy in
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = scale * delta
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                    if scale < 1.0 {
                                        withAnimation {
                                            scale = 1.0
                                            offset = .zero
                                        }
                                    }
                                }
                        )
                        .gesture(
                           DragGesture()
                               .onChanged { value in
                                   if scale > 1.0 {
                                       offset = CGSize(
                                           width: lastOffset.width + value.translation.width,
                                           height: lastOffset.height + value.translation.height
                                       )
                                   }
                               }
                               .onEnded { _ in
                                   if scale > 1.0 {
                                       lastOffset = offset
                                   }
                               }
                        )
                        .gesture(
                            TapGesture(count: 2)
                                .onEnded {
                                    withAnimation {
                                        if scale > 1.0 {
                                            scale = 1.0
                                            offset = .zero
                                            lastOffset = .zero
                                        } else {
                                            scale = 2.0
                                        }
                                    }
                                }
                        )
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            } else if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                    Text("Erro ao carregar imagem")
                        .foregroundStyle(.white.opacity(0.8))
                }
            }

            // Action buttons overlay
            VStack {
                Spacer()
                HStack(spacing: 16) {
                    // Legend button (with burn-in)
                    Button {
                        saveWithLegend()
                    } label: {
                        VStack(spacing: 4) {
                            if isLoadingLegend {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "text.below.photo.fill")
                                    .font(.system(size: 24))
                            }
                            Text("Legenda")
                                .font(.caption2)
                        }
                        .frame(width: 70, height: 60)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .foregroundStyle(.white)
                    }
                    .disabled(imageData == nil || isLoadingLegend)

                    Spacer()

                    // Save original button
                    Button {
                        saveToGallery()
                    } label: {
                        VStack(spacing: 4) {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 24))
                            }
                            Text("Salvar")
                                .font(.caption2)
                        }
                        .frame(width: 70, height: 60)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .foregroundStyle(.white)
                    }
                    .disabled(imageData == nil || isSaving)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }

            if showSaveSuccess {
                ToastView(icon: "checkmark.circle.fill", title: "Salvo", color: .green)
            }
            if showSaveError {
                ToastView(icon: "xmark.circle.fill", title: saveErrorMessage, color: .red)
            }
        }
        .task {
            await loadImage()
        }
        .onChange(of: image.id) { _, _ in
            scale = 1.0
            offset = .zero
        }
    }

    private func loadImage() async {
        do {
            let data: Data
            if image.imageLosslessUrl != nil {
                data = try await APIService.shared.fetchImageLosslessData(
                    passName: image.passName,
                    folderName: image.folderName,
                    imageName: image.name
                )
            } else {
                data = try await APIService.shared.fetchImageData(
                    passName: image.passName,
                    folderName: image.folderName,
                    imageName: image.name
                )
            }
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
                if status == .authorized || status == .limited {
                    PHPhotoLibrary.shared().performChanges {
                        PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
                    } completionHandler: { success, error in
                        DispatchQueue.main.async {
                            isSaving = false
                            if success {
                                withAnimation { showSaveSuccess = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation { showSaveSuccess = false }
                                }
                            } else {
                                saveErrorMessage = "Erro"
                                showSaveError = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation { showSaveError = false }
                                }
                            }
                        }
                    }
                } else {
                    isSaving = false
                    saveErrorMessage = "Sem permissao"
                    showSaveError = true
                }
            }
        }
    }

    private func saveWithLegend() {
        isLoadingLegend = true

        Task {
            do {
                // Fetch image with burned-in legend
                let data = try await APIService.shared.fetchImageWithLegend(
                    passName: image.passName,
                    folderName: image.folderName,
                    imageName: image.name,
                    format: "jpeg",
                    quality: 95
                )

                guard let uiImage = UIImage(data: data) else {
                    throw APIError.unknown
                }

                await MainActor.run {
                    isLoadingLegend = false
                }

                // Save to gallery
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                    DispatchQueue.main.async {
                        if status == .authorized || status == .limited {
                            PHPhotoLibrary.shared().performChanges {
                                PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
                            } completionHandler: { success, error in
                                DispatchQueue.main.async {
                                    if success {
                                        withAnimation { showSaveSuccess = true }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                            withAnimation { showSaveSuccess = false }
                                        }
                                    } else {
                                        saveErrorMessage = "Erro"
                                        showSaveError = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            withAnimation { showSaveError = false }
                                        }
                                    }
                                }
                            }
                        } else {
                            saveErrorMessage = "Sem permissao"
                            showSaveError = true
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isLoadingLegend = false
                    saveErrorMessage = "Erro na legenda"
                    showSaveError = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showSaveError = false
                    }
                }
            }
        }
    }
}

// MARK: - Toast View

struct ToastView: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundStyle(color)
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Pass Images Sheet

struct SatellitePassImagesSheet: View {
    let pass: SatellitePass
    let images: LastImages?
    let isLoading: Bool
    let errorMessage: String?
    let onImageTap: (SatelliteImage) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Carregando imagens...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if let errorMessage {
                    ErrorCard(message: errorMessage)
                } else if let images = images?.images, !images.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Header Info
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(pass.formattedDate)
                                        .font(.headline)
                                    Text("\(images.count) imagens capturadas")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "satellite")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.purple.opacity(0.8))
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)

                            Divider()
                                .padding(.horizontal)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(images) { image in
                                    SatelliteImageCard(image: image) {
                                        onImageTap(image)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.bottom)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Nenhuma imagem disponivel")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(pass.satelliteName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar", role: .cancel) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Image Card (for grid)

struct SatelliteImageCard: View {
    let image: SatelliteImage
    let onTap: () -> Void

    @State private var imageData: Data?
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray5))
            .cornerRadius(8)
            .clipped()

            Text(image.shortName)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)

            if !image.cleanLegend.isEmpty {
                Text(image.cleanLegend.components(separatedBy: "\n").first ?? "")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
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
            let data = try await APIService.shared.fetchImageLightJPEG(
                passName: image.passName,
                folderName: image.folderName,
                imageName: image.name,
                max: 400,
                quality: 80
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

// MARK: - All Passes View

struct AllPassesView: View {
    @Environment(\.dismiss) var dismiss
    @State private var passes: [SatellitePassExtended] = []
    @State private var isLoading = true
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var errorMessage: String?
    @State private var selectedPass: SatellitePass?
    @State private var passImages: LastImages?
    @State private var isLoadingImages = false
    @State private var imagesError: String?
    @State private var selectedImage: SatelliteImage?
    @State private var showFullscreen = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && passes.isEmpty {
                    ProgressView("Carregando passes...")
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text(error)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List {
                        ForEach(passes) { pass in
                            Button {
                                loadPassImages(pass.toSatellitePass)
                            } label: {
                                PassRowExtended(pass: pass)
                            }
                            .buttonStyle(.plain)
                        }

                        if currentPage < totalPages {
                            Button {
                                loadMorePasses()
                            } label: {
                                HStack {
                                    Spacer()
                                    if isLoading {
                                        ProgressView()
                                    } else {
                                        Text("Carregar mais...")
                                    }
                                    Spacer()
                                }
                            }
                            .disabled(isLoading)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Todos os Passes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedPass) { pass in
                SatellitePassImagesSheet(
                    pass: pass,
                    images: passImages,
                    isLoading: isLoadingImages,
                    errorMessage: imagesError,
                    onImageTap: { image in
                        selectedImage = image
                        showFullscreen = true
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showFullscreen) {
                if let image = selectedImage {
                    SatelliteImageFullscreen(
                        images: passImages?.images ?? [image],
                        selectedImageID: image.id
                    )
                }
            }
        }
        .task {
            await loadPasses()
        }
    }

    private func loadPassImages(_ pass: SatellitePass) {
        selectedPass = pass
        passImages = nil
        imagesError = nil
        isLoadingImages = true

        Task {
            do {
                let images = try await APIService.shared.fetchPassImagesLossless(passName: pass.name)
                await MainActor.run {
                    passImages = images
                    isLoadingImages = false
                }
            } catch {
                await MainActor.run {
                    if let apiError = error as? APIError {
                        switch apiError {
                        case .unauthorized:
                            imagesError = "Nao autorizado"
                        case .serverError(let code) where code == 404:
                            imagesError = "Passe nao encontrado (404)"
                        default:
                            imagesError = apiError.localizedDescription
                        }
                    } else {
                        imagesError = error.localizedDescription
                    }
                    isLoadingImages = false
                }
            }
        }
    }

    private func loadPasses() async {
        isLoading = true
        do {
            let result = try await APIService.shared.fetchAllPasses(page: 1, limit: 50)
            await MainActor.run {
                passes = result.passes
                currentPage = result.page
                totalPages = result.totalPages
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func loadMorePasses() {
        guard !isLoading else { return }
        isLoading = true

        Task {
            do {
                let result = try await APIService.shared.fetchAllPasses(page: currentPage + 1, limit: 50)
                await MainActor.run {
                    passes.append(contentsOf: result.passes)
                    currentPage = result.page
                    totalPages = result.totalPages
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

struct PassRowExtended: View {
    let pass: SatellitePassExtended

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(pass.satelliteName)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(pass.qualityStarsDisplay)
                        .font(.caption)
                }

                Text(pass.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(pass.imageCount) img")
                    .font(.caption)
                    .fontWeight(.medium)

                Text("\(String(format: "%.1f", pass.sizeMb)) MB")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Predicted Pass Row

struct PredictedPassRow: View {
    let pass: PredictedPass

    var body: some View {
        HStack(spacing: 12) {
            // Ícone de qualidade
            ZStack {
                Circle()
                    .fill(qualityColor.opacity(0.2))
                    .frame(width: 44, height: 44)

                VStack(spacing: 0) {
                    Text("\(Int(pass.maxElevation))°")
                        .font(.system(size: 14, weight: .bold))
                    Text("elev")
                        .font(.system(size: 8))
                }
                .foregroundStyle(qualityColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(pass.safeSatelliteName)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(String(repeating: "★", count: pass.qualityStars))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                HStack(spacing: 8) {
                    // Data
                    Text(pass.formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Horários UTC/BRT
                    HStack(spacing: 4) {
                        Text(pass.formattedAOSutc)
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("UTC")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("/")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(pass.formattedAOSbrt)
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("BRT")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(pass.timeUntil)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)

                Text("\(Int(pass.durationMinutes)) min")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var qualityColor: Color {
        switch pass.qualityStars {
        case 5: return .green
        case 4: return .mint
        case 3: return .blue
        case 2: return .orange
        default: return .gray
        }
    }
}

// MARK: - Pass Predictions Sheet

struct PassPredictionsSheet: View {
    @ObservedObject var predictor: SatellitePassPredictor
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Info section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "satellite")
                                .foregroundStyle(.blue)
                            Text("Meteor M2-x")
                                .fontWeight(.semibold)
                        }

                        if let tle = predictor.tleData {
                            HStack {
                                Text("Periodo orbital:")
                                    .foregroundStyle(.secondary)
                                Text("\(String(format: "%.1f", tle.orbitalPeriod)) min")
                            }
                            .font(.caption)

                            HStack {
                                Text("Inclinacao:")
                                    .foregroundStyle(.secondary)
                                Text("\(String(format: "%.1f", tle.inclination))°")
                            }
                            .font(.caption)
                        }

                        HStack {
                            Image(systemName: "location.fill")
                                .font(.caption)
                            Text("Franca, SP (-20.51°, -47.40°)")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Informacoes")
                }

                // Passes section
                Section {
                    if predictor.predictedPasses.isEmpty {
                        Text("Nenhum passe previsto")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(predictor.predictedPasses) { pass in
                            PredictedPassDetailRow(pass: pass, predictor: predictor)
                        }
                    }
                } header: {
                    HStack {
                        Text("Proximos Passes")
                        Spacer()
                        if predictor.isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                } footer: {
                    Text("Previsoes baseadas em dados TLE do Celestrak. Elevacao minima: 10°")
                }
            }
            .navigationTitle("Previsao de Passes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task {
                            await predictor.fetchAndPredict()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(predictor.isLoading)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PredictedPassDetailRow: View {
    let pass: PredictedPass
    let predictor: SatellitePassPredictor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header com data e qualidade
            HStack {
                Text(pass.formattedDateFull)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                HStack(spacing: 2) {
                    Text(String(repeating: "★", count: pass.qualityStars))
                        .foregroundStyle(.orange)
                    Text(pass.qualityDescription)
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }

            // Horários
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("UTC")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(pass.formattedAOSutc)
                        .font(.headline)
                        .monospacedDigit()
                }

                VStack(alignment: .leading) {
                    Text("BRT")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(pass.formattedAOSbrt)
                        .font(.headline)
                        .monospacedDigit()
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text(pass.timeUntil)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                }
            }

            Divider()

            // Detalhes do passe
            HStack {
                PassDetailItem(label: "Elevacao Max", value: "\(Int(pass.maxElevation))°")
                Spacer()
                PassDetailItem(label: "Duracao", value: "\(Int(pass.durationMinutes)) min")
                Spacer()
                PassDetailItem(label: "AOS", value: predictor.azimuthDirection(pass.azimuthAOS))
                Spacer()
                PassDetailItem(label: "LOS", value: predictor.azimuthDirection(pass.azimuthLOS))
            }
        }
        .padding(.vertical, 4)
    }
}

struct PassDetailItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - ORBCOMM

enum OrbcommSection: String, CaseIterable, Identifiable {
    case jsonl = "JSONL"
    case logs = "Logs"

    var id: String { rawValue }
}

@MainActor
final class OrbcommViewModel: ObservableObject {
    @Published var runs: [OrbcommRun] = []
    @Published var selectedRunName: String = ""

    @Published var isLoadingRuns = false
    @Published var isLoadingJSONL = false
    @Published var isLoadingLogs = false

    @Published var runsError: String?
    @Published var jsonlError: String?
    @Published var logsError: String?

    @Published var jsonlLimit: Int = 200
    @Published var logsLimit: Int = 500

    @Published var jsonlTimestamp: String = ""
    @Published var jsonlRun: String = ""
    @Published var jsonlCount: Int = 0
    @Published var jsonlLines: [String] = []

    @Published var logsTimestamp: String = ""
    @Published var logsRun: String = ""
    @Published var logsCount: Int = 0
    @Published var logsLines: [String] = []

    @Published var tailLogsEnabled: Bool = false

    private let jsonlLimitSteps: [Int] = [200, 500, 1000]
    private let logsLimitSteps: [Int] = [500, 1000, 2000, 5000]
    private let tailIntervalNs: UInt64 = 3_000_000_000

    private var tailTask: Task<Void, Never>?

    var nextJSONLLimit: Int? {
        jsonlLimitSteps.first(where: { $0 > jsonlLimit })
    }

    var nextLogsLimit: Int? {
        logsLimitSteps.first(where: { $0 > logsLimit })
    }

    func loadInitial(section: OrbcommSection) async {
        await refreshRuns()
        await load(section: section)
    }

    func refreshRuns() async {
        if isLoadingRuns { return }
        isLoadingRuns = true
        runsError = nil
        do {
            let response = try await APIService.shared.fetchOrbcommRunsNonempty(limit: 200)
            runs = response.runs

            // Default: latest (API usually returns newest first).
            if selectedRunName.isEmpty || !runs.contains(where: { $0.name == selectedRunName }) {
                selectedRunName = runs.first?.name ?? ""
            }
        } catch {
            runsError = "Erro ao carregar runs: \(error.localizedDescription)"
        }
        isLoadingRuns = false
    }

    func load(section: OrbcommSection) async {
        switch section {
        case .jsonl:
            await loadJSONL()
        case .logs:
            await loadLogs()
        }
    }

    func loadJSONL() async {
        if isLoadingJSONL { return }
        isLoadingJSONL = true
        jsonlError = nil
        do {
            let response = try await APIService.shared.fetchOrbcommDecoded(
                run: selectedRunName.isEmpty ? nil : selectedRunName,
                limit: jsonlLimit
            )

            jsonlTimestamp = response.timestamp
            jsonlRun = response.run
            jsonlCount = response.count

            let events = Array(response.events.prefix(jsonlLimit))
            jsonlLines = await Self.compactJSONLines(from: events)
        } catch {
            jsonlLines = []
            jsonlError = "Erro ao carregar eventos: \(error.localizedDescription)"
        }
        isLoadingJSONL = false
    }

    func loadLogs() async {
        if isLoadingLogs { return }
        isLoadingLogs = true
        logsError = nil
        do {
            let response = try await APIService.shared.fetchOrbcommLogs(
                run: selectedRunName.isEmpty ? nil : selectedRunName,
                limit: logsLimit
            )

            logsTimestamp = response.timestamp
            logsRun = response.run
            logsCount = response.count
            logsLines = Array(response.lines.prefix(logsLimit))
        } catch {
            logsLines = []
            logsError = "Erro ao carregar logs: \(error.localizedDescription)"
        }
        isLoadingLogs = false
    }

    func stepUpJSONLLimitAndReload() async {
        guard let next = nextJSONLLimit else { return }
        jsonlLimit = next
        await loadJSONL()
    }

    func stepUpLogsLimitAndReload() async {
        guard let next = nextLogsLimit else { return }
        logsLimit = next
        await loadLogs()
    }

    func setTailLogsEnabled(_ enabled: Bool) {
        tailLogsEnabled = enabled
        tailTask?.cancel()
        tailTask = nil

        guard enabled else { return }

        tailTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.loadLogs()
                try? await Task.sleep(nanoseconds: self.tailIntervalNs)
            }
        }
    }

    func stopTailLogs() {
        tailTask?.cancel()
        tailTask = nil
    }

    private static func compactJSONLines(from events: [AnyCodable]) async -> [String] {
        await Task.detached(priority: .userInitiated) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = []
            return events.map { event in
                guard let data = try? encoder.encode(event),
                      let str = String(data: data, encoding: .utf8) else {
                    return "(invalid json)"
                }
                return str.replacingOccurrences(of: "\n", with: "")
            }
        }.value
    }
}

struct OrbcommView: View {
    @StateObject private var vm = OrbcommViewModel()
    @State private var section: OrbcommSection = .jsonl
    @State private var searchText: String = ""

    var body: some View {
        List {
            Section {
                Picker("Run", selection: $vm.selectedRunName) {
                    ForEach(vm.runs) { run in
                        Text(run.name).tag(run.name)
                    }
                }
                .pickerStyle(.menu)
                .disabled(vm.runs.isEmpty)

                Picker("Aba", selection: $section) {
                    ForEach(OrbcommSection.allCases) { sec in
                        Text(sec.rawValue).tag(sec)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 12) {
                    if section == .jsonl {
                        Text("Eventos: \(vm.jsonlCount)")
                        Text("Limit: \(vm.jsonlLimit)")
                    } else {
                        Text("Linhas: \(vm.logsCount)")
                        Text("Limit: \(vm.logsLimit)")
                    }

                    Spacer()

                    if vm.isLoadingRuns {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let err = vm.runsError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section {
                switch section {
                case .jsonl:
                    jsonlSection
                case .logs:
                    logsSection
                }
            }

            if section == .jsonl, let next = vm.nextJSONLLimit {
                Section {
                    Button("Carregar mais (\(next))") {
                        Task { await vm.stepUpJSONLLimitAndReload() }
                    }
                }
            }

            if section == .logs, let next = vm.nextLogsLimit {
                Section {
                    Button("Carregar mais (\(next))") {
                        Task { await vm.stepUpLogsLimitAndReload() }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("ORBCOMM")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if section == .logs {
                        Button(vm.tailLogsEnabled ? "Desativar Tail logs" : "Ativar Tail logs") {
                            vm.setTailLogsEnabled(!vm.tailLogsEnabled)
                        }
                    }

                    Button("Atualizar") {
                        Task { await vm.load(section: section) }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .searchable(text: $searchText, prompt: section == .jsonl ? "Buscar eventos..." : "Buscar logs...")
        .refreshable {
            await vm.refreshRuns()
            await vm.load(section: section)
        }
        .task {
            await vm.loadInitial(section: section)
        }
        .onChange(of: section) { _, newValue in
            searchText = ""
            if newValue != .logs {
                vm.setTailLogsEnabled(false)
            }
            Task { await vm.load(section: newValue) }
        }
        .onChange(of: vm.selectedRunName) { _, _ in
            Task { await vm.load(section: section) }
        }
        .onDisappear {
            vm.setTailLogsEnabled(false)
        }
    }

    @ViewBuilder
    private var jsonlSection: some View {
        if vm.isLoadingJSONL && vm.jsonlLines.isEmpty {
            ProgressView("Carregando eventos...")
        } else if let err = vm.jsonlError {
            ErrorCard(message: err)
        } else if filteredJSONLLines.isEmpty {
            ContentUnavailableView("Sem eventos", systemImage: "doc.text.magnifyingglass")
        } else {
            let items = filteredJSONLLines
            ForEach(items.indices, id: \.self) { i in
                let item = items[i]
                let previous = i > 0 ? items[i - 1].text : nil
                NavigationLink {
                    OrbcommEventDetailView(jsonLine: item.text, previousLine: previous)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("#\(item.id + 1)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(item.text)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(3)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    @ViewBuilder
    private var logsSection: some View {
        if vm.isLoadingLogs && vm.logsLines.isEmpty {
            ProgressView("Carregando logs...")
        } else if let err = vm.logsError {
            ErrorCard(message: err)
        } else if filteredLogLines.isEmpty {
            ContentUnavailableView("Sem logs", systemImage: "text.magnifyingglass")
        } else {
            ForEach(filteredLogLines, id: \.id) { item in
                NavigationLink {
                    OrbcommTextDetailView(title: "Log", text: item.text)
                } label: {
                    Text(item.text)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(2)
                        .padding(.vertical, 4)
                }
            }
        }
    }

    private var filteredJSONLLines: [(id: Int, text: String)] {
        vm.jsonlLines.enumerated().compactMap { idx, line in
            if searchText.isEmpty || line.localizedCaseInsensitiveContains(searchText) {
                return (id: idx, text: line)
            }
            return nil
        }
    }

    private var filteredLogLines: [(id: Int, text: String)] {
        vm.logsLines.enumerated().compactMap { idx, line in
            if searchText.isEmpty || line.localizedCaseInsensitiveContains(searchText) {
                return (id: idx, text: line)
            }
            return nil
        }
    }
}

struct OrbcommEventDetailView: View {
    let jsonLine: String
    let previousLine: String?
    let prettyJSON: String
    private let interpreted: OrbcommInterpreted?
    private let trend: OrbcommTrend?

    @State private var isSharePresented = false
    @State private var shareItems: [Any] = []

    init(jsonLine: String, previousLine: String? = nil) {
        self.jsonLine = jsonLine
        self.previousLine = previousLine
        self.prettyJSON = Self.prettyPrinted(jsonLine)
        let cur = OrbcommInterpreted.parse(jsonLine: jsonLine)
        self.interpreted = cur
        self.trend = OrbcommTrend.compute(current: cur, previousLine: previousLine)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let interpreted {
                    GroupBox("Interpretado") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(interpreted.satName ?? "-")
                                    .font(.headline)
                                Spacer()
                                Text(interpreted.localTimestampShort ?? "-")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 14) {
                                OrbcommMetric(label: "Azimute", value: interpreted.azimuthText)
                                OrbcommMetric(label: "Elevação", value: interpreted.elevationText)
                                OrbcommMetric(label: "Doppler", value: interpreted.dopplerText)
                            }

                            if let trend {
                                Text(trend.text)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let speed = interpreted.radialSpeedText {
                                Text(speed)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text(interpreted.frequencyText)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let pkt = interpreted.packetSummary {
                                Text(pkt)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                GroupBox("JSONL") {
                    Text(jsonLine)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Pretty") {
                    Text(prettyJSON)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .navigationTitle("Evento")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        UIPasteboard.general.string = jsonLine
                    } label: {
                        Label("Copiar JSONL", systemImage: "doc.on.doc")
                    }

                    Button {
                        UIPasteboard.general.string = prettyJSON
                    } label: {
                        Label("Copiar Pretty", systemImage: "doc.on.doc")
                    }

                    Button {
                        presentShare([jsonLine])
                    } label: {
                        Label("Compartilhar JSONL", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        presentShare([prettyJSON])
                    } label: {
                        Label("Compartilhar Pretty", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isSharePresented) {
            ShareSheet(activityItems: shareItems)
        }
    }

    private func presentShare(_ items: [Any]) {
        shareItems = items
        isSharePresented = true
    }

    private static func prettyPrinted(_ jsonLine: String) -> String {
        guard let data = jsonLine.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: prettyData, encoding: .utf8) else {
            return jsonLine
        }
        return str
    }
}

private struct OrbcommMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct OrbcommInterpreted {
    let satName: String?
    let timestampUTC: Date?
    let azimuthDeg: Double?
    let elevationDeg: Double?
    let dopplerHz: Double?
    let centerFrequencyHz: Double
    let centerFrequencySource: String
    let packetType: String?
    let packetHex: String?

    // ORBCOMM downlink is around 137-138 MHz. Used as fallback for a rough radial-speed estimate.
    private static let assumedCenterHz: Double = 137_500_000

    // Optional per-satellite override (if you know the exact downlink center frequency).
    // Keying by normalized sat_name (lowercased).
    private static let perSatelliteCenterHz: [String: Double] = [:]

    var localTimestampShort: String? {
        guard let timestampUTC else { return nil }
        return Formatters.date.string(from: timestampUTC)
    }

    var azimuthText: String {
        guard let azimuthDeg else { return "-" }
        return String(format: "%.1f° (%@)", azimuthDeg, Self.cardinal(azimuthDeg))
    }

    var elevationText: String {
        guard let elevationDeg else { return "-" }
        return String(format: "%.1f°", elevationDeg)
    }

    var dopplerText: String {
        guard let dopplerHz else { return "-" }
        return String(format: "%.0f Hz", dopplerHz)
    }

    var radialSpeedText: String? {
        guard let dopplerHz else { return nil }
        let c = 299_792_458.0
        let v = (dopplerHz / centerFrequencyHz) * c // m/s
        let kmh = v * 3.6
        return String(format: "Velocidade radial aprox: %.0f km/h", kmh)
    }

    var frequencyText: String {
        let mhz = centerFrequencyHz / 1_000_000.0
        return String(format: "Freq. usada: %.3f MHz (%@)", mhz, centerFrequencySource)
    }

    var packetSummary: String? {
        guard packetType != nil || packetHex != nil else { return nil }
        let type = packetType ?? "-"
        if let hex = packetHex, !hex.isEmpty {
            let bytes = max(0, hex.count / 2)
            return "Packet: \(type) • \(bytes) bytes"
        }
        return "Packet: \(type)"
    }

    static func parse(jsonLine: String) -> OrbcommInterpreted? {
        guard let data = jsonLine.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let satName = obj["sat_name"] as? String
        let ts = obj["timestamp"] as? String
        let tsDate = Formatters.isoDateNoFrac.date(from: ts ?? "") ?? Formatters.isoDate.date(from: ts ?? "")

        let az = (obj["azimuth"] as? NSNumber)?.doubleValue ?? obj["azimuth"] as? Double
        let el = (obj["elevation"] as? NSNumber)?.doubleValue ?? obj["elevation"] as? Double
        let dop = (obj["doppler"] as? NSNumber)?.doubleValue ?? obj["doppler"] as? Double

        // Best-effort center frequency extraction (if backend includes it later).
        let (centerHz, centerSrc) = pickCenterFrequencyHz(obj: obj, satName: satName)

        var pktType: String? = nil
        var pktHex: String? = nil
        if let pkt = obj["packet"] as? [String: Any] {
            pktType = pkt["packet_type"] as? String
            pktHex = pkt["data"] as? String
        }

        return OrbcommInterpreted(
            satName: satName,
            timestampUTC: tsDate,
            azimuthDeg: az,
            elevationDeg: el,
            dopplerHz: dop,
            centerFrequencyHz: centerHz,
            centerFrequencySource: centerSrc,
            packetType: pktType,
            packetHex: pktHex
        )
    }

    private static func pickCenterFrequencyHz(obj: [String: Any], satName: String?) -> (Double, String) {
        func toHz(_ any: Any?) -> Double? {
            if let n = any as? NSNumber { return n.doubleValue }
            if let d = any as? Double { return d }
            if let i = any as? Int { return Double(i) }
            if let s = any as? String, let v = Double(s.trimmingCharacters(in: .whitespacesAndNewlines)) { return v }
            return nil
        }

        // Common keys we might add on the backend in the future.
        let keys = [
            "frequency_hz", "freq_hz", "center_hz", "center_frequency_hz",
            "frequency", "freq"
        ]
        for k in keys {
            if let v = toHz(obj[k]) {
                return (normalizeHz(v), "evento:\(k)")
            }
        }
        if let pkt = obj["packet"] as? [String: Any] {
            for k in keys {
                if let v = toHz(pkt[k]) {
                    return (normalizeHz(v), "packet:\(k)")
                }
            }
        }

        let normName = (satName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let v = perSatelliteCenterHz[normName] {
            return (v, "por satelite")
        }

        return (assumedCenterHz, "fallback")
    }

    private static func normalizeHz(_ v: Double) -> Double {
        // If someone sends MHz (e.g. 137.5), convert to Hz.
        if v > 0, v < 1_000_000 {
            return v * 1_000_000
        }
        return v
    }

    private static func cardinal(_ degrees: Double) -> String {
        // 16-wind compass
        let dirs = ["N","NNE","NE","ENE","E","ESE","SE","SSE","S","SSW","SW","WSW","W","WNW","NW","NNW"]
        let d = (degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        let idx = Int((d / 22.5).rounded()) % dirs.count
        return dirs[idx]
    }
}

private struct OrbcommTrend {
    let deltaHz: Double
    let deltaSeconds: Double

    var text: String {
        let arrow = deltaHz > 0 ? "Doppler subindo" : (deltaHz < 0 ? "Doppler caindo" : "Doppler estavel")
        return String(format: "%@ (Δ %.0f Hz / %.1f s)", arrow, deltaHz, deltaSeconds)
    }

    static func compute(current: OrbcommInterpreted?, previousLine: String?) -> OrbcommTrend? {
        guard let current,
              let prevLine = previousLine,
              let prev = OrbcommInterpreted.parse(jsonLine: prevLine) else {
            return nil
        }
        // Only compare same satellite name if present.
        if let a = current.satName?.lowercased(), let b = prev.satName?.lowercased(), !a.isEmpty, !b.isEmpty, a != b {
            return nil
        }
        guard let curD = current.dopplerHz, let prevD = prev.dopplerHz else { return nil }
        guard let curT = current.timestampUTC, let prevT = prev.timestampUTC else { return nil }
        let dt = curT.timeIntervalSince(prevT)
        guard dt != 0 else { return nil }
        return OrbcommTrend(deltaHz: curD - prevD, deltaSeconds: abs(dt))
    }
}

struct OrbcommTextDetailView: View {
    let title: String
    let text: String

    @State private var isSharePresented = false
    @State private var shareItems: [Any] = []

    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        UIPasteboard.general.string = text
                    } label: {
                        Label("Copiar", systemImage: "doc.on.doc")
                    }

                    Button {
                        presentShare([text])
                    } label: {
                        Label("Compartilhar", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isSharePresented) {
            ShareSheet(activityItems: shareItems)
        }
    }

    private func presentShare(_ items: [Any]) {
        shareItems = items
        isSharePresented = true
    }
}

@MainActor
final class SatelliteMapViewModel: ObservableObject {
    @Published private(set) var satellites: [SatellitePosition] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    @Published var selectedSatellite: SatellitePosition?
    @Published private(set) var selectedStatus: SatelliteStatusResponse?
    @Published private(set) var isLoadingStatus = false
    @Published private(set) var statusErrorMessage: String?

    let stationCoordinate = CLLocationCoordinate2D(latitude: -20.5125, longitude: -47.4009)
    let coverageRadiusMeters: CLLocationDistance = 2_500_000

    private var pollingTask: Task<Void, Never>?
    private var statusTask: Task<Void, Never>?
    private var isRefreshing = false

    var captureableCount: Int {
        satellites.count
    }

    func startPolling() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            await self?.pollingLoop()
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func dismissStatusSheet() {
        selectedSatellite = nil
        selectedStatus = nil
        statusErrorMessage = nil
        isLoadingStatus = false
        statusTask?.cancel()
        statusTask = nil
    }

    func selectSatellite(_ satellite: SatellitePosition) {
        selectedSatellite = satellite
        selectedStatus = nil
        statusErrorMessage = nil
        isLoadingStatus = true

        statusTask?.cancel()
        statusTask = Task { [weak self] in
            await self?.loadStatus(for: satellite)
        }
    }

    private func pollingLoop() async {
        await refreshPositions(showLoading: true)

        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await refreshPositions(showLoading: false)
        }
    }

    private func refreshPositions(showLoading: Bool) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        if showLoading { isLoading = true }

        defer {
            isRefreshing = false
            if showLoading { isLoading = false }
        }

        do {
            let response = try await APIService.shared.fetchSatellitePositions(minElevation: 10)
            satellites = merge(existing: satellites, incoming: response.satellites)
            errorMessage = nil
        } catch {
            if satellites.isEmpty {
                errorMessage = "Nao foi possivel carregar o mapa satelital agora."
            } else {
                errorMessage = "Falha temporaria ao atualizar. Mostrando ultima posicao recebida."
            }
        }
    }

    private func merge(existing: [SatellitePosition], incoming: [SatellitePosition]) -> [SatellitePosition] {
        var byId: [String: SatellitePosition] = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        
        // Ensure incoming is unique by id before merging
        var uniqueIncoming: [String: SatellitePosition] = [:]
        for sat in incoming {
            uniqueIncoming[sat.id] = sat
        }
        
        let sortedIncoming = uniqueIncoming.values.sorted { lhs, rhs in
            if lhs.category != rhs.category {
                return lhs.category.sortOrder < rhs.category.sortOrder
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        var merged: [SatellitePosition] = []
        merged.reserveCapacity(sortedIncoming.count)

        for sat in sortedIncoming {
            if let old = byId.removeValue(forKey: sat.id), old == sat {
                merged.append(old)
            } else {
                merged.append(sat)
            }
        }

        return merged
    }

    private func loadStatus(for satellite: SatellitePosition) async {
        do {
            let status: SatelliteStatusResponse
            if let norad = satellite.norad {
                status = try await APIService.shared.fetchSatelliteStatus(norad: norad)
            } else {
                status = try await APIService.shared.fetchSatelliteStatus(name: satellite.name)
            }

            if Task.isCancelled { return }
            selectedStatus = status
            statusErrorMessage = nil
            isLoadingStatus = false
        } catch {
            if Task.isCancelled { return }
            statusErrorMessage = "Nao foi possivel carregar os detalhes deste satelite."
            isLoadingStatus = false
        }
    }
}

struct SatelliteCoverageMapView: View {
    @ObservedObject var viewModel: SatelliteMapViewModel
    @State private var position: MapCameraPosition
    @State private var selectedSatelliteID: String?
    @State private var is3D = true

    init(viewModel: SatelliteMapViewModel) {
        self.viewModel = viewModel
        let region = MKCoordinateRegion(
            center: viewModel.stationCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 45, longitudeDelta: 45)
        )
        _position = State(initialValue: .region(region))
    }

    var body: some View {
        Map(position: $position, interactionModes: .all, selection: $selectedSatelliteID) {
            MapPolyline(coordinates: coverageRingCoordinates)
                .stroke(.cyan.opacity(0.45), lineWidth: 2)

            Annotation("Estação Franca", coordinate: viewModel.stationCoordinate) {
                ZStack {
                    Circle()
                        .fill(.blue.opacity(0.25))
                        .frame(width: 34, height: 34)
                    Circle()
                        .fill(.blue)
                        .frame(width: 12, height: 12)
                    Circle()
                        .stroke(.white, lineWidth: 2)
                        .frame(width: 12, height: 12)
                }
            }

            ForEach(viewModel.satellites) { satellite in
                Annotation("", coordinate: satellite.coordinate) {
                    Button {
                        selectedSatelliteID = satellite.id
                        viewModel.selectSatellite(satellite)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: satellite.category.iconName)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(satellite.category.mapColor)
                                .shadow(color: .black, radius: 1, x: 1, y: 1)

                            Text(satellite.name)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.black.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .tag(satellite.id)
            }
        }
        .mapStyle(.hybrid(elevation: is3D ? .realistic : .flat))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .overlay(alignment: .topTrailing) {
            VStack(spacing: 8) {
                Button {
                    is3D.toggle()
                } label: {
                    Text(is3D ? "3D" : "2D")
                        .font(.caption.bold())
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button {
                    zoom(by: 0.65)
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button {
                    zoom(by: 1.45)
                } label: {
                    Image(systemName: "minus")
                        .font(.headline)
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(10)
        }
        .onChange(of: selectedSatelliteID) { _, newID in
            guard let newID,
                  let sat = viewModel.satellites.first(where: { $0.id == newID }) else { return }
            viewModel.selectSatellite(sat)
        }
    }

    private var coverageRingCoordinates: [CLLocationCoordinate2D] {
        ringCoordinates(
            center: viewModel.stationCoordinate,
            radiusMeters: viewModel.coverageRadiusMeters,
            points: 180
        )
    }

    // Approximates a geodesic ring with line segments. This avoids polygon/circle fill artifacts.
    private func ringCoordinates(center: CLLocationCoordinate2D, radiusMeters: CLLocationDistance, points: Int) -> [CLLocationCoordinate2D] {
        let earthRadius = 6_371_000.0
        let lat1 = center.latitude * .pi / 180
        let lon1 = center.longitude * .pi / 180
        let angularDistance = radiusMeters / earthRadius

        var coordinates: [CLLocationCoordinate2D] = []
        coordinates.reserveCapacity(points + 1)

        for i in 0...points {
            let bearing = (Double(i) / Double(points)) * 2 * .pi
            let lat2 = asin(
                sin(lat1) * cos(angularDistance) +
                cos(lat1) * sin(angularDistance) * cos(bearing)
            )

            let lon2 = lon1 + atan2(
                sin(bearing) * sin(angularDistance) * cos(lat1),
                cos(angularDistance) - sin(lat1) * sin(lat2)
            )

            coordinates.append(
                CLLocationCoordinate2D(
                    latitude: lat2 * 180 / .pi,
                    longitude: lon2 * 180 / .pi
                )
            )
        }

        return coordinates
    }

    private func zoom(by factor: Double) {
        let fallback = MKCoordinateRegion(
            center: viewModel.stationCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 45, longitudeDelta: 45)
        )
        let currentRegion = position.region ?? fallback
        var span = currentRegion.span
        span.latitudeDelta = max(0.05, min(160, span.latitudeDelta * factor))
        span.longitudeDelta = max(0.05, min(160, span.longitudeDelta * factor))
        let updated = MKCoordinateRegion(center: currentRegion.center, span: span)
        position = .region(updated)
    }
}

struct SatelliteStatusSheetView: View {
    let satellite: SatellitePosition
    @ObservedObject var viewModel: SatelliteMapViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.isLoadingStatus {
                        ProgressView("Carregando detalhes...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 50)
                    } else if let error = viewModel.statusErrorMessage {
                        ContentUnavailableView("Erro de Carregamento", systemImage: "exclamationmark.triangle", description: Text(error))
                    } else {
                        // Header
                        headerView
                        
                        // Key Stats Grid
                        statsGrid
                        
                        // Detailed List
                        detailedInfoList
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(satellite.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") {
                        viewModel.dismissStatusSheet()
                        dismiss()
                    }
                }
            }
        }
    }

    private var headerView: some View {
        let status = viewModel.selectedStatus
        let category = status?.category ?? satellite.category
        
        return VStack(spacing: 8) {
            Image(systemName: category.iconName)
                .font(.system(size: 48))
                .foregroundStyle(category.mapColor)
                .padding()
                .background(category.mapColor.opacity(0.1))
                .clipShape(Circle())
            
            Text(status?.name ?? satellite.name)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            
            Text(category.rawValue)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(.tertiarySystemFill))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    private var statsGrid: some View {
        let status = viewModel.selectedStatus
        
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            SatStatCard(icon: "location.fill", value: formatDouble(status?.lat ?? satellite.lat), label: "Latitude", color: .blue)
            SatStatCard(icon: "location.fill", value: formatDouble(status?.lon ?? satellite.lon), label: "Longitude", color: .blue)
            SatStatCard(icon: "arrow.up.left.and.arrow.down.right", value: formatDouble(status?.altKm ?? satellite.altKm, suffix: " km"), label: "Altitude", color: .orange)
            SatStatCard(icon: "speedometer", value: formatDouble(status?.speedKmS ?? 0, suffix: " km/s"), label: "Velocidade", color: .green)
        }
    }
    
    private var detailedInfoList: some View {
        let status = viewModel.selectedStatus
        
        return VStack(spacing: 0) {
            SatDetailRow(title: "NORAD", value: status?.norad.map(String.init) ?? satellite.norad.map(String.init) ?? "-")
            Divider()
            SatDetailRow(title: "Elevação", value: formatDouble(status?.elevation ?? satellite.elevation, suffix: "°"))
            Divider()
            SatDetailRow(title: "Azimute", value: formatDouble(status?.azimuth ?? satellite.azimuth, suffix: "°"))
            Divider()
            SatDetailRow(title: "Período Orbital", value: status?.orbitPeriodMin.map { formatDouble($0, suffix: " min") } ?? "-")
            Divider()
            SatDetailRow(title: "Mean Motion", value: status?.meanMotionRevPerDay.map { formatDouble($0, suffix: " rev/day") } ?? "-")
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    private func formatDouble(_ value: Double, suffix: String = "") -> String {
        String(format: "%.2f%@", value, suffix)
    }
}

struct SatStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct SatDetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .padding()
    }
}

private extension SatellitePosition {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

private extension SatelliteCategory {
    var iconName: String {
        switch self {
        case .meteor: return "satellite.fill"
        case .orbcomm: return "antenna.radiowaves.left.and.right"
        case .unknown: return "satellite.fill"
        }
    }

    var mapColor: Color {
        switch self {
        case .meteor: return .cyan
        case .orbcomm: return .orange
        case .unknown: return .gray
        }
    }

    var sortOrder: Int {
        switch self {
        case .meteor: return 0
        case .orbcomm: return 1
        case .unknown: return 2
        }
    }
}

#Preview {
    SatelliteView()
        .environmentObject(AppState())
}

// MARK: - Fullscreen Map View

struct SatelliteFullscreenMapView: View {
    @ObservedObject var viewModel: SatelliteMapViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            SatelliteCoverageMapView(viewModel: viewModel)
                .ignoresSafeArea()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.8), .black.opacity(0.6))
                    .padding(20)
            }
            .buttonStyle(.plain)
        }
    }
}
