import CoreLocation
import ImageIO
import MapKit
import Photos
import SceneKit
import SwiftUI
import UIKit

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
    @StateObject private var gpsGlobeVM = GPSGlobeViewModel()
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
    @State private var isGPSGlobeFullscreen = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    GlassSection(spacing: 20) {
                        if let status = appState.satDumpStatus {
                            satDumpStatusSection(status)
                        }

                        gpsGlobeSection

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
                            Label(
                                showAllPasses ? "Últimos Passes" : "Todos os Passes",
                                systemImage: "list.bullet.rectangle.portrait")
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
                gpsGlobeVM.startPolling()
            }
            .onDisappear {
                satelliteMapVM.stopPolling()
                gpsGlobeVM.stopPolling()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    satelliteMapVM.startPolling()
                    gpsGlobeVM.startPolling()
                } else {
                    satelliteMapVM.stopPolling()
                    gpsGlobeVM.stopPolling()
                }
            }
            .onChange(of: appState.intelligenceContext) { _, context in
                guard
                    let context,
                    context["kind"] == "satellite_pass",
                    context["tab"] == ContentView.Tab.satellite.rawValue,
                    let identifier = context["identifier"]
                else { return }

                if let pass = appState.passes.first(where: { $0.id == identifier }) {
                    selectedPass = pass
                    appState.intelligenceContext = nil
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
            .fullScreenCover(isPresented: $isGPSGlobeFullscreen) {
                GPSGlobeFullscreenView(
                    viewModel: gpsGlobeVM,
                    satelliteMapViewModel: satelliteMapVM
                )
            }
            .sheet(isPresented: $showAllPasses) {
                AllPassesView()
            }
            .sheet(isPresented: $showPassPredictions) {
                PassPredictionsSheet(predictor: passPredictor)
            }
        }
    }

    private var gpsGlobeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("GPS Globe", systemImage: "globe.americas.fill")
                    .font(.headline)

                Spacer()

                if let state = gpsGlobeVM.state {
                    let used = state.sky.gpsUsed ?? state.sky.usedSatellites ?? 0
                    let visible = state.sky.gpsVisible ?? state.sky.nSatellites ?? 0
                    Text("GPS \(used)/\(visible)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Button {
                    isGPSGlobeFullscreen = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption.bold())
                }
                .buttonStyle(.plain)
                .disabled(gpsGlobeVM.state == nil)
            }

            if let state = gpsGlobeVM.state {
                GPSGlobePanel(
                    state: state,
                    statusMessage: gpsGlobeVM.statusMessage,
                    satelliteMapViewModel: satelliteMapVM
                )
            } else if gpsGlobeVM.isLoading {
                LoadingCard()
            } else if let error = gpsGlobeVM.errorMessage {
                ErrorCard(message: error)
            }
        }
        .padding()
        .glassCard(cornerRadius: 12)
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
            .glassCard(cornerRadius: 12)

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
                .glassCard(cornerRadius: 8)
        }
        .padding()
        .glassCard(cornerRadius: 12)
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
        .glassCard(cornerRadius: 12)
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
                let images = try await APIService.shared.fetchPassImagesLossless(
                    passName: pass.name)
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
            .materialCard(cornerRadius: 0)
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
        let options: CFDictionary =
            [
                kCGImageSourceShouldCache: false
            ] as CFDictionary

        guard let source = CGImageSourceCreateWithData(cfData, options) else {
            return UIImage(data: data)
        }

        let thumbnailOptions: CFDictionary =
            [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
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
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
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
            .glassCard(cornerRadius: 8)
        }
        .padding(12)
        .glassCard(cornerRadius: 12)
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
                        let url = URL(string: urlStr)
                    {
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
                        .glassCard(cornerRadius: 12)
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
                        .glassCard(cornerRadius: 12)
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
        .glassCard(cornerRadius: 16)
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

                            LazyVGrid(
                                columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12
                            ) {
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
            .materialCard(cornerRadius: 8)
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
                    .scrollContentBackground(.hidden)
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
                let images = try await APIService.shared.fetchPassImagesLossless(
                    passName: pass.name)
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
                let result = try await APIService.shared.fetchAllPasses(
                    page: currentPage + 1, limit: 50)
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
        .materialCard(cornerRadius: 12)
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
            .scrollContentBackground(.hidden)
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
                    let str = String(data: data, encoding: .utf8)
                else {
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
        .searchable(
            text: $searchText, prompt: section == .jsonl ? "Buscar eventos..." : "Buscar logs..."
        )
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
            let prettyData = try? JSONSerialization.data(
                withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
            let str = String(data: prettyData, encoding: .utf8)
        else {
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
        let v = (dopplerHz / centerFrequencyHz) * c  // m/s
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
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        let satName = obj["sat_name"] as? String
        let ts = obj["timestamp"] as? String
        let tsDate =
            Formatters.isoDateNoFrac.date(from: ts ?? "") ?? Formatters.isoDate.date(from: ts ?? "")

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

    private static func pickCenterFrequencyHz(obj: [String: Any], satName: String?) -> (
        Double, String
    ) {
        func toHz(_ any: Any?) -> Double? {
            if let n = any as? NSNumber { return n.doubleValue }
            if let d = any as? Double { return d }
            if let i = any as? Int { return Double(i) }
            if let s = any as? String,
                let v = Double(s.trimmingCharacters(in: .whitespacesAndNewlines))
            {
                return v
            }
            return nil
        }

        // Common keys we might add on the backend in the future.
        let keys = [
            "frequency_hz", "freq_hz", "center_hz", "center_frequency_hz",
            "frequency", "freq",
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
        let dirs = [
            "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW",
            "NW", "NNW",
        ]
        let d = (degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(
            dividingBy: 360)
        let idx = Int((d / 22.5).rounded()) % dirs.count
        return dirs[idx]
    }
}

private struct OrbcommTrend {
    let deltaHz: Double
    let deltaSeconds: Double

    var text: String {
        let arrow =
            deltaHz > 0 ? "Doppler subindo" : (deltaHz < 0 ? "Doppler caindo" : "Doppler estavel")
        return String(format: "%@ (Δ %.0f Hz / %.1f s)", arrow, deltaHz, deltaSeconds)
    }

    static func compute(current: OrbcommInterpreted?, previousLine: String?) -> OrbcommTrend? {
        guard let current,
            let prevLine = previousLine,
            let prev = OrbcommInterpreted.parse(jsonLine: prevLine)
        else {
            return nil
        }
        // Only compare same satellite name if present.
        if let a = current.satName?.lowercased(), let b = prev.satName?.lowercased(), !a.isEmpty,
            !b.isEmpty, a != b
        {
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
final class GPSGlobeViewModel: ObservableObject {
    @Published private(set) var state: GPSGlobeState?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private var pollingTask: Task<Void, Never>?
    private var isRefreshing = false

    var statusMessage: String? {
        if let gpsdError = state?.gpsd.error, !gpsdError.isEmpty {
            return "GPSD: \(gpsdError)"
        }
        return errorMessage
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

    private func pollingLoop() async {
        await refresh(showLoading: true)

        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await refresh(showLoading: false)
        }
    }

    private func refresh(showLoading: Bool) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        if showLoading { isLoading = true }

        defer {
            isRefreshing = false
            if showLoading { isLoading = false }
        }

        do {
            let response = try await APIService.shared.fetchGPSGlobeState()
            state = response
            errorMessage = nil
        } catch {
            if state == nil {
                errorMessage = "Nao foi possivel conectar ao GPS Globe agora."
            } else {
                errorMessage = "Falha temporaria ao atualizar. Mostrando a ultima leitura valida."
            }
        }
    }
}

@MainActor
final class GPSGlobeSceneController: ObservableObject {
    let scene = SCNScene()

    private struct GlobeTextureSet {
        let earth: UIImage
        let bump: UIImage?
        let starfield: UIImage?
    }

    private static let receiverUIColor = UIColor(
        red: 86 / 255, green: 225 / 255, blue: 216 / 255, alpha: 1)
    private static let satelliteUIColor = UIColor(
        red: 1, green: 184 / 255, blue: 92 / 255, alpha: 1)
    private static let nadirUIColor = UIColor(red: 1, green: 220 / 255, blue: 165 / 255, alpha: 1)
    private static let selectionUIColor = UIColor(
        red: 110 / 255, green: 197 / 255, blue: 1, alpha: 1)
    private static let earthTextureURL = URL(
        string: "https://cdn.jsdelivr.net/npm/three-globe/example/img/earth-blue-marble.jpg")!
    private static let earthBumpURL = URL(
        string: "https://cdn.jsdelivr.net/npm/three-globe/example/img/earth-topology.png")!
    private static let starfieldURL = URL(
        string: "https://cdn.jsdelivr.net/npm/three-globe/example/img/night-sky.png")!
    private static var cachedTextures: GlobeTextureSet?
    private static var isLoadingTextures = false
    private static let textureCacheDirectoryName = "gps-globe-textures"

    private let globeRoot = SCNNode()
    private let earthNode = SCNNode()
    private let gridNode = SCNNode()
    private let connectionNode = SCNNode()
    private let receiverNode = SCNNode()
    private let receiverGlowNode = SCNNode()
    private let nadirNode = SCNNode()
    private var satelliteNodes: [Int: SCNNode] = [:]
    private var connectionNodes: [Int: SCNNode] = [:]
    private var nadirNodes: [Int: SCNNode] = [:]
    private var earthMaterial = SCNMaterial()
    private var selectedPRN: Int?

    init() {
        setupScene()
        Task { await loadReferenceTexturesIfNeeded() }
    }

    func update(with state: GPSGlobeState, selectedPRN: Int?) {
        self.selectedPRN = selectedPRN

        let receiverPosition = cartesian(
            lat: state.receiver.lat,
            lon: state.receiver.lon,
            radius: 1.03
        )
        receiverNode.position = receiverPosition
        receiverGlowNode.position = receiverPosition

        let validSatellites = state.satellitesVisible.filter { $0.subpoint != nil }
        let validIDs = Set(validSatellites.map(\.prn))

        for (prn, node) in satelliteNodes where !validIDs.contains(prn) {
            node.removeFromParentNode()
            satelliteNodes.removeValue(forKey: prn)
        }

        for (prn, node) in connectionNodes where !validIDs.contains(prn) {
            node.removeFromParentNode()
            connectionNodes.removeValue(forKey: prn)
        }

        for (prn, node) in nadirNodes where !validIDs.contains(prn) {
            node.removeFromParentNode()
            nadirNodes.removeValue(forKey: prn)
        }

        for satellite in validSatellites {
            guard let subpoint = satellite.subpoint else { continue }

            let orbitRadius = compressedOrbitRadius(for: subpoint.altitudeKM)
            let satellitePosition = cartesian(
                lat: subpoint.lat, lon: subpoint.lon, radius: orbitRadius)
            let subpointPosition = cartesian(lat: subpoint.lat, lon: subpoint.lon, radius: 1.015)
            let isSelected = satellite.prn == selectedPRN

            let satelliteNode: SCNNode
            if let existing = satelliteNodes[satellite.prn] {
                satelliteNode = existing
            } else {
                satelliteNode = makeSatelliteNode(for: satellite)
                globeRoot.addChildNode(satelliteNode)
                satelliteNodes[satellite.prn] = satelliteNode
            }

            styleSatelliteNode(satelliteNode, satellite: satellite, selected: isSelected)
            satelliteNode.position = satellitePosition

            let nadirMarker: SCNNode
            if let existing = nadirNodes[satellite.prn] {
                nadirMarker = existing
            } else {
                nadirMarker = makeNadirNode()
                nadirMarker.name = "nadir-\(satellite.prn)"
                nadirNode.addChildNode(nadirMarker)
                nadirNodes[satellite.prn] = nadirMarker
            }

            styleNadirNode(nadirMarker, selected: isSelected)
            nadirMarker.position = subpointPosition

            let connection: SCNNode
            if let existing = connectionNodes[satellite.prn] {
                connection = existing
            } else {
                connection = SCNNode()
                connectionNode.addChildNode(connection)
                connectionNodes[satellite.prn] = connection
            }

            connection.geometry = makeConnectionGeometry(
                from: receiverPosition,
                to: satellitePosition,
                emphasized: satellite.used || isSelected
            )
        }
    }

    private func setupScene() {
        scene.background.contents = UIColor(red: 0.01, green: 0.02, blue: 0.06, alpha: 1)
        scene.rootNode.addChildNode(globeRoot)
        scene.rootNode.addChildNode(connectionNode)
        globeRoot.addChildNode(nadirNode)

        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 50
        camera.position = SCNVector3(0, 0, 7.5)
        scene.rootNode.addChildNode(camera)

        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = UIColor.white.withAlphaComponent(0.55)
        scene.rootNode.addChildNode(ambientLight)

        let sunLight = SCNNode()
        sunLight.light = SCNLight()
        sunLight.light?.type = .omni
        sunLight.light?.intensity = 1_200
        sunLight.position = SCNVector3(5, 3, 8)
        scene.rootNode.addChildNode(sunLight)

        let earth = SCNSphere(radius: 1.0)
        earth.segmentCount = 64
        earthMaterial = makeFallbackEarthMaterial()
        earth.firstMaterial = earthMaterial
        earthNode.geometry = earth
        globeRoot.addChildNode(earthNode)

        buildGrid()
        globeRoot.addChildNode(gridNode)

        let atmosphere = SCNSphere(radius: 1.05)
        atmosphere.firstMaterial?.diffuse.contents = Self.receiverUIColor.withAlphaComponent(0.06)
        atmosphere.firstMaterial?.emission.contents = Self.receiverUIColor.withAlphaComponent(0.18)
        atmosphere.firstMaterial?.transparency = 0.35
        let atmosphereNode = SCNNode(geometry: atmosphere)
        globeRoot.addChildNode(atmosphereNode)

        let receiver = SCNSphere(radius: 0.05)
        receiver.firstMaterial?.lightingModel = .physicallyBased
        receiver.firstMaterial?.diffuse.contents = Self.receiverUIColor
        receiver.firstMaterial?.emission.contents = Self.receiverUIColor.withAlphaComponent(0.55)
        receiverNode.geometry = receiver
        globeRoot.addChildNode(receiverNode)

        let receiverHalo = SCNPlane(width: 0.22, height: 0.22)
        receiverHalo.firstMaterial?.diffuse.contents = Self.receiverUIColor.withAlphaComponent(0.22)
        receiverHalo.firstMaterial?.emission.contents = Self.receiverUIColor.withAlphaComponent(
            0.42)
        receiverHalo.firstMaterial?.isDoubleSided = true
        receiverHalo.firstMaterial?.lightingModel = .constant
        receiverHalo.firstMaterial?.blendMode = .add
        receiverGlowNode.geometry = receiverHalo
        receiverGlowNode.constraints = [SCNBillboardConstraint()]
        globeRoot.addChildNode(receiverGlowNode)

        let receiverIcon = makeMarkerNode(
            image: receiverMarkerImage(size: CGSize(width: 160, height: 160)),
            size: CGSize(width: 0.2, height: 0.2)
        )
        receiverIcon.name = "icon"
        receiverIcon.position = SCNVector3(0, 0.11, 0)
        receiverIcon.constraints = [SCNBillboardConstraint()]
        receiverNode.addChildNode(receiverIcon)

        let rotation = SCNAction.repeatForever(
            .rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 60))
        globeRoot.runAction(rotation)
    }

    private func loadReferenceTexturesIfNeeded() async {
        if let cached = Self.cachedTextures {
            applyTextures(cached)
            return
        }

        guard !Self.isLoadingTextures else { return }
        Self.isLoadingTextures = true
        defer { Self.isLoadingTextures = false }

        async let earth = loadImage(from: Self.earthTextureURL)
        async let bump = loadImage(from: Self.earthBumpURL)
        async let starfield = loadImage(from: Self.starfieldURL)

        guard let earthImage = await earth else { return }
        let textures = GlobeTextureSet(
            earth: earthImage,
            bump: await bump,
            starfield: await starfield
        )
        Self.cachedTextures = textures
        applyTextures(textures)
    }

    private func loadImage(from url: URL) async -> UIImage? {
        if let cachedData = await Self.cachedTextureData(for: url) {
            return UIImage(data: cachedData)
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode)
            else {
                return nil
            }
            await Self.storeTextureData(data, for: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }

    private static func cachedTextureData(for remoteURL: URL) async -> Data? {
        guard let fileURL = cacheFileURL(for: remoteURL) else { return nil }
        return await Task.detached(priority: .utility) {
            try? Data(contentsOf: fileURL)
        }.value
    }

    private static func storeTextureData(_ data: Data, for remoteURL: URL) async {
        guard let fileURL = cacheFileURL(for: remoteURL) else { return }
        _ = await Task.detached(priority: .utility) {
            let directoryURL = fileURL.deletingLastPathComponent()
            try? FileManager.default.createDirectory(
                at: directoryURL, withIntermediateDirectories: true)
            try? data.write(to: fileURL, options: .atomic)
        }.value
    }

    private static func cacheFileURL(for remoteURL: URL) -> URL? {
        guard
            let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
                .first
        else {
            return nil
        }

        return
            cachesURL
            .appendingPathComponent(textureCacheDirectoryName, isDirectory: true)
            .appendingPathComponent(remoteURL.lastPathComponent)
    }

    private func applyTextures(_ textures: GlobeTextureSet) {
        earthMaterial.diffuse.contents = textures.earth
        earthMaterial.emission.contents = UIColor.black.withAlphaComponent(0.12)
        if let bump = textures.bump {
            earthMaterial.normal.contents = bump
            earthMaterial.normal.intensity = 0.55
        }
        scene.background.contents =
            textures.starfield ?? UIColor(red: 0.01, green: 0.02, blue: 0.06, alpha: 1)
    }

    private func makeFallbackEarthMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = UIColor(red: 0.05, green: 0.14, blue: 0.25, alpha: 1)
        material.emission.contents = UIColor(red: 0.02, green: 0.18, blue: 0.24, alpha: 0.65)
        material.specular.contents = UIColor.white.withAlphaComponent(0.18)
        material.roughness.contents = 0.75
        material.metalness.contents = 0.05
        material.normal.intensity = 0.35

        return material
    }

    private func buildGrid() {
        gridNode.childNodes.forEach { $0.removeFromParentNode() }

        let latitudes: [Double] = [-60, -30, 0, 30, 60]
        for latitude in latitudes {
            let node = makeLatitudeRing(latitude: latitude, radius: 1.002)
            gridNode.addChildNode(node)
        }

        let longitudes = stride(from: 0.0, to: 180.0, by: 30.0)
        for longitude in longitudes {
            let node = makeLongitudeRing(longitude: longitude, radius: 1.002)
            gridNode.addChildNode(node)
        }
    }

    private func makeLatitudeRing(latitude: Double, radius: Double) -> SCNNode {
        let latRad = latitude * .pi / 180
        let ringRadius = cos(latRad) * radius
        let y = sin(latRad) * radius
        let torus = SCNTorus(
            ringRadius: CGFloat(abs(ringRadius)), pipeRadius: latitude == 0 ? 0.0028 : 0.0018)
        torus.firstMaterial?.diffuse.contents =
            latitude == 0
            ? Self.receiverUIColor.withAlphaComponent(0.8) : UIColor.white.withAlphaComponent(0.18)
        torus.firstMaterial?.emission.contents =
            latitude == 0
            ? Self.receiverUIColor.withAlphaComponent(0.3) : UIColor.white.withAlphaComponent(0.05)
        torus.firstMaterial?.lightingModel = .constant
        let node = SCNNode(geometry: torus)
        node.position = SCNVector3(0, y, 0)
        node.eulerAngles.x = .pi / 2
        return node
    }

    private func makeLongitudeRing(longitude: Double, radius: Double) -> SCNNode {
        let torus = SCNTorus(ringRadius: CGFloat(radius), pipeRadius: 0.0016)
        torus.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.14)
        torus.firstMaterial?.emission.contents = Self.receiverUIColor.withAlphaComponent(0.05)
        torus.firstMaterial?.lightingModel = .constant
        let node = SCNNode(geometry: torus)
        node.eulerAngles.y = Float(longitude * .pi / 180)
        return node
    }

    private func makeSatelliteNode(for satellite: GPSGlobeSatellite) -> SCNNode {
        let container = SCNNode()
        container.name = "satellite-\(satellite.prn)"

        let sphere = SCNSphere(radius: satellite.used ? 0.06 : 0.043)
        sphere.firstMaterial?.lightingModel = .physicallyBased
        let core = SCNNode(geometry: sphere)
        core.name = "core"
        container.addChildNode(core)

        let halo = SCNPlane(width: satellite.used ? 0.3 : 0.2, height: satellite.used ? 0.3 : 0.2)
        halo.firstMaterial?.isDoubleSided = true
        halo.firstMaterial?.lightingModel = .constant
        halo.firstMaterial?.blendMode = .add
        let haloNode = SCNNode(geometry: halo)
        haloNode.name = "halo"
        haloNode.constraints = [SCNBillboardConstraint()]
        container.addChildNode(haloNode)

        let ring = SCNTorus(ringRadius: 0.11, pipeRadius: 0.004)
        ring.firstMaterial?.lightingModel = .constant
        let ringNode = SCNNode(geometry: ring)
        ringNode.name = "ring"
        ringNode.constraints = [SCNBillboardConstraint()]
        let pulse = SCNAction.repeatForever(
            .sequence([
                .group([.scale(to: 1.24, duration: 0.9), .fadeOpacity(to: 0.15, duration: 0.9)]),
                .group([.scale(to: 0.92, duration: 0.12), .fadeOpacity(to: 0.9, duration: 0.12)]),
            ])
        )
        ringNode.runAction(pulse)
        container.addChildNode(ringNode)

        let selectionRing = SCNTorus(ringRadius: 0.15, pipeRadius: 0.005)
        selectionRing.firstMaterial?.lightingModel = .constant
        let selectionNode = SCNNode(geometry: selectionRing)
        selectionNode.name = "selection"
        selectionNode.constraints = [SCNBillboardConstraint()]
        container.addChildNode(selectionNode)

        let icon = makeMarkerNode(
            image: satelliteMarkerImage(
                tint: satellite.used
                    ? Self.satelliteUIColor : UIColor.white.withAlphaComponent(0.92),
                highlight: satellite.used,
                size: CGSize(width: 220, height: 180)
            ),
            size: CGSize(width: 0.24, height: 0.2)
        )
        icon.name = "icon"
        icon.position = SCNVector3(0, 0.12, 0)
        icon.constraints = [SCNBillboardConstraint()]
        container.addChildNode(icon)

        styleSatelliteNode(container, satellite: satellite, selected: satellite.prn == selectedPRN)
        return container
    }

    private func styleSatelliteNode(_ node: SCNNode, satellite: GPSGlobeSatellite, selected: Bool) {
        let used = satellite.used

        if let core = node.childNode(withName: "core", recursively: false),
            let sphere = core.geometry as? SCNSphere
        {
            sphere.radius = selected ? 0.075 : (used ? 0.06 : 0.043)
            sphere.firstMaterial?.diffuse.contents = Self.satelliteUIColor
            sphere.firstMaterial?.emission.contents =
                (selected ? Self.selectionUIColor : Self.satelliteUIColor).withAlphaComponent(
                    selected ? 0.5 : (used ? 0.42 : 0.18))
        }

        if let halo = node.childNode(withName: "halo", recursively: false),
            let plane = halo.geometry as? SCNPlane
        {
            plane.width = selected ? 0.38 : (used ? 0.3 : 0.2)
            plane.height = selected ? 0.38 : (used ? 0.3 : 0.2)
            plane.firstMaterial?.diffuse.contents =
                (selected ? Self.selectionUIColor : Self.satelliteUIColor).withAlphaComponent(
                    selected ? 0.22 : (used ? 0.16 : 0.1))
            plane.firstMaterial?.emission.contents =
                (selected ? Self.selectionUIColor : Self.satelliteUIColor).withAlphaComponent(
                    selected ? 0.58 : (used ? 0.28 : 0.14))
        }

        if let ringNode = node.childNode(withName: "ring", recursively: false),
            let ring = ringNode.geometry as? SCNTorus
        {
            ringNode.isHidden = !used
            ring.ringRadius = selected ? 0.14 : 0.11
            ring.firstMaterial?.diffuse.contents = Self.satelliteUIColor.withAlphaComponent(0.9)
            ring.firstMaterial?.emission.contents = Self.satelliteUIColor.withAlphaComponent(0.45)
        }

        if let selectionNode = node.childNode(withName: "selection", recursively: false),
            let ring = selectionNode.geometry as? SCNTorus
        {
            selectionNode.isHidden = !selected
            ring.firstMaterial?.diffuse.contents = Self.selectionUIColor.withAlphaComponent(0.85)
            ring.firstMaterial?.emission.contents = Self.selectionUIColor.withAlphaComponent(0.55)
        }

        if let iconNode = node.childNode(withName: "icon", recursively: false),
            let plane = iconNode.geometry as? SCNPlane
        {
            plane.width = selected ? 0.29 : 0.24
            plane.height = selected ? 0.24 : 0.2
            plane.firstMaterial?.diffuse.contents = satelliteMarkerImage(
                tint: selected
                    ? Self.selectionUIColor
                    : (used ? Self.satelliteUIColor : UIColor.white.withAlphaComponent(0.92)),
                highlight: used || selected,
                size: CGSize(width: 240, height: 196)
            )
            plane.firstMaterial?.emission.contents =
                (selected ? Self.selectionUIColor : Self.satelliteUIColor).withAlphaComponent(
                    selected ? 0.24 : 0.12)
        }
    }

    private func makeNadirNode() -> SCNNode {
        let container = SCNNode()

        let point = SCNSphere(radius: 0.021)
        point.firstMaterial?.lightingModel = .physicallyBased
        let pointNode = SCNNode(geometry: point)
        pointNode.name = "point"
        container.addChildNode(pointNode)

        let ring = SCNPlane(width: 0.12, height: 0.12)
        ring.firstMaterial?.isDoubleSided = true
        ring.firstMaterial?.lightingModel = .constant
        ring.firstMaterial?.blendMode = .add
        let ringNode = SCNNode(geometry: ring)
        ringNode.name = "ring"
        ringNode.constraints = [SCNBillboardConstraint()]
        container.addChildNode(ringNode)

        return container
    }

    private func styleNadirNode(_ node: SCNNode, selected: Bool) {
        if let pointNode = node.childNode(withName: "point", recursively: false),
            let point = pointNode.geometry as? SCNSphere
        {
            point.radius = selected ? 0.028 : 0.021
            point.firstMaterial?.diffuse.contents = Self.nadirUIColor
            point.firstMaterial?.emission.contents =
                (selected ? Self.selectionUIColor : Self.nadirUIColor).withAlphaComponent(
                    selected ? 0.45 : 0.24)
        }

        if let ringNode = node.childNode(withName: "ring", recursively: false),
            let ring = ringNode.geometry as? SCNPlane
        {
            ring.width = selected ? 0.16 : 0.12
            ring.height = selected ? 0.16 : 0.12
            ring.firstMaterial?.diffuse.contents = Self.nadirUIColor.withAlphaComponent(
                selected ? 0.22 : 0.12)
            ring.firstMaterial?.emission.contents =
                (selected ? Self.selectionUIColor : Self.nadirUIColor).withAlphaComponent(
                    selected ? 0.35 : 0.16)
        }
    }

    private func makeConnectionGeometry(from: SCNVector3, to: SCNVector3, emphasized: Bool)
        -> SCNGeometry
    {
        let vertices = [from, to]
        let source = SCNGeometrySource(vertices: vertices)
        let element = SCNGeometryElement(indices: [0, 1], primitiveType: .line)
        let geometry = SCNGeometry(sources: [source], elements: [element])
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents =
            emphasized
            ? Self.satelliteUIColor.withAlphaComponent(0.82)
            : Self.receiverUIColor.withAlphaComponent(0.16)
        material.emission.contents =
            emphasized
            ? Self.satelliteUIColor.withAlphaComponent(0.32)
            : Self.receiverUIColor.withAlphaComponent(0.08)
        geometry.materials = [material]
        return geometry
    }

    func satellitePRN(at point: CGPoint, in view: SCNView) -> Int? {
        let hitNodes = view.hitTest(
            point,
            options: [
                SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue,
                SCNHitTestOption.boundingBoxOnly: false,
            ])

        for result in hitNodes {
            var node: SCNNode? = result.node
            while let current = node {
                if let name = current.name,
                    let prn = parsePRN(from: name)
                {
                    return prn
                }
                node = current.parent
            }
        }

        return nil
    }

    private func makeMarkerNode(image: UIImage?, size: CGSize) -> SCNNode {
        let plane = SCNPlane(width: size.width, height: size.height)
        plane.firstMaterial = SCNMaterial()
        plane.firstMaterial?.lightingModel = .constant
        plane.firstMaterial?.diffuse.contents = image
        plane.firstMaterial?.isDoubleSided = true
        plane.firstMaterial?.transparent.contents = image
        let node = SCNNode(geometry: plane)
        return node
    }

    private func receiverMarkerImage(size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cg = context.cgContext
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            cg.setStrokeColor(Self.receiverUIColor.withAlphaComponent(0.28).cgColor)
            cg.setLineWidth(10)
            cg.addEllipse(in: CGRect(x: center.x - 34, y: center.y - 34, width: 68, height: 68))
            cg.strokePath()

            cg.setFillColor(Self.receiverUIColor.cgColor)
            let diamond = UIBezierPath()
            diamond.move(to: CGPoint(x: center.x, y: center.y - 28))
            diamond.addLine(to: CGPoint(x: center.x + 24, y: center.y))
            diamond.addLine(to: CGPoint(x: center.x, y: center.y + 28))
            diamond.addLine(to: CGPoint(x: center.x - 24, y: center.y))
            diamond.close()
            diamond.fill()

            cg.setFillColor(UIColor.white.withAlphaComponent(0.92).cgColor)
            cg.fillEllipse(in: CGRect(x: center.x - 10, y: center.y - 10, width: 20, height: 20))
        }
    }

    private func satelliteMarkerImage(tint: UIColor, highlight: Bool, size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cg = context.cgContext
            let bodyRect = CGRect(x: 74, y: 58, width: 72, height: 52)
            let panelColor = tint.withAlphaComponent(highlight ? 0.95 : 0.82)
            let bodyColor = UIColor(white: 0.96, alpha: 0.98)

            cg.setShadow(
                offset: .zero, blur: 14,
                color: tint.withAlphaComponent(highlight ? 0.45 : 0.18).cgColor)

            let leftPanel = UIBezierPath(
                roundedRect: CGRect(x: 18, y: 52, width: 50, height: 32), cornerRadius: 7)
            panelColor.setFill()
            leftPanel.fill()

            let rightPanel = UIBezierPath(
                roundedRect: CGRect(x: 152, y: 52, width: 50, height: 32), cornerRadius: 7)
            rightPanel.fill()

            cg.setShadow(offset: .zero, blur: 0, color: nil)

            let body = UIBezierPath(roundedRect: bodyRect, cornerRadius: 14)
            bodyColor.setFill()
            body.fill()

            tint.withAlphaComponent(0.2).setStroke()
            body.lineWidth = 2
            body.stroke()

            UIColor(white: 0.65, alpha: 0.9).setStroke()
            let mast = UIBezierPath()
            mast.move(to: CGPoint(x: bodyRect.minX, y: bodyRect.midY))
            mast.addLine(to: CGPoint(x: 68, y: 68))
            mast.move(to: CGPoint(x: bodyRect.maxX, y: bodyRect.midY))
            mast.addLine(to: CGPoint(x: 152, y: 68))
            mast.lineWidth = 5
            mast.lineCapStyle = .round
            mast.stroke()

            tint.setFill()
            UIBezierPath(ovalIn: CGRect(x: 96, y: 118, width: 28, height: 28)).fill()

            let antenna = UIBezierPath()
            antenna.move(to: CGPoint(x: 110, y: 126))
            antenna.addLine(to: CGPoint(x: 110, y: 156))
            antenna.lineWidth = 4
            antenna.lineCapStyle = .round
            UIColor.white.withAlphaComponent(0.85).setStroke()
            antenna.stroke()
        }
    }

    private func cartesian(lat: Double, lon: Double, radius: Double) -> SCNVector3 {
        let latitude = lat * .pi / 180
        let longitude = lon * .pi / 180
        let x = radius * cos(latitude) * sin(longitude)
        let y = radius * sin(latitude)
        let z = radius * cos(latitude) * cos(longitude)
        return SCNVector3(x, y, z)
    }

    private func compressedOrbitRadius(for altitudeKM: Double?) -> Double {
        let altitude = max(0, altitudeKM ?? 20_200)
        let normalized = min(altitude / 22_000.0, 1.0)
        return 1.18 + (normalized * 0.18)
    }

    private func parsePRN(from name: String) -> Int? {
        let separators = ["satellite-", "nadir-"]
        for prefix in separators where name.hasPrefix(prefix) {
            return Int(name.dropFirst(prefix.count))
        }
        return nil
    }
}

struct GPSGlobePanel: View {
    let state: GPSGlobeState
    let statusMessage: String?
    @ObservedObject var satelliteMapViewModel: SatelliteMapViewModel
    var isFullscreen = false

    @State private var selectedSatellitePRN: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: isFullscreen ? 120 : 96), spacing: 10)],
                spacing: 10
            ) {
                GPSMiniMetric(
                    title: "Modo",
                    value: gpsModeText,
                    tint: GPSGlobePalette.receiver
                )
                GPSMiniMetric(
                    title: "HDOP",
                    value: formatted(state.sky.hdop, fallback: "--"),
                    tint: GPSGlobePalette.satellite
                )
                GPSMiniMetric(
                    title: "Precisão",
                    value: receiverAccuracyText,
                    tint: GPSGlobePalette.nadir
                )
            }

            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    UnifiedSatelliteGlobe(
                        state: state,
                        selectedPRN: $selectedSatellitePRN,
                        satelliteMapViewModel: satelliteMapViewModel,
                        isFullscreen: isFullscreen
                    )
                    .frame(height: isFullscreen ? 520 : 400)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Receptor em Franca")
                            .font(.caption.weight(.semibold))
                        Text(receiverCoordinateText)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .glassCard(cornerRadius: 12)
                    .padding(12)

                    if let selectedSatellite {
                        GPSSatelliteTooltipOverlay(
                            satellite: selectedSatellite,
                            onDismiss: { selectedSatellitePRN = nil }
                        )
                        .frame(maxWidth: isFullscreen ? 360 : 320)
                        .padding(12)
                        .frame(
                            maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    if let statusMessage, !statusMessage.isEmpty {
                        Label(statusMessage, systemImage: "info.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(
                        "Globo 3D MapKit com satélites GPS e ORBCOMM/Meteor. Toque para selecionar."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    GPSGlobeLegend()
                }
                .padding(14)
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .onAppear {
            syncSelection(with: state)
        }
        .onChange(of: state) { _, newValue in
            syncSelection(with: newValue)
        }
    }

    private var sortedSatellites: [GPSGlobeSatellite] {
        state.satellitesVisible.sorted { lhs, rhs in
            if lhs.used != rhs.used { return lhs.used && !rhs.used }
            return (lhs.signalDBHz ?? 0) > (rhs.signalDBHz ?? 0)
        }
    }

    private var selectedSatellite: GPSGlobeSatellite? {
        guard let selectedSatellitePRN else { return nil }
        return sortedSatellites.first(where: { $0.prn == selectedSatellitePRN })
    }

    private var gpsModeText: String {
        switch state.receiver.mode {
        case 3: return "3D"
        case 2: return "2D"
        case 1: return "Fix"
        default: return "--"
        }
    }

    private var receiverAccuracyText: String {
        if let horizontalError = state.receiver.horizontalErrorM {
            return "\(horizontalError.formattedBR(decimals: 0)) m"
        }
        return "--"
    }

    private var receiverCoordinateText: String {
        "\(state.receiver.lat.formattedBR(decimals: 4)), \(state.receiver.lon.formattedBR(decimals: 4))"
    }

    private func syncSelection(with state: GPSGlobeState) {
        let availableIDs = Set(state.satellitesVisible.map(\.prn))
        if let selectedSatellitePRN, availableIDs.contains(selectedSatellitePRN) {
            return
        }

        selectedSatellitePRN = nil
    }

    private func formatted(_ value: Double?, fallback: String) -> String {
        guard let value else { return fallback }
        return value.formattedBR(decimals: 2)
    }
}

private enum GPSGlobePalette {
    static let receiver = Color(red: 86 / 255, green: 225 / 255, blue: 216 / 255)
    static let satellite = Color(red: 1, green: 184 / 255, blue: 92 / 255)
    static let nadir = Color(red: 1, green: 220 / 255, blue: 165 / 255)
    static let selection = Color(red: 110 / 255, green: 197 / 255, blue: 1)
}

struct GPSMiniMetric: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassCard(tint: tint, cornerRadius: 12)
    }
}

// MARK: - Unified 3D MapKit Satellite Globe

struct UnifiedSatelliteGlobe: View {
    let state: GPSGlobeState
    @Binding var selectedPRN: Int?
    @ObservedObject var satelliteMapViewModel: SatelliteMapViewModel
    var isFullscreen: Bool = false

    @State private var position: MapCameraPosition
    @State private var userHasMoved = false

    init(
        state: GPSGlobeState, selectedPRN: Binding<Int?>,
        satelliteMapViewModel: SatelliteMapViewModel, isFullscreen: Bool = false
    ) {
        self.state = state
        _selectedPRN = selectedPRN
        _satelliteMapViewModel = ObservedObject(wrappedValue: satelliteMapViewModel)
        self.isFullscreen = isFullscreen
        _position = State(
            initialValue: .camera(
                MapCamera(
                    centerCoordinate: CLLocationCoordinate2D(
                        latitude: state.receiver.lat, longitude: state.receiver.lon),
                    distance: 28_000_000,
                    heading: 0,
                    pitch: 0
                )
            ))
    }

    var body: some View {
        Map(position: $position) {
            // Coverage ring
            MapPolyline(coordinates: coverageRingCoordinates)
                .stroke(.cyan.opacity(0.35), lineWidth: 1.5)

            // Connection lines from receiver to ALL used GPS satellites
            ForEach(usedSatellitesWithSubpoints, id: \.prn) { satellite in
                if let subpoint = satellite.subpoint {
                    let coord = CLLocationCoordinate2D(
                        latitude: subpoint.lat, longitude: subpoint.lon)
                    MapPolyline(coordinates: [receiverCoordinate, coord])
                        .stroke(
                            satellite.prn == selectedPRN
                                ? GPSGlobePalette.selection.opacity(0.7)
                                : GPSGlobePalette.satellite.opacity(0.35),
                            style: StrokeStyle(
                                lineWidth: satellite.prn == selectedPRN ? 2.5 : 1.2,
                                dash: satellite.prn == selectedPRN ? [] : [6, 4]
                            )
                        )
                }
            }

            // Selected non-used satellite connection line
            if let selectedPRN,
                let sat = satellitesWithSubpoints.first(where: { $0.prn == selectedPRN && !$0.used }
                ),
                let sp = sat.subpoint
            {
                MapPolyline(coordinates: [
                    receiverCoordinate, CLLocationCoordinate2D(latitude: sp.lat, longitude: sp.lon),
                ])
                .stroke(GPSGlobePalette.selection.opacity(0.5), lineWidth: 1.5)
            }

            // Receiver annotation
            Annotation("", coordinate: receiverCoordinate) {
                VStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(GPSGlobePalette.receiver.opacity(0.22))
                            .frame(width: 30, height: 30)
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(GPSGlobePalette.receiver)
                            .overlay(
                                Image(systemName: "diamond")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.7))
                            )
                    }
                }
            }

            // GPS satellite subpoints
            ForEach(satellitesWithSubpoints, id: \.prn) { satellite in
                if let subpoint = satellite.subpoint {
                    let coord = CLLocationCoordinate2D(
                        latitude: subpoint.lat, longitude: subpoint.lon)

                    Annotation("", coordinate: coord) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedPRN = satellite.prn
                                userHasMoved = false
                            }
                        } label: {
                            VStack(spacing: 2) {
                                ZStack {
                                    // Pulsing ring for used satellites
                                    if satellite.used {
                                        Circle()
                                            .stroke(
                                                GPSGlobePalette.satellite.opacity(0.4),
                                                lineWidth: 1.5
                                            )
                                            .frame(
                                                width: satellite.prn == selectedPRN ? 34 : 28,
                                                height: satellite.prn == selectedPRN ? 34 : 28
                                            )
                                    }

                                    Image(systemName: "satellite.fill")
                                        .font(
                                            .system(
                                                size: satellite.prn == selectedPRN ? 13 : 10,
                                                weight: .bold)
                                        )
                                        .foregroundStyle(.white)
                                        .frame(
                                            width: satellite.prn == selectedPRN ? 28 : 22,
                                            height: satellite.prn == selectedPRN ? 28 : 22
                                        )
                                        .background(
                                            (satellite.prn == selectedPRN
                                                ? GPSGlobePalette.selection
                                                : (satellite.used
                                                    ? GPSGlobePalette.satellite
                                                    : GPSGlobePalette.nadir.opacity(0.6))),
                                            in: Circle()
                                        )
                                        .overlay(
                                            Circle().stroke(.white.opacity(0.65), lineWidth: 1))
                                }

                                if satellite.prn == selectedPRN || satellite.used {
                                    Text(
                                        satellite.prn == selectedPRN
                                            ? "PRN \(satellite.prn)" : "\(satellite.prn)"
                                    )
                                    .font(
                                        .system(
                                            size: satellite.prn == selectedPRN ? 9 : 8,
                                            weight: .bold, design: .monospaced)
                                    )
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, satellite.prn == selectedPRN ? 6 : 4)
                                    .padding(.vertical, satellite.prn == selectedPRN ? 3 : 2)
                                    .background(
                                        (satellite.prn == selectedPRN
                                            ? Color.black : GPSGlobePalette.satellite).opacity(
                                                0.75),
                                        in: Capsule()
                                    )
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // ORBCOMM/Meteor satellites
            ForEach(satelliteMapViewModel.satellites) { satellite in
                Annotation("", coordinate: satellite.coordinate) {
                    Button {
                        satelliteMapViewModel.selectSatellite(satellite)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: satellite.category.iconName)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(satellite.category.mapColor, in: Circle())
                                .overlay(Circle().stroke(.white.opacity(0.55), lineWidth: 1))

                            if satelliteMapViewModel.selectedSatellite?.id == satellite.id {
                                Text(satellite.name)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.black.opacity(0.72), in: Capsule())
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .mapStyle(.imagery(elevation: .realistic))
        .mapControlVisibility(.hidden)
        .onMapCameraChange { _ in
            userHasMoved = true
        }
        .onChange(of: selectedPRN) { _, newPRN in
            if !userHasMoved {
                animateToSelection(prn: newPRN)
            }
        }
    }

    private var receiverCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: state.receiver.lat, longitude: state.receiver.lon)
    }

    private var satellitesWithSubpoints: [GPSGlobeSatellite] {
        state.satellitesVisible
            .filter { $0.subpoint != nil }
            .sorted { lhs, rhs in
                if lhs.used != rhs.used { return lhs.used && !rhs.used }
                return (lhs.signalDBHz ?? 0) > (rhs.signalDBHz ?? 0)
            }
    }

    private var usedSatellitesWithSubpoints: [GPSGlobeSatellite] {
        satellitesWithSubpoints.filter { $0.used }
    }

    private var coverageRingCoordinates: [CLLocationCoordinate2D] {
        ringCoordinates(
            center: satelliteMapViewModel.stationCoordinate,
            radiusMeters: satelliteMapViewModel.coverageRadiusMeters,
            points: 180
        )
    }

    private func animateToSelection(prn: Int?) {
        guard let prn,
            let satellite = satellitesWithSubpoints.first(where: { $0.prn == prn }),
            let subpoint = satellite.subpoint
        else {
            // Reset to globe view centered on receiver
            withAnimation(.easeInOut(duration: 0.6)) {
                position = .camera(
                    MapCamera(
                        centerCoordinate: receiverCoordinate,
                        distance: 28_000_000,
                        heading: 0,
                        pitch: 0
                    )
                )
            }
            return
        }

        // Center between receiver and selected satellite subpoint
        let centerLat = (state.receiver.lat + subpoint.lat) / 2
        let centerLon = (state.receiver.lon + subpoint.lon) / 2
        let latSpan = abs(state.receiver.lat - subpoint.lat)
        let lonSpan = abs(state.receiver.lon - subpoint.lon)
        let maxSpan = max(latSpan, lonSpan)
        // Scale distance: closer for nearby subpoints, farther for distant ones
        let distance = max(8_000_000, min(35_000_000, maxSpan * 250_000))

        withAnimation(.easeInOut(duration: 0.6)) {
            position = .camera(
                MapCamera(
                    centerCoordinate: CLLocationCoordinate2D(
                        latitude: centerLat, longitude: centerLon),
                    distance: distance,
                    heading: 0,
                    pitch: 0
                )
            )
        }
    }

    private func ringCoordinates(
        center: CLLocationCoordinate2D, radiusMeters: CLLocationDistance, points: Int
    ) -> [CLLocationCoordinate2D] {
        let earthRadius = 6_371_000.0
        let lat1 = center.latitude * .pi / 180
        let lon1 = center.longitude * .pi / 180
        let angularDistance = radiusMeters / earthRadius

        var coordinates: [CLLocationCoordinate2D] = []
        coordinates.reserveCapacity(points + 1)

        for index in 0...points {
            let bearing = (Double(index) / Double(points)) * 2 * .pi
            let lat2 = asin(
                sin(lat1) * cos(angularDistance) + cos(lat1) * sin(angularDistance) * cos(bearing)
            )
            let lon2 =
                lon1
                + atan2(
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
}

// MARK: - Legacy Flat Projection Map (kept for reference)

struct GPSGlobeProjectionMap: View {
    let state: GPSGlobeState
    @Binding var selectedPRN: Int?
    @ObservedObject var satelliteMapViewModel: SatelliteMapViewModel

    @State private var position: MapCameraPosition

    init(
        state: GPSGlobeState, selectedPRN: Binding<Int?>,
        satelliteMapViewModel: SatelliteMapViewModel
    ) {
        self.state = state
        _selectedPRN = selectedPRN
        _satelliteMapViewModel = ObservedObject(wrappedValue: satelliteMapViewModel)
        _position = State(
            initialValue: .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(
                        latitude: state.receiver.lat, longitude: state.receiver.lon),
                    span: MKCoordinateSpan(latitudeDelta: 80, longitudeDelta: 80)
                )
            ))
    }

    var body: some View {
        Map(position: $position) {
            MapPolyline(coordinates: coverageRingCoordinates)
                .stroke(.cyan.opacity(0.3), lineWidth: 1.5)

            Annotation("Franca", coordinate: receiverCoordinate) {
                ZStack {
                    Circle()
                        .fill(GPSGlobePalette.receiver.opacity(0.22))
                        .frame(width: 26, height: 26)
                    Circle()
                        .fill(GPSGlobePalette.receiver)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1))
                }
            }

            ForEach(satelliteMapViewModel.satellites) { satellite in
                Annotation("", coordinate: satellite.coordinate) {
                    Button {
                        satelliteMapViewModel.selectSatellite(satellite)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: satellite.category.iconName)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(satellite.category.mapColor, in: Circle())
                                .overlay(
                                    Circle()
                                        .stroke(.white.opacity(0.55), lineWidth: 1)
                                )

                            if satelliteMapViewModel.selectedSatellite?.id == satellite.id {
                                Text(satellite.name)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.black.opacity(0.72), in: Capsule())
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            ForEach(satellitesWithSubpoints, id: \.prn) { satellite in
                if let subpoint = satellite.subpoint {
                    let subpointCoordinate = CLLocationCoordinate2D(
                        latitude: subpoint.lat,
                        longitude: subpoint.lon
                    )

                    if satellite.prn == selectedPRN {
                        MapPolyline(coordinates: [receiverCoordinate, subpointCoordinate])
                            .stroke(GPSGlobePalette.selection.opacity(0.55), lineWidth: 2)
                    }

                    Annotation("", coordinate: subpointCoordinate) {
                        Button {
                            selectedPRN = satellite.prn
                        } label: {
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(
                                        satellite.prn == selectedPRN
                                            ? GPSGlobePalette.selection
                                            : (satellite.used
                                                ? GPSGlobePalette.satellite : GPSGlobePalette.nadir)
                                    )
                                    .frame(
                                        width: satellite.prn == selectedPRN ? 12 : 10,
                                        height: satellite.prn == selectedPRN ? 12 : 10
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(.white.opacity(0.7), lineWidth: 1)
                                    )

                                if satellite.prn == selectedPRN {
                                    Text("PRN \(satellite.prn)")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.black.opacity(0.72), in: Capsule())
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .mapStyle(.hybrid(elevation: .flat))
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Projeção na Terra")
                    .font(.caption.weight(.semibold))
                Text(selectedMapCaption)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(
                .ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .padding(10)
        }
        .onAppear {
            recenterMap(for: selectedSatellite)
        }
        .onChange(of: selectedPRN) { _, _ in
            recenterMap(for: selectedSatellite)
        }
        .onChange(of: state.generatedAt) { _, _ in
            recenterMap(for: selectedSatellite)
        }
    }

    private var receiverCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: state.receiver.lat, longitude: state.receiver.lon)
    }

    private var satellitesWithSubpoints: [GPSGlobeSatellite] {
        state.satellitesVisible
            .filter { $0.subpoint != nil }
            .sorted { lhs, rhs in
                if lhs.used != rhs.used { return lhs.used && !rhs.used }
                return (lhs.signalDBHz ?? 0) > (rhs.signalDBHz ?? 0)
            }
    }

    private var coverageRingCoordinates: [CLLocationCoordinate2D] {
        ringCoordinates(
            center: satelliteMapViewModel.stationCoordinate,
            radiusMeters: satelliteMapViewModel.coverageRadiusMeters,
            points: 180
        )
    }

    private var selectedSatellite: GPSGlobeSatellite? {
        guard let selectedPRN else { return satellitesWithSubpoints.first }
        return satellitesWithSubpoints.first(where: { $0.prn == selectedPRN })
            ?? satellitesWithSubpoints.first
    }

    private var selectedMapCaption: String {
        guard let satellite = selectedSatellite, let subpoint = satellite.subpoint else {
            return "Toque em um satelite para sincronizar globo e mapa"
        }
        return
            "PRN \(satellite.prn)  \(subpoint.lat.formattedBR(decimals: 2)), \(subpoint.lon.formattedBR(decimals: 2))"
    }

    private func recenterMap(for satellite: GPSGlobeSatellite?) {
        guard let subpoint = satellite?.subpoint else {
            position = .region(
                MKCoordinateRegion(
                    center: receiverCoordinate,
                    span: MKCoordinateSpan(latitudeDelta: 80, longitudeDelta: 80)
                )
            )
            return
        }

        let minLat = min(receiverCoordinate.latitude, subpoint.lat)
        let maxLat = max(receiverCoordinate.latitude, subpoint.lat)
        let minLon = min(receiverCoordinate.longitude, subpoint.lon)
        let maxLon = max(receiverCoordinate.longitude, subpoint.lon)

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(25, (maxLat - minLat) * 1.8),
            longitudeDelta: max(25, (maxLon - minLon) * 1.8)
        )
        position = .region(MKCoordinateRegion(center: center, span: span))
    }

    private func ringCoordinates(
        center: CLLocationCoordinate2D, radiusMeters: CLLocationDistance, points: Int
    ) -> [CLLocationCoordinate2D] {
        let earthRadius = 6_371_000.0
        let lat1 = center.latitude * .pi / 180
        let lon1 = center.longitude * .pi / 180
        let angularDistance = radiusMeters / earthRadius

        var coordinates: [CLLocationCoordinate2D] = []
        coordinates.reserveCapacity(points + 1)

        for index in 0...points {
            let bearing = (Double(index) / Double(points)) * 2 * .pi
            let lat2 = asin(
                sin(lat1) * cos(angularDistance) + cos(lat1) * sin(angularDistance) * cos(bearing)
            )

            let lon2 =
                lon1
                + atan2(
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
}

struct GPSInteractiveSceneView: UIViewRepresentable {
    @ObservedObject var sceneController: GPSGlobeSceneController
    let onSelectPRN: (Int?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(sceneController: sceneController, onSelectPRN: onSelectPRN)
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = sceneController.scene
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.rendersContinuously = true
        view.defaultCameraController.interactionMode = .orbitTurntable

        let tap = UITapGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        context.coordinator.scnView = view
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        uiView.scene = sceneController.scene
        context.coordinator.sceneController = sceneController
        context.coordinator.onSelectPRN = onSelectPRN
        context.coordinator.scnView = uiView
    }

    final class Coordinator: NSObject {
        var sceneController: GPSGlobeSceneController
        var onSelectPRN: (Int?) -> Void
        weak var scnView: SCNView?

        init(sceneController: GPSGlobeSceneController, onSelectPRN: @escaping (Int?) -> Void) {
            self.sceneController = sceneController
            self.onSelectPRN = onSelectPRN
        }

        @MainActor
        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let view = scnView else { return }
            let point = recognizer.location(in: view)
            onSelectPRN(sceneController.satellitePRN(at: point, in: view))
        }
    }
}

struct GPSSatelliteTooltipOverlay: View {
    let satellite: GPSGlobeSatellite
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                satelliteArtwork

                VStack(alignment: .leading, spacing: 8) {
                    Text((satellite.intlDesignator ?? "PRN \(satellite.prn)").uppercased())
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)

                    Text(satellite.displayName)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(
                        satellite.used
                            ? "Usado pelo GPS local no sincronismo de hora e localização"
                            : "Visivel, mas não esta sendo usado no fix local agora"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(satellite.used ? GPSGlobePalette.satellite : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        (satellite.used ? GPSGlobePalette.satellite : Color.white).opacity(0.12),
                        in: Capsule())
                }

                Spacer(minLength: 0)

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.72))
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                tooltipFact("Launch", launchText)
                tooltipFact("Localização atual", locationText)
                tooltipFact("Período orbital", orbitPeriodText)
                tooltipFact("Velocidade", orbitSpeedText)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.88), Color(red: 0.06, green: 0.09, blue: 0.16),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.28), radius: 14, x: 0, y: 8)
    }

    @ViewBuilder
    private var satelliteArtwork: some View {
        if let url = imageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure(_):
                    artworkPlaceholder
                case .empty:
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                        ProgressView()
                            .tint(.white)
                    }
                @unknown default:
                    artworkPlaceholder
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            artworkPlaceholder
        }
    }

    private var artworkPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
            Image(systemName: satellite.used ? "satellite.fill" : "smallcircle.filled.circle")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(satellite.used ? GPSGlobePalette.satellite : .white)
        }
        .frame(width: 72, height: 72)
    }

    private var imageURL: URL? {
        guard let imageURL = satellite.imageURL, !imageURL.isEmpty else { return nil }
        if imageURL.hasPrefix("http") {
            return URL(string: imageURL)
        }
        return URL(string: "https://gps.meulab.fun\(imageURL)")
    }

    private var launchText: String {
        var parts: [String] = []
        if let date = satellite.launch?.dateLocalized { parts.append(date) }
        if let time = satellite.launch?.timeUTC { parts.append("\(time) UTC") }
        if let site = satellite.launch?.site { parts.append(site) }
        if let vehicle = satellite.launch?.vehicle { parts.append(vehicle) }
        return parts.isEmpty ? "Sem dados" : parts.joined(separator: "\n")
    }

    private var locationText: String {
        guard let subpoint = satellite.subpoint else { return "Sem dados" }
        let lat = abs(subpoint.lat).formattedBR(decimals: 2)
        let lon = abs(subpoint.lon).formattedBR(decimals: 2)
        let latSuffix = subpoint.lat >= 0 ? "N" : "S"
        let lonSuffix = subpoint.lon >= 0 ? "E" : "W"
        let altitude = (subpoint.altitudeKM ?? 0).formattedBR(decimals: 0)
        return "\(lat)° \(latSuffix), \(lon)° \(lonSuffix)\n\(altitude) km"
    }

    private var orbitPeriodText: String {
        guard let period = satellite.orbit?.periodMinutes else { return "Sem dados" }
        return "\(period.formattedBR(decimals: 1)) min"
    }

    private var orbitSpeedText: String {
        guard let speed = satellite.orbit?.speedKMH else { return "Sem dados" }
        return "\(speed.formattedBR(decimals: 0)) km/h"
    }

    private func tooltipFact(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct GPSGlobeLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Legenda")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                GPSGlobeLegendItem(color: GPSGlobePalette.receiver, text: "Dongle / posição atual")
                GPSGlobeLegendItem(
                    color: GPSGlobePalette.satellite, text: "Satélites GPS usados no cálculo")
                GPSGlobeLegendItem(
                    color: GPSGlobePalette.nadir, text: "Subponto orbital sobre a Terra")
                GPSGlobeLegendItem(color: .orange, text: "ORBCOMM captável no mesmo mapa")
                GPSGlobeLegendItem(color: .cyan, text: "Meteor captável no mesmo mapa")
            }
        }
    }
}

struct GPSGlobeLegendItem: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
                )
            Text(text)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }
}

struct GPSGlobeFullscreenView: View {
    @ObservedObject var viewModel: GPSGlobeViewModel
    @ObservedObject var satelliteMapViewModel: SatelliteMapViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    if let state = viewModel.state {
                        GPSGlobeFullscreenContent(
                            state: state,
                            statusMessage: viewModel.statusMessage,
                            satelliteMapViewModel: satelliteMapViewModel,
                            availableHeight: geo.size.height
                        )
                    } else if viewModel.isLoading {
                        Spacer()
                        LoadingCard()
                        Spacer()
                    } else if let error = viewModel.errorMessage {
                        Spacer()
                        ErrorCard(message: error)
                        Spacer()
                    }
                }
            }
            .navigationTitle("GPS Globe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Fullscreen-specific content that fills available space
private struct GPSGlobeFullscreenContent: View {
    let state: GPSGlobeState
    let statusMessage: String?
    @ObservedObject var satelliteMapViewModel: SatelliteMapViewModel
    let availableHeight: CGFloat

    @State private var selectedSatellitePRN: Int?

    private var metricsHeight: CGFloat { 58 }
    private var legendHeight: CGFloat { 100 }
    private var globeHeight: CGFloat {
        max(300, availableHeight - metricsHeight - legendHeight - 40)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Metrics row
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 120), spacing: 10)],
                spacing: 10
            ) {
                GPSMiniMetric(
                    title: "Modo",
                    value: gpsModeText,
                    tint: GPSGlobePalette.receiver
                )
                GPSMiniMetric(
                    title: "HDOP",
                    value: formatted(state.sky.hdop, fallback: "--"),
                    tint: GPSGlobePalette.satellite
                )
                GPSMiniMetric(
                    title: "Precisão",
                    value: receiverAccuracyText,
                    tint: GPSGlobePalette.nadir
                )
            }
            .padding(.horizontal, 12)

            // Globe - fills remaining space
            ZStack(alignment: .bottomLeading) {
                UnifiedSatelliteGlobe(
                    state: state,
                    selectedPRN: $selectedSatellitePRN,
                    satelliteMapViewModel: satelliteMapViewModel,
                    isFullscreen: true
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Receptor em Franca")
                        .font(.caption.weight(.semibold))
                    Text(receiverCoordinateText)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .glassCard(cornerRadius: 12)
                .padding(12)

                if let selectedSatellite {
                    GPSSatelliteTooltipOverlay(
                        satellite: selectedSatellite,
                        onDismiss: { selectedSatellitePRN = nil }
                    )
                    .frame(maxWidth: 400)
                    .padding(12)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .bottomTrailing)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Compact legend
            HStack(spacing: 16) {
                GPSGlobeFullscreenLegendDot(color: GPSGlobePalette.receiver, text: "Dongle")
                GPSGlobeFullscreenLegendDot(color: GPSGlobePalette.satellite, text: "GPS usado")
                GPSGlobeFullscreenLegendDot(color: GPSGlobePalette.nadir, text: "Subponto")
                GPSGlobeFullscreenLegendDot(color: .orange, text: "ORBCOMM")
                GPSGlobeFullscreenLegendDot(color: .cyan, text: "Meteor")
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)

            if let statusMessage, !statusMessage.isEmpty {
                Label(statusMessage, systemImage: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
            }
        }
        .onAppear {
            syncSelection(with: state)
        }
        .onChange(of: state) { _, newValue in
            syncSelection(with: newValue)
        }
    }

    private var sortedSatellites: [GPSGlobeSatellite] {
        state.satellitesVisible.sorted { lhs, rhs in
            if lhs.used != rhs.used { return lhs.used && !rhs.used }
            return (lhs.signalDBHz ?? 0) > (rhs.signalDBHz ?? 0)
        }
    }

    private var selectedSatellite: GPSGlobeSatellite? {
        guard let selectedSatellitePRN else { return nil }
        return sortedSatellites.first(where: { $0.prn == selectedSatellitePRN })
    }

    private var gpsModeText: String {
        switch state.receiver.mode {
        case 3: return "3D"
        case 2: return "2D"
        case 1: return "Fix"
        default: return "--"
        }
    }

    private var receiverAccuracyText: String {
        if let horizontalError = state.receiver.horizontalErrorM {
            return "\(horizontalError.formattedBR(decimals: 0)) m"
        }
        return "--"
    }

    private var receiverCoordinateText: String {
        "\(state.receiver.lat.formattedBR(decimals: 4)), \(state.receiver.lon.formattedBR(decimals: 4))"
    }

    private func syncSelection(with state: GPSGlobeState) {
        let availableIDs = Set(state.satellitesVisible.map(\.prn))
        if let selectedSatellitePRN, availableIDs.contains(selectedSatellitePRN) {
            return
        }
        selectedSatellitePRN = nil
    }

    private func formatted(_ value: Double?, fallback: String) -> String {
        guard let value else { return fallback }
        return value.formattedBR(decimals: 2)
    }
}

private struct GPSGlobeFullscreenLegendDot: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
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

    private func merge(existing: [SatellitePosition], incoming: [SatellitePosition])
        -> [SatellitePosition]
    {
        var byId: [String: SatellitePosition] = Dictionary(
            uniqueKeysWithValues: existing.map { ($0.id, $0) })

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
                        .glassInteractive(cornerRadius: 17)
                }
                .buttonStyle(.plain)

                Button {
                    zoom(by: 0.65)
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                        .frame(width: 34, height: 34)
                        .glassInteractive(cornerRadius: 17)
                }
                .buttonStyle(.plain)

                Button {
                    zoom(by: 1.45)
                } label: {
                    Image(systemName: "minus")
                        .font(.headline)
                        .frame(width: 34, height: 34)
                        .glassInteractive(cornerRadius: 17)
                }
                .buttonStyle(.plain)
            }
            .padding(10)
        }
        .onChange(of: selectedSatelliteID) { _, newID in
            guard let newID,
                let sat = viewModel.satellites.first(where: { $0.id == newID })
            else { return }
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
    private func ringCoordinates(
        center: CLLocationCoordinate2D, radiusMeters: CLLocationDistance, points: Int
    ) -> [CLLocationCoordinate2D] {
        let earthRadius = 6_371_000.0
        let lat1 = center.latitude * .pi / 180
        let lon1 = center.longitude * .pi / 180
        let angularDistance = radiusMeters / earthRadius

        var coordinates: [CLLocationCoordinate2D] = []
        coordinates.reserveCapacity(points + 1)

        for i in 0...points {
            let bearing = (Double(i) / Double(points)) * 2 * .pi
            let lat2 = asin(
                sin(lat1) * cos(angularDistance) + cos(lat1) * sin(angularDistance) * cos(bearing)
            )

            let lon2 =
                lon1
                + atan2(
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
                        ContentUnavailableView(
                            "Erro de Carregamento", systemImage: "exclamationmark.triangle",
                            description: Text(error))
                    } else {
                        // Header with satellite image
                        headerView

                        // Key Stats Grid
                        statsGrid

                        // Detailed List
                        detailedInfoList
                    }
                }
                .padding()
            }
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

    /// Image URL from Wikipedia Commons for known satellite constellations
    private var satelliteImageURL: URL? {
        let name = satellite.name.lowercased()
        if name.contains("orbcomm") {
            // ORBCOMM FM satellite - Wikipedia Commons image
            return URL(
                string:
                    "https://upload.wikimedia.org/wikipedia/commons/thumb/f/f9/ORBCOMM_satellite.jpg/300px-ORBCOMM_satellite.jpg"
            )
        } else if name.contains("meteor") {
            return URL(
                string:
                    "https://upload.wikimedia.org/wikipedia/commons/thumb/8/81/Meteor-M_satellite.jpg/300px-Meteor-M_satellite.jpg"
            )
        } else if name.contains("noaa") {
            return URL(
                string:
                    "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3e/NOAA-20_satellite.jpg/300px-NOAA-20_satellite.jpg"
            )
        }
        return nil
    }

    private var headerView: some View {
        let status = viewModel.selectedStatus
        let category = status?.category ?? satellite.category

        return VStack(spacing: 12) {
            if let imageURL = satelliteImageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    case .failure:
                        satelliteIconView(category: category)
                    case .empty:
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(category.mapColor.opacity(0.08))
                                .frame(height: 120)
                            ProgressView()
                        }
                    @unknown default:
                        satelliteIconView(category: category)
                    }
                }
            } else {
                satelliteIconView(category: category)
            }

            Text(status?.name ?? satellite.name)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                Text(category.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Capsule())

                if let norad = satellite.norad {
                    Text("NORAD \(norad)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassCard(cornerRadius: 16)
    }

    private func satelliteIconView(category: SatelliteCategory) -> some View {
        Image(systemName: category.iconName)
            .font(.system(size: 48))
            .foregroundStyle(category.mapColor)
            .padding()
            .background(category.mapColor.opacity(0.1))
            .clipShape(Circle())
    }

    private var statsGrid: some View {
        let status = viewModel.selectedStatus

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            SatStatCard(
                icon: "location.fill", value: formatDouble(status?.lat ?? satellite.lat),
                label: "Latitude", color: .blue)
            SatStatCard(
                icon: "location.fill", value: formatDouble(status?.lon ?? satellite.lon),
                label: "Longitude", color: .blue)
            SatStatCard(
                icon: "arrow.up.left.and.arrow.down.right",
                value: formatDouble(status?.altKm ?? satellite.altKm, suffix: " km"),
                label: "Altitude", color: .orange)
            SatStatCard(
                icon: "speedometer", value: formatDouble(status?.speedKmS ?? 0, suffix: " km/s"),
                label: "Velocidade", color: .green)
        }
    }

    private var detailedInfoList: some View {
        let status = viewModel.selectedStatus

        return VStack(spacing: 0) {
            SatDetailRow(
                title: "NORAD",
                value: status?.norad.map(String.init) ?? satellite.norad.map(String.init) ?? "-")
            Divider()
            SatDetailRow(
                title: "Elevação",
                value: formatDouble(status?.elevation ?? satellite.elevation, suffix: "°"))
            Divider()
            SatDetailRow(
                title: "Azimute",
                value: formatDouble(status?.azimuth ?? satellite.azimuth, suffix: "°"))
            Divider()
            SatDetailRow(
                title: "Período Orbital",
                value: status?.orbitPeriodMin.map { formatDouble($0, suffix: " min") } ?? "-")
            Divider()
            SatDetailRow(
                title: "Mean Motion",
                value: status?.meanMotionRevPerDay.map { formatDouble($0, suffix: " rev/day") }
                    ?? "-")
        }
        .glassCard(cornerRadius: 16)
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
        .glassCard(cornerRadius: 12)
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

extension SatellitePosition {
    fileprivate var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

extension SatelliteCategory {
    fileprivate var iconName: String {
        switch self {
        case .meteor: return "satellite.fill"
        case .orbcomm: return "antenna.radiowaves.left.and.right"
        case .unknown: return "satellite.fill"
        }
    }

    fileprivate var mapColor: Color {
        switch self {
        case .meteor: return .cyan
        case .orbcomm: return .orange
        case .unknown: return .gray
        }
    }

    fileprivate var sortOrder: Int {
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
            .glassInteractive(cornerRadius: 22)
            .buttonStyle(.plain)
        }
    }
}
