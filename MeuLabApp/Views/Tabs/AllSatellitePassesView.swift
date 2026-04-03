import Photos
import SwiftUI

struct AllSatellitePassesView: View {
    @EnvironmentObject var appState: AppState
    @State private var allPasses: PassesListPaginated?
    @State private var isLoadingAllPasses = false
    @State private var allPassesError: String?
    @State private var selectedFilter: PassFilter = .all
    @State private var currentPage = 1
    @State private var selectedPass: SatellitePass?
    @State private var showingPassImages = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Controls
                filterControls

                // Content
                if isLoadingAllPasses {
                    ProgressView("Carregando passes...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = allPassesError {
                    ErrorCard(message: error)
                        .onTapGesture {
                            loadAllPasses()
                        }
                } else if let passes = allPasses?.passes, !passes.isEmpty {
                    passesList(passes)
                } else {
                    emptyState
                }
            }
            .navigationTitle("Todos os Passes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Download Completo") {
                        downloadAllImages()
                    }
                    .disabled(allPasses?.passes.isEmpty != false)
                }
            }
            .refreshable {
                currentPage = 1
                loadAllPasses()
            }
            .onAppear {
                loadAllPasses()
            }
            .sheet(isPresented: $showingPassImages) {
                if let pass = selectedPass {
                    PassImagesView(pass: pass)
                }
            }
        }
    }

    @ViewBuilder
    private var filterControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filtros")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(PassFilter.allCases, id: \.self) { filter in
                        Button {
                            selectedFilter = filter
                            currentPage = 1
                            loadAllPasses()
                        } label: {
                            Text(filter.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(
                                            selectedFilter == filter
                                                ? Color.blue : Color(.systemGray6))
                                )
                                .foregroundStyle(selectedFilter == filter ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .materialCard(cornerRadius: 0)
    }

    @ViewBuilder
    private func passesList(_ passes: [SatellitePass]) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(passes, id: \.name) { pass in
                    SatellitePassCard(
                        pass: pass,
                        onViewImages: {
                            selectedPass = pass
                            showingPassImages = true
                        },
                        onDownload: {
                            downloadPassImages(pass)
                        }
                    )
                }

                // Load More Button
                if allPasses?.hasMore == true {
                    Button("Carregar mais") {
                        loadMorePasses()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .disabled(isLoadingAllPasses)
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "satellite")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Nenhum passe encontrado")
                .font(.title2)
                .fontWeight(.medium)

            Text("Tente ajustar os filtros para ver passes anteriores")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func loadAllPasses() {
        isLoadingAllPasses = true
        allPassesError = nil

        Task {
            do {
                let passes: PassesListPaginated
                switch selectedFilter {
                case .all:
                    passes = try await APIService.shared.fetchAllSatellitePasses(page: currentPage)
                case .meteor:
                    passes = try await APIService.shared.fetchSatellitePassesBySatellite(
                        satellite: "METEOR", page: currentPage)
                case .noaa:
                    passes = try await APIService.shared.fetchSatellitePassesBySatellite(
                        satellite: "NOAA", page: currentPage)
                case .lastWeek:
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    let from = formatter.string(
                        from: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                    )
                    let to = formatter.string(from: Date())
                    passes = try await APIService.shared.fetchSatellitePassesByDateRange(
                        from: from, to: to, page: currentPage)
                case .lastMonth:
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    let from = formatter.string(
                        from: Calendar.current.date(byAdding: .month, value: -1, to: Date())
                            ?? Date())
                    let to = formatter.string(from: Date())
                    passes = try await APIService.shared.fetchSatellitePassesByDateRange(
                        from: from, to: to, page: currentPage)
                }

                await MainActor.run {
                    if currentPage == 1 {
                        self.allPasses = passes
                    } else {
                        self.allPasses?.passes.append(contentsOf: passes.passes)
                        self.allPasses?.hasMore = passes.hasMore
                    }
                    self.isLoadingAllPasses = false
                }
            } catch {
                await MainActor.run {
                    self.allPassesError = error.localizedDescription
                    self.isLoadingAllPasses = false
                }
            }
        }
    }

    private func loadMorePasses() {
        currentPage += 1
        loadAllPasses()
    }

    private func downloadPassImages(_ pass: SatellitePass) {
        Task {
            do {
                let images = try await APIService.shared.fetchPassImages(passName: pass.name)

                // Request photo library permission
                let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
                guard status == .authorized else {
                    print("Permissão negada para acessar a biblioteca de fotos")
                    return
                }

                // Save images to photo library
                for imageInfo in images.images {
                    if let imageData = try? await APIService.shared.fetchImageData(
                        passName: pass.name,
                        folderName: imageInfo.folderName,
                        imageName: imageInfo.fileName
                    ) {
                        // Convert to UIImage and save
                        if let uiImage = UIImage(data: imageData) {
                            UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
                        }
                    }
                }

                await MainActor.run {
                    // Show success message
                    print("Imagens do passe \(pass.name) salvas com sucesso")
                }
            } catch {
                await MainActor.run {
                    print("Erro ao baixar imagens: \(error)")
                }
            }
        }
    }

    private func downloadAllImages() {
        guard let passes = allPasses?.passes else { return }

        Task {
            for pass in passes {
                downloadPassImages(pass)
                // Add delay between downloads to avoid overwhelming the server
                try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
            }
        }
    }
}

// MARK: - Pass Filter

enum PassFilter: String, CaseIterable {
    case all = "all"
    case meteor = "meteor"
    case noaa = "noaa"
    case lastWeek = "last_week"
    case lastMonth = "last_month"

    var displayName: String {
        switch self {
        case .all: return "Todos"
        case .meteor: return "METEOR"
        case .noaa: return "NOAA"
        case .lastWeek: return "Última Semana"
        case .lastMonth: return "Último Mês"
        }
    }
}

// MARK: - Satellite Pass Card

struct SatellitePassCard: View {
    let pass: SatellitePass
    let onViewImages: () -> Void
    let onDownload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pass.satelliteName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(formatPassName(pass.name))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatPassDate(pass.name))
                        .font(.caption)
                        .foregroundStyle(.primary)

                    Text(String(format: "%.1f°", pass.maxElevation))
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
            }

            // Pass Info
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(formatDuration(pass.duration))
                        .font(.caption)
                }
                .foregroundStyle(.secondary)

                if !pass.images.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "photo")
                            .font(.caption)
                        Text("\(pass.images.count) imagens")
                            .font(.caption)
                    }
                    .foregroundStyle(.green)
                }

                Spacer()

                // Status
                HStack(spacing: 4) {
                    Circle()
                        .fill(pass.success ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(pass.success ? "Sucesso" : "Falha")
                        .font(.caption)
                        .foregroundStyle(pass.success ? .green : .red)
                }
            }

            // Action Buttons
            HStack(spacing: 12) {
                if !pass.images.isEmpty {
                    Button("Ver Imagens") {
                        onViewImages()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(8)
                }

                Button("Download") {
                    onDownload()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.green)
                .foregroundStyle(.white)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private func formatPassName(_ name: String) -> String {
        let components = name.components(separatedBy: "_")
        guard components.count >= 3 else { return name }
        return "\(components[0]) \(components[1]) \(components[2])"
    }

    private func formatPassDate(_ name: String) -> String {
        let components = name.components(separatedBy: "_")
        guard components.count >= 3,
            let date = components[1].optionalDate(),
            let time = components[2].optionalTime()
        else { return name }

        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM HH:mm"
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Pass Images View

struct PassImagesView: View {
    let pass: SatellitePass
    @State private var images: LastImages?
    @State private var isLoading = true
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView("Carregando imagens...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = error {
                    ErrorCard(message: error)
                } else if let images = images {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16
                    ) {
                        ForEach(images.images) { image in
                            AsyncImage(
                                url: APIService.shared.imageLightURL(
                                    passName: pass.name,
                                    folderName: image.folderName,
                                    imageName: image.fileName,
                                    max: 512
                                )
                            ) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color(.systemGray6))
                                    .overlay {
                                        ProgressView()
                                    }
                            }
                            .frame(height: 200)
                            .cornerRadius(12)
                            .clipped()
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(pass.satelliteName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Concluído") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadImages()
        }
    }

    private func loadImages() {
        Task {
            do {
                let loadedImages = try await APIService.shared.fetchPassImages(passName: pass.name)
                await MainActor.run {
                    self.images = loadedImages
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - String Extensions

extension String {
    func optionalDate() -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.date(from: self)
    }

    func optionalTime() -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmmss"
        return formatter.date(from: self)
    }
}

#Preview {
    AllSatellitePassesView()
        .environmentObject(AppState())
}
