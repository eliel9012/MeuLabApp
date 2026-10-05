import SwiftUI

/// Card "Perguntar ao laboratório": consulta a RAG do Pi (POST /api/rag/query)
/// e mostra a resposta gerada, quando houver, e os trechos usados como fonte.
struct LabAskCard: View {
    var tint: Color = .accentColor

    @State private var question = ""
    @State private var source: RAGSource = .adsbHistory
    @State private var isLoading = false
    @State private var result: RAGQueryResponse?
    @State private var errorMessage: String?
    @State private var task: Task<Void, Never>?
    @FocusState private var fieldFocused: Bool

    private var trimmedQuestion: String {
        question.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canAsk: Bool { trimmedQuestion.count >= 3 && !isLoading }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            sourcePicker
            inputRow

            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Consultando o laboratório…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            } else if let errorMessage {
                errorView(errorMessage)
            } else if let result {
                resultView(result)
            }
        }
        .padding(18)
        .contentCard(cornerRadius: 22)
        .animation(.snappy, value: isLoading)
        .animation(.snappy, value: result?.question)
        .onDisappear { task?.cancel() }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "text.magnifyingglass")
                .scaledFont(size: 15, weight: .semibold)
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Perguntar ao laboratório")
                    .font(.headline.weight(.semibold))
                Text("Busca no histórico do radar, da rádio e nas notas.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var sourcePicker: some View {
        Picker("Fonte", selection: $source) {
            ForEach(RAGSource.allCases) { item in
                Label(item.label, systemImage: item.symbol).tag(item)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: source) { _, _ in
            result = nil
            errorMessage = nil
        }
    }

    private var inputRow: some View {
        HStack(spacing: 10) {
            TextField(source.placeholder, text: $question, axis: .vertical)
                .lineLimit(1...3)
                .font(.subheadline)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.search)
                .focused($fieldFocused)
                .onSubmit(ask)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .materialCard(cornerRadius: 14)

            Button(action: ask) {
                Image(systemName: "arrow.up")
                    .scaledFont(size: 15, weight: .bold)
                    .frame(width: 22, height: 22)
            }
            .adaptiveGlassProminentButton()
            .disabled(!canAsk)
            .accessibilityLabel("Perguntar")
        }
    }

    @ViewBuilder
    private func resultView(_ result: RAGQueryResponse) -> some View {
        let sources = result.relevantSources
        VStack(alignment: .leading, spacing: 12) {
            if let answer = result.generatedAnswer {
                Text(answer)
                    .font(.subheadline)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            } else if result.answerMode == "not_found" || sources.isEmpty {
                Label("Não encontrei nada relevante em \(source.label.lowercased()). Tente outras palavras ou outra fonte.",
                      systemImage: "questionmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if result.llmUnavailable && !sources.isEmpty {
                Label("IA do laboratório indisponível — mostrando os trechos encontrados.",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if !sources.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(result.generatedAnswer == nil ? "Trechos encontrados" : "Fontes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    ForEach(sources) { item in
                        sourceRow(item)
                    }
                }
            }
        }
        .transition(.opacity)
    }

    private func sourceRow(_ item: RAGSourceItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Spacer(minLength: 4)
                Text(item.originLabel)
                    .scaledFont(size: 10, weight: .semibold)
                    .foregroundStyle(tint)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(tint.opacity(0.14), in: Capsule())
            }
            Text(item.excerpt)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .materialCard(cornerRadius: 14)
        .accessibilityElement(children: .combine)
    }

    private func errorView(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text(message)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Tentar de novo", action: ask)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .disabled(!canAsk)
            }
        }
        .transition(.opacity)
    }

    // MARK: - Actions

    private func ask() {
        guard canAsk else { return }
        let text = trimmedQuestion
        let selected = source
        fieldFocused = false
        errorMessage = nil
        isLoading = true
        task?.cancel()
        task = Task {
            do {
                let response = try await APIService.shared.queryRAG(question: text, source: selected)
                guard !Task.isCancelled else { return }
                result = response
            } catch {
                guard !Task.isCancelled else { return }
                result = nil
                errorMessage = Self.friendlyMessage(for: error)
            }
            isLoading = false
        }
    }

    private static func friendlyMessage(for error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .unauthorized:
                return "O app não está autorizado a consultar o laboratório. Confira o token nas configurações."
            case .serverError(400):
                return "Não entendi a pergunta. Escreva pelo menos algumas palavras."
            case .serverError(let code) where code >= 500:
                return "O laboratório não conseguiu responder agora. Tente de novo em instantes."
            case .serverError:
                return "O laboratório recusou a consulta. Tente de novo mais tarde."
            case .decodingError:
                return "A resposta do laboratório veio num formato inesperado."
            case .networkError(let underlying):
                if let urlError = underlying as? URLError {
                    switch urlError.code {
                    case .timedOut:
                        return "O laboratório demorou demais para responder. Tente de novo."
                    case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                        return "Sem conexão com a internet."
                    case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                        return "Não foi possível alcançar o laboratório."
                    case .cancelled:
                        return "Consulta cancelada."
                    default:
                        break
                    }
                }
                return "Falha de rede ao consultar o laboratório."
            default:
                break
            }
        }
        return "Não foi possível consultar o laboratório agora."
    }
}

#Preview {
    LabAskCard()
        .padding()
}
