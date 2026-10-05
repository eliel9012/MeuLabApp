import QuickLook
import SwiftUI
import UniformTypeIdentifiers

// ============================================================
// NOTAS — lista, detalhe, edição e anexos (/api/notes)
// ============================================================

// MARK: - Lista

struct NotesView: View {
    @State private var notes: [NoteItem] = []
    @State private var query = ""
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var errorMessage: String?
    @State private var showEditor = false

    var body: some View {
        // No NavigationStack here: the tab is hosted by the "Mais" navigation on
        // iPhone and by the split view on iPad; a second stack stacks a second bar.
        Group {
            content
                .navigationTitle("Notas")
                .navigationBarTitleDisplayMode(.inline)
                // Title as a principal item: the "Mais" navigation bar shows only that,
                // next to the back button.
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Notas").font(.headline)
                    }
                }
                .searchable(text: $query, prompt: "Buscar notas")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showEditor = true
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                        .accessibilityLabel("Nova nota")
                    }
                }
                .sheet(isPresented: $showEditor) {
                    NoteEditorView(note: nil) { created in
                        notes.insert(created, at: 0)
                        notes = sorted(notes)
                    }
                }
        }
        // Recarrega ao digitar (debounce de 350 ms; a troca de `query` cancela a tarefa anterior).
        .task(id: query) {
            if hasLoaded {
                try? await Task.sleep(nanoseconds: 350_000_000)
                if Task.isCancelled { return }
            }
            await load()
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && notes.isEmpty {
            ProgressView("Carregando notas…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage, notes.isEmpty {
            ContentUnavailableView {
                Label("Não foi possível carregar", systemImage: "wifi.exclamationmark")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Tentar novamente") { Task { await load() } }
                    .adaptiveGlassProminentButton()
            }
        } else if notes.isEmpty {
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                ContentUnavailableView(
                    "Nenhuma nota",
                    systemImage: "note.text",
                    description: Text("Toque em novo para criar sua primeira nota.")
                )
            } else {
                ContentUnavailableView.search(text: query)
            }
        } else {
            List {
                ForEach(notes) { note in
                    NavigationLink {
                        NoteDetailView(
                            note: note,
                            onUpdate: { updated in
                                if let i = notes.firstIndex(where: { $0.id == updated.id }) {
                                    notes[i] = updated
                                    notes = sorted(notes)
                                }
                            },
                            onDelete: { id in notes.removeAll { $0.id == id } }
                        )
                    } label: {
                        NoteRow(note: note)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable { await load() }
        }
    }

    private func sorted(_ list: [NoteItem]) -> [NoteItem] {
        list.sorted {
            if $0.pinned != $1.pinned { return $0.pinned }
            return ($0.updatedDate ?? .distantPast) > ($1.updatedDate ?? .distantPast)
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await APIService.shared.fetchNotes(query: query)
            if Task.isCancelled { return }
            notes = result
            errorMessage = nil
            hasLoaded = true
        } catch {
            if Task.isCancelled || (error as? URLError)?.code == .cancelled { return }
            errorMessage = error.localizedDescription
            hasLoaded = true
        }
    }
}

// MARK: - Linha

private struct NoteRow: View {
    let note: NoteItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if note.pinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Text(note.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
            }
            if !note.body.isEmpty {
                Text(note.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            HStack(spacing: 8) {
                if let date = note.updatedDate {
                    Text(date, format: .relative(presentation: .named))
                }
                if !note.attachments.isEmpty {
                    Label("\(note.attachments.count)", systemImage: "paperclip")
                        .labelStyle(.titleAndIcon)
                }
                if let tag = note.tags.first {
                    Text("#\(tag)").lineLimit(1)
                    if note.tags.count > 1 { Text("+\(note.tags.count - 1)") }
                }
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Detalhe

struct NoteDetailView: View {
    @State var note: NoteItem
    let onUpdate: (NoteItem) -> Void
    let onDelete: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showEditor = false
    @State private var confirmDelete = false
    @State private var showImporter = false
    @State private var busyMessage: String?
    @State private var errorMessage: String?
    @State private var previewURL: URL?
    @State private var shareURL: URL?
    @State private var attachmentToDelete: NoteAttachment?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                bodySection
                attachmentsSection
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(note.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button { showEditor = true } label: { Image(systemName: "pencil") }
                    .accessibilityLabel("Editar")
                Button(role: .destructive) { confirmDelete = true } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Apagar")
            }
        }
        .sheet(isPresented: $showEditor) {
            NoteEditorView(note: note) { updated in
                note = updated
                onUpdate(updated)
            }
        }
        .sheet(isPresented: Binding(get: { shareURL != nil }, set: { if !$0 { shareURL = nil } })) {
            if let shareURL { ShareSheet(activityItems: [shareURL]) }
        }
        .quickLookPreview($previewURL)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.item]) { result in
            Task { await handleImport(result) }
        }
        .confirmationDialog("Apagar esta nota?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Apagar nota e anexos", role: .destructive) { Task { await deleteNote() } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esta ação não pode ser desfeita.")
        }
        .confirmationDialog(
            "Apagar anexo?",
            isPresented: Binding(get: { attachmentToDelete != nil }, set: { if !$0 { attachmentToDelete = nil } }),
            titleVisibility: .visible,
            presenting: attachmentToDelete
        ) { att in
            Button("Apagar \(att.originalName)", role: .destructive) { Task { await deleteAttachment(att) } }
            Button("Cancelar", role: .cancel) {}
        }
        .alert("Erro", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .task { await refresh() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(note.displayTitle)
                .font(.title2.weight(.semibold))
            if let date = note.updatedDate {
                Text("Atualizada \(date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if !note.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(note.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bodySection: some View {
        Group {
            if note.body.isEmpty {
                Text("Nota sem conteúdo.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if NoteMarkdown.looksLikeMarkdown(note.body) {
                NoteMarkdownView(text: note.body)
            } else {
                Text(note.body)
                    .font(.body)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .contentCard(cornerRadius: 16)
    }

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Anexos", systemImage: "paperclip")
                    .font(.headline)
                Spacer()
                if let busyMessage {
                    ProgressView().controlSize(.small)
                    Text(busyMessage).font(.caption).foregroundStyle(.secondary)
                }
                Button {
                    showImporter = true
                } label: {
                    Image(systemName: "plus.circle")
                }
                .accessibilityLabel("Adicionar anexo")
                .disabled(busyMessage != nil)
            }
            if note.attachments.isEmpty {
                Text("Nenhum anexo.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(note.attachments) { att in
                    HStack(spacing: 10) {
                        Button {
                            Task { await open(att, share: false) }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: Self.icon(for: att))
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(att.originalName)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                        .foregroundStyle(.primary)
                                    if let size = att.sizeBytes {
                                        Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Menu {
                            Button { Task { await open(att, share: false) } } label: {
                                Label("Abrir", systemImage: "eye")
                            }
                            Button { Task { await open(att, share: true) } } label: {
                                Label("Compartilhar", systemImage: "square.and.arrow.up")
                            }
                            Button(role: .destructive) { attachmentToDelete = att } label: {
                                Label("Apagar", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                    .padding(10)
                    .materialCard(cornerRadius: 12)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func icon(for att: NoteAttachment) -> String {
        let ct = (att.contentType ?? "").lowercased()
        let ext = (att.originalName as NSString).pathExtension.lowercased()
        if ct.hasPrefix("image/") || ["png", "jpg", "jpeg", "heic", "gif"].contains(ext) { return "photo" }
        if ct == "application/pdf" || ext == "pdf" { return "doc.richtext" }
        if ct.hasPrefix("video/") { return "film" }
        if ct.hasPrefix("audio/") { return "waveform" }
        if ct.hasPrefix("text/") || ext == "txt" || ext == "md" { return "doc.text" }
        return "doc"
    }

    // MARK: Ações

    private func refresh() async {
        if let fresh = try? await APIService.shared.fetchNote(id: note.id) {
            note = fresh
            onUpdate(fresh)
        }
    }

    private func open(_ att: NoteAttachment, share: Bool) async {
        busyMessage = "Baixando…"
        defer { busyMessage = nil }
        do {
            let url = try await APIService.shared.downloadNoteAttachment(att)
            if share { shareURL = url } else { previewURL = url }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteNote() async {
        do {
            try await APIService.shared.deleteNote(id: note.id)
            onDelete(note.id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteAttachment(_ att: NoteAttachment) async {
        do {
            try await APIService.shared.deleteNoteAttachment(noteId: note.id, attachmentId: att.id)
            note.attachments.removeAll { $0.id == att.id }
            onUpdate(note)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleImport(_ result: Result<URL, Error>) async {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let url):
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            busyMessage = "Enviando…"
            defer { busyMessage = nil }
            do {
                let data = try Data(contentsOf: url)
                let type = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
                    ?? "application/octet-stream"
                let att = try await APIService.shared.uploadNoteAttachment(
                    noteId: note.id, data: data, filename: url.lastPathComponent, contentType: type)
                note.attachments.append(att)
                onUpdate(note)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Editor

struct NoteEditorView: View {
    let note: NoteItem?
    let onSaved: (NoteItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var text: String
    @State private var tagsText: String
    @State private var pinned: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(note: NoteItem?, onSaved: @escaping (NoteItem) -> Void) {
        self.note = note
        self.onSaved = onSaved
        _title = State(initialValue: note?.title ?? "")
        _text = State(initialValue: note?.body ?? "")
        _tagsText = State(initialValue: (note?.tags ?? []).joined(separator: ", "))
        _pinned = State(initialValue: note?.pinned ?? false)
    }

    private var canSave: Bool {
        !isSaving && !(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Título") {
                    TextField("Título", text: $title)
                }
                Section("Conteúdo (Markdown opcional)") {
                    TextEditor(text: $text)
                        .frame(minHeight: 220)
                        .font(.body)
                }
                Section("Tags") {
                    TextField("separadas por vírgula", text: $tagsText)
                        .textInputAutocapitalization(.never)
                }
                Section {
                    Toggle("Fixar no topo", isOn: $pinned)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red).font(.footnote) }
                }
            }
            .navigationTitle(note == nil ? "Nova nota" : "Editar nota")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Salvar") { Task { await save() } }
                            .disabled(!canSave)
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let saved: NoteItem
            if let note {
                saved = try await APIService.shared.updateNote(
                    id: note.id, title: t, body: text, tags: tags, pinned: pinned)
            } else {
                saved = try await APIService.shared.createNote(
                    title: t, body: text, tags: tags, pinned: pinned)
            }
            onSaved(saved)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Markdown simples

enum NoteMarkdown {
    /// Heurística barata: cabeçalho, lista, citação, negrito, código ou link.
    static func looksLikeMarkdown(_ s: String) -> Bool {
        s.range(
            of: #"(^|\n)(#{1,6} |[-*] |> |```)|\*\*[^*\n]+\*\*|`[^`\n]+`|\[[^\]\n]+\]\([^)\n]+\)"#,
            options: .regularExpression) != nil
    }
}

private struct NoteMarkdownView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(blocks().enumerated()), id: \.offset) { _, b in
                render(b)
            }
        }
        .textSelection(.enabled)
    }

    private enum Block {
        case heading(Int, String)
        case bullet(String)
        case quote(String)
        case code(String)
        case paragraph(String)
        case spacer
    }

    private func blocks() -> [Block] {
        var out: [Block] = []
        var inCode = false
        var code: [String] = []
        for raw in text.components(separatedBy: "\n") {
            if raw.hasPrefix("```") {
                if inCode { out.append(.code(code.joined(separator: "\n"))); code = [] }
                inCode.toggle()
                continue
            }
            if inCode { code.append(raw); continue }
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { out.append(.spacer) }
            else if let m = line.range(of: #"^#{1,6} "#, options: .regularExpression) {
                out.append(.heading(line.distance(from: m.lowerBound, to: m.upperBound) - 1, String(line[m.upperBound...])))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                out.append(.bullet(String(line.dropFirst(2))))
            } else if line.hasPrefix("> ") {
                out.append(.quote(String(line.dropFirst(2))))
            } else { out.append(.paragraph(line)) }
        }
        if inCode && !code.isEmpty { out.append(.code(code.joined(separator: "\n"))) }
        return out
    }

    private func inline(_ s: String) -> AttributedString {
        let opts = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: s, options: opts)) ?? AttributedString(s)
    }

    @ViewBuilder
    private func render(_ b: Block) -> some View {
        switch b {
        case .heading(let level, let s):
            Text(inline(s))
                .font(level == 1 ? .title2.bold() : level == 2 ? .title3.bold() : .headline)
                .padding(.top, 4)
        case .bullet(let s):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("•")
                Text(inline(s))
            }
        case .quote(let s):
            Text(inline(s))
                .foregroundStyle(.secondary)
                .padding(.leading, 10)
                .overlay(alignment: .leading) {
                    Rectangle().fill(.secondary.opacity(0.5)).frame(width: 3)
                }
        case .code(let s):
            Text(s)
                .font(.system(.footnote, design: .monospaced))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
        case .paragraph(let s):
            Text(inline(s)).font(.body)
        case .spacer:
            Color.clear.frame(height: 4)
        }
    }
}
