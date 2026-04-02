import SwiftUI

struct FlightSearchView: View {
    @EnvironmentObject var appState: AppState

    enum Mode: String, CaseIterable {
        case flights = "Voos"
        case airports = "Aeroportos"
    }

    enum Airport: String, CaseIterable, Identifiable {
        case gru = "GRU"
        case cgh = "CGH"
        case vcp = "VCP"
        case rao = "RAO"

        var id: String { rawValue }
    }

    enum BoardKind: String, CaseIterable, Identifiable {
        case scheduledDepartures = "Partidas"
        case scheduledArrivals = "Chegadas"

        var id: String { rawValue }

        var apiKind: APIService.FlightAwareBoardKind {
            switch self {
            case .scheduledDepartures: return .scheduledDepartures
            case .scheduledArrivals: return .scheduledArrivals
            }
        }
    }

    @State private var mode: Mode = .flights
    @State private var searchRequest = FlightSearchRequest()
    @State private var searchResults: FlightSearchResponse?
    @State private var isLoading = false
    @State private var error: String?
    @State private var showingFilters = false
    @State private var searchQuery = ""
    @State private var currentPage = 1
    @State private var hasMoreResults = false

    // Airport board (FlightAware)
    @State private var selectedAirport: Airport = .gru
    @State private var boardKind: BoardKind = .scheduledDepartures
    @State private var boardResponse: FlightAwareAirportBoardResponse?
    @State private var boardLoading = false
    @State private var boardError: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                switch mode {
                case .flights:
                    searchBar
                    quickFilters

                    if let results = searchResults {
                        resultsList(results)
                    } else if !isLoading && error == nil {
                        emptyState
                    }

                    if isLoading {
                        ProgressView("Buscando voos...")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }

                    if let error = error {
                        ErrorCard(message: error)
                            .onTapGesture { performSearch() }
                    }

                case .airports:
                    airportBoardControls

                    if boardLoading {
                        ProgressView("Carregando...")
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if let boardResponse {
                        airportBoardList(boardResponse)
                    } else if let boardError {
                        ErrorCard(message: boardError)
                            .onTapGesture { loadBoard() }
                            .padding(.horizontal)
                    } else {
                        ContentUnavailableView("Sem dados", systemImage: "airplane.departure")
                            .padding(.top, 40)
                    }
                }
            }
            .navigationTitle("Buscar Voos")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if mode == .flights {
                        Button {
                            showingFilters = true
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                FlightFiltersView(
                    searchRequest: $searchRequest,
                    onSearch: {
                        performSearch()
                    }
                )
            }
            .refreshable {
                currentPage = 1
                if mode == .flights {
                    performSearch()
                } else {
                    loadBoard()
                }
            }
        }
        .onSubmit {
            if mode == .flights {
                performSearch()
            }
        }
        .onChange(of: mode) { _, newMode in
            if newMode == .airports, boardResponse == nil, !boardLoading {
                loadBoard()
            }
        }
    }
    
    @ViewBuilder
    private var searchBar: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Buscar voo, número, registro...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        searchRequest.query = searchQuery.isEmpty ? nil : searchQuery
                        performSearch()
                    }
                
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                        searchRequest.query = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassCard(cornerRadius: 12)
        }
        .padding()
    }
    
    @ViewBuilder
    private var quickFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                QuickFilterChip(
                    title: "Hoje",
                    isSelected: isTodaySelected,
                    onTap: {
                        setTodayFilter()
                    }
                )
                
                QuickFilterChip(
                    title: "Aeronaves",
                    isSelected: searchRequest.aircraftType != nil,
                    onTap: {
                        showAircraftTypeFilter()
                    }
                )
                
                QuickFilterChip(
                    title: "Altitude",
                    isSelected: searchRequest.altitudeMin != nil || searchRequest.altitudeMax != nil,
                    onTap: {
                        showAltitudeFilter()
                    }
                )
                
                QuickFilterChip(
                    title: "Rota",
                    isSelected: searchRequest.origin != nil || searchRequest.destination != nil,
                    onTap: {
                        showRouteFilter()
                    }
                )
            }
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private func resultsList(_ results: FlightSearchResponse) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(results.results, id: \.hex) { flight in
                    FlightSearchResultCard(flight: flight)
                }
                
                // Load More Button
                if results.hasMore {
                    Button("Carregar mais") {
                        loadMoreResults()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .disabled(isLoading)
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "airplane")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("Nenhum voo encontrado")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Tente ajustar os filtros ou buscar novamente")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var isTodaySelected: Bool {
        let calendar = Calendar.current
        if let from = searchRequest.timeFrom {
            return calendar.isDateInToday(Formatters.isoDate.date(from: from) ?? Date())
        }
        return false
    }
    
    private func performSearch() {
        isLoading = true
        error = nil
        currentPage = 1
        
        var request = searchRequest
        request.offset = nil // Reset offset for new search
        
        Task {
            do {
                let results = try await APIService.shared.searchFlights(request)
                await MainActor.run {
                    self.searchResults = results
                    self.hasMoreResults = results.hasMore
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
    
    private func loadMoreResults() {
        guard hasMoreResults && !isLoading else { return }
        
        isLoading = true
        currentPage += 1
        
        var request = searchRequest
        request.offset = ((currentPage - 1) * (request.limit ?? 20))
        
        Task {
            do {
                let newResults = try await APIService.shared.searchFlights(request)
                await MainActor.run {
                    self.searchResults?.results.append(contentsOf: newResults.results)
                    self.searchResults?.hasMore = newResults.hasMore
                    self.hasMoreResults = newResults.hasMore
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
    
    private func setTodayFilter() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        searchRequest.timeFrom = ISO8601DateFormatter().string(from: startOfDay)
        searchRequest.timeTo = ISO8601DateFormatter().string(from: endOfDay)
        performSearch()
    }
    
    private func showAircraftTypeFilter() {
        // Show aircraft type picker
        showingFilters = true
    }
    
    private func showAltitudeFilter() {
        // Show altitude range picker
        showingFilters = true
    }
    
    private func showRouteFilter() {
        // Show route origin/destination picker
        showingFilters = true
    }

    // MARK: - Airport Board (FlightAware)

    private var airportBoardControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Picker("Aeroporto", selection: $selectedAirport) {
                    ForEach(Airport.allCases) { ap in
                        Text(ap.rawValue).tag(ap)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    loadBoard()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .adaptiveGlassButton()
            }

            Picker("Tipo", selection: $boardKind) {
                ForEach(BoardKind.allCases) { k in
                    Text(k.rawValue).tag(k)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .onChange(of: selectedAirport) { _, _ in loadBoard() }
        .onChange(of: boardKind) { _, _ in loadBoard() }
    }

    private func airportBoardList(_ response: FlightAwareAirportBoardResponse) -> some View {
        let flights = airportBoardFlights(from: response)
        return ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(flights) { f in
                    AirportBoardCard(flight: f)
                }

                if flights.isEmpty {
                    ContentUnavailableView("Nenhum voo encontrado", systemImage: "airplane")
                        .padding(.top, 40)
                }
            }
            .padding()
        }
    }

    private func airportBoardFlights(from response: FlightAwareAirportBoardResponse) -> [FlightAwareFlight] {
        switch boardKind {
        case .scheduledDepartures:
            return response.data.scheduledDepartures ?? []
        case .scheduledArrivals:
            return response.data.scheduledArrivals ?? []
        }
    }

    private func loadBoard() {
        if boardLoading { return }
        boardLoading = true
        boardError = nil

        let airport = selectedAirport.rawValue
        let kind = boardKind.apiKind

        Task {
            do {
                let resp = try await APIService.shared.fetchFlightAwareAirportBoard(
                    airport: airport,
                    kind: kind,
                    type: .airline,
                    maxPages: 1
                )
                await MainActor.run {
                    self.boardResponse = resp
                    self.boardLoading = false
                }
            } catch {
                await MainActor.run {
                    self.boardError = error.localizedDescription
                    self.boardLoading = false
                }
            }
        }
    }
}

private struct AirportBoardCard: View {
    let flight: FlightAwareFlight

    private var title: String { flight.bestIdent }

    private var route: String {
        let orig = flight.origin?.bestCode ?? "-"
        let dest = flight.destination?.bestCode ?? "-"
        return "\(orig) → \(dest)"
    }

    private var timeText: String {
        let out = FlightAwareTime.short(flight.actualOut)
            ?? FlightAwareTime.short(flight.estimatedOut)
            ?? FlightAwareTime.short(flight.scheduledOut)
        let inn = FlightAwareTime.short(flight.actualIn)
            ?? FlightAwareTime.short(flight.estimatedIn)
            ?? FlightAwareTime.short(flight.scheduledIn)
        if let out, let inn { return "\(out)–\(inn)" }
        return out ?? inn ?? "-"
    }

    private var gateText: String {
        let t = flight.terminalOrigin ?? flight.terminalDestination
        let g = flight.gateOrigin ?? flight.gateDestination
        if t == nil && g == nil { return "T- • G-" }
        return "T\(t ?? "-") • G\(g ?? "-")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline.monospacedDigit())
                Spacer()
                Text(timeText)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Text(route)
                .font(.subheadline.weight(.semibold))

            HStack {
                Text(flight.operatorIata ?? flight.operatorIcao ?? flight.operator ?? "-")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(gateText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 14)
    }
}

// MARK: - Flight Filters View

struct FlightFiltersView: View {
    @Binding var searchRequest: FlightSearchRequest
    let onSearch: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var flightNumber = ""
    @State private var registration = ""
    @State private var aircraftType = ""
    @State private var origin = ""
    @State private var destination = ""
    @State private var altitudeMin = ""
    @State private var altitudeMax = ""
    @State private var speedMin = ""
    @State private var speedMax = ""
    @State private var timeFrom = Date()
    @State private var timeTo = Date()
    @State private var hasTimeFilter = false
    @State private var hasAltitudeFilter = false
    @State private var hasSpeedFilter = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Informações do Voo")) {
                    TextField("Número do Voo", text: $flightNumber)
                    TextField("Registro", text: $registration)
                    TextField("Tipo de Aeronave", text: $aircraftType)
                }
                
                Section(header: Text("Rota")) {
                    TextField("Origem", text: $origin)
                    TextField("Destino", text: $destination)
                }
                
                Section(header: Text("Altitude (pés)")) {
                    Toggle("Filtrar por altitude", isOn: $hasAltitudeFilter)
                    
                    if hasAltitudeFilter {
                        HStack {
                            TextField("Mín", text: $altitudeMin)
                                .keyboardType(.numberPad)
                            TextField("Máx", text: $altitudeMax)
                                .keyboardType(.numberPad)
                        }
                    }
                }
                
                Section(header: Text("Velocidade (nós)")) {
                    Toggle("Filtrar por velocidade", isOn: $hasSpeedFilter)
                    
                    if hasSpeedFilter {
                        HStack {
                            TextField("Mín", text: $speedMin)
                                .keyboardType(.numberPad)
                            TextField("Máx", text: $speedMax)
                                .keyboardType(.numberPad)
                        }
                    }
                }
                
                Section(header: Text("Período")) {
                    Toggle("Filtrar por período", isOn: $hasTimeFilter)
                    
                    if hasTimeFilter {
                        DatePicker("De", selection: $timeFrom)
                        DatePicker("Até", selection: $timeTo)
                    }
                }
                
                Section(header: Text("Resultados")) {
                    Picker("Limitar resultados", selection: Binding(
                        get: { searchRequest.limit ?? 20 },
                        set: { searchRequest.limit = $0 }
                    )) {
                        Text("20").tag(20)
                        Text("50").tag(50)
                        Text("100").tag(100)
                        Text("200").tag(200)
                    }
                }
                
                Section {
                    Button("Limpar Filtros") {
                        clearFilters()
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Buscar") {
                        applyFilters()
                        onSearch()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCurrentFilters()
            }
        }
    }
    
    private func loadCurrentFilters() {
        flightNumber = searchRequest.flightNumber ?? ""
        registration = searchRequest.registration ?? ""
        aircraftType = searchRequest.aircraftType ?? ""
        origin = searchRequest.origin ?? ""
        destination = searchRequest.destination ?? ""
        altitudeMin = searchRequest.altitudeMin != nil ? String(searchRequest.altitudeMin!) : ""
        altitudeMax = searchRequest.altitudeMax != nil ? String(searchRequest.altitudeMax!) : ""
        speedMin = searchRequest.speedMin != nil ? String(searchRequest.speedMin!) : ""
        speedMax = searchRequest.speedMax != nil ? String(searchRequest.speedMax!) : ""
        
        hasAltitudeFilter = searchRequest.altitudeMin != nil || searchRequest.altitudeMax != nil
        hasSpeedFilter = searchRequest.speedMin != nil || searchRequest.speedMax != nil
        hasTimeFilter = searchRequest.timeFrom != nil || searchRequest.timeTo != nil
        
        if let fromStr = searchRequest.timeFrom, let fromDate = Formatters.isoDate.date(from: fromStr) {
            timeFrom = fromDate
        }
        if let toStr = searchRequest.timeTo, let toDate = Formatters.isoDate.date(from: toStr) {
            timeTo = toDate
        }
    }
    
    private func applyFilters() {
        searchRequest.flightNumber = flightNumber.isEmpty ? nil : flightNumber
        searchRequest.registration = registration.isEmpty ? nil : registration
        searchRequest.aircraftType = aircraftType.isEmpty ? nil : aircraftType
        searchRequest.origin = origin.isEmpty ? nil : origin
        searchRequest.destination = destination.isEmpty ? nil : destination
        searchRequest.altitudeMin = altitudeMin.isEmpty ? nil : Int(altitudeMin)
        searchRequest.altitudeMax = altitudeMax.isEmpty ? nil : Int(altitudeMax)
        searchRequest.speedMin = speedMin.isEmpty ? nil : Int(speedMin)
        searchRequest.speedMax = speedMax.isEmpty ? nil : Int(speedMax)
        
        if hasTimeFilter {
            searchRequest.timeFrom = ISO8601DateFormatter().string(from: timeFrom)
            searchRequest.timeTo = ISO8601DateFormatter().string(from: timeTo)
        } else {
            searchRequest.timeFrom = nil
            searchRequest.timeTo = nil
        }
    }
    
    private func clearFilters() {
        searchRequest = FlightSearchRequest()
        flightNumber = ""
        registration = ""
        aircraftType = ""
        origin = ""
        destination = ""
        altitudeMin = ""
        altitudeMax = ""
        speedMin = ""
        speedMax = ""
        hasAltitudeFilter = false
        hasSpeedFilter = false
        hasTimeFilter = false
        timeFrom = Date()
        timeTo = Date()
    }
}

// MARK: - Supporting Views

struct QuickFilterChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.blue : Color(.systemGray6))
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct FlightSearchResultCard: View {
    let flight: SearchFlightResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let flightNum = flight.flight {
                        Text(flightNum)
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    
                    if let reg = flight.registration {
                        Text(reg)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if let type = flight.aircraftType {
                        Text(type)
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    
                    Text(Formatters.relativeDate.localizedString(for: 
                        Formatters.isoDate.date(from: flight.timestamp) ?? Date(), 
                        relativeTo: Date()))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            
            // Route
            if let origin = flight.origin, let destination = flight.destination {
                HStack {
                    Text(origin)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(destination)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                }
            }
            
            // Metrics
            HStack(spacing: 16) {
                if let altitude = flight.altitude {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.caption)
                        Text("\(altitude) ft")
                            .font(.caption)
                            .monospacedDigit()
                    }
                    .foregroundStyle(.blue)
                }
                
                if let speed = flight.speed {
                    HStack(spacing: 4) {
                        Image(systemName: "gauge.high")
                            .font(.caption)
                        Text("\(speed) kt")
                            .font(.caption)
                            .monospacedDigit()
                    }
                    .foregroundStyle(.green)
                }
                
                if let heading = flight.heading {
                    HStack(spacing: 4) {
                        Image(systemName: "location.north")
                            .font(.caption)
                        Text("\(heading)°")
                            .font(.caption)
                            .monospacedDigit()
                    }
                    .foregroundStyle(.orange)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    FlightSearchView()
        .environmentObject(AppState())
}
