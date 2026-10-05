import Foundation

// ============================================================
// NOTAS — cliente de /api/notes (bot2/api/notes_api.py)
// Soft delete no servidor: DELETE marca deleted=1 e apaga os anexos.
// ============================================================

// MARK: - Modelos

struct NoteAttachment: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let noteId: String
    let originalName: String
    let contentType: String?
    let sizeBytes: Int?
    let createdAt: String?
    let downloadUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case noteId = "note_id"
        case originalName = "original_name"
        case contentType = "content_type"
        case sizeBytes = "size_bytes"
        case createdAt = "created_at"
        case downloadUrl = "download_url"
    }
}

struct NoteItem: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var title: String
    var body: String
    var tags: [String]
    var pinned: Bool
    var color: String?
    let createdAt: String?
    let updatedAt: String?
    var attachments: [NoteAttachment]

    enum CodingKeys: String, CodingKey {
        case id, title, body, tags, pinned, color, attachments
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        body = (try? c.decode(String.self, forKey: .body)) ?? ""
        tags = (try? c.decode([String].self, forKey: .tags)) ?? []
        pinned = (try? c.decode(Bool.self, forKey: .pinned)) ?? false
        color = try? c.decodeIfPresent(String.self, forKey: .color)
        createdAt = try? c.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try? c.decodeIfPresent(String.self, forKey: .updatedAt)
        attachments = (try? c.decode([NoteAttachment].self, forKey: .attachments)) ?? []
    }

    /// Título exibível (notas sem título usam a primeira linha do corpo).
    var displayTitle: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        let firstLine = body.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return firstLine.isEmpty ? "Sem título" : firstLine
    }

    var updatedDate: Date? { NoteDates.parse(updatedAt) }
}

enum NoteDates {
    nonisolated(unsafe) private static let frac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    nonisolated(unsafe) private static let plain = ISO8601DateFormatter()

    static func parse(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        return frac.date(from: s) ?? plain.date(from: s)
    }
}

private struct NotesListResponse: Decodable {
    let items: [NoteItem]
}

private struct NotesAttachmentsResponse: Decodable {
    let items: [NoteAttachment]
}

// MARK: - API

extension APIService {
    /// GET /api/notes — `q` filtra título/corpo no servidor (case-insensitive).
    func fetchNotes(query: String? = nil, limit: Int = 200, offset: Int = 0) async throws -> [NoteItem] {
        var comps = URLComponents()
        var items = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]
        if let q = query?.trimmingCharacters(in: .whitespacesAndNewlines), !q.isEmpty {
            items.append(URLQueryItem(name: "q", value: q))
        }
        comps.queryItems = items
        let resp: NotesListResponse = try await fetch("/api/notes?\(comps.percentEncodedQuery ?? "")")
        return resp.items
    }

    /// GET /api/notes/{id}
    func fetchNote(id: String) async throws -> NoteItem {
        try await fetch("/api/notes/\(id)")
    }

    /// POST /api/notes
    func createNote(title: String, body: String, tags: [String], pinned: Bool) async throws -> NoteItem {
        var req = try makeRequest(path: "/api/notes")
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "title": title, "body": body, "tags": tags, "pinned": pinned,
        ] as [String: Any])
        let (data, _) = try await performRequest(req, retries: 0)
        return try decodeNote(data)
    }

    /// PUT /api/notes/{id}
    func updateNote(id: String, title: String, body: String, tags: [String], pinned: Bool) async throws -> NoteItem {
        var req = try makeRequest(path: "/api/notes/\(id)")
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "title": title, "body": body, "tags": tags, "pinned": pinned,
        ] as [String: Any])
        let (data, _) = try await performRequest(req)
        return try decodeNote(data)
    }

    /// DELETE /api/notes/{id}
    func deleteNote(id: String) async throws {
        var req = try makeRequest(path: "/api/notes/\(id)")
        req.httpMethod = "DELETE"
        _ = try await performRequest(req, retries: 0)
    }

    /// GET /api/notes/{id}/attachments
    func fetchNoteAttachments(noteId: String) async throws -> [NoteAttachment] {
        let resp: NotesAttachmentsResponse = try await fetch("/api/notes/\(noteId)/attachments")
        return resp.items
    }

    /// GET /api/notes/{id}/attachments/{aid} → grava em tmp e devolve a URL local.
    func downloadNoteAttachment(_ att: NoteAttachment) async throws -> URL {
        var req = try makeRequest(path: "/api/notes/\(att.noteId)/attachments/\(att.id)")
        req.setValue("*/*", forHTTPHeaderField: "Accept")
        let (data, _) = try await performRequest(req)
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("notes-attachments", isDirectory: true)
            .appendingPathComponent(att.id, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let safe = att.originalName.replacingOccurrences(of: "/", with: "_")
        let url = dir.appendingPathComponent(safe.isEmpty ? "anexo" : safe)
        try data.write(to: url, options: .atomic)
        return url
    }

    /// POST /api/notes/{id}/attachments (multipart, campo "file")
    func uploadNoteAttachment(
        noteId: String, data: Data, filename: String, contentType: String
    ) async throws -> NoteAttachment {
        let boundary = "Boundary-\(UUID().uuidString)"
        var req = try makeRequest(path: "/api/notes/\(noteId)/attachments")
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let safeName = filename.replacingOccurrences(of: "\"", with: "_")
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(safeName)\"\r\n".utf8))
        body.append(Data("Content-Type: \(contentType)\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        req.httpBody = body
        let (resp, _) = try await performRequest(req, retries: 0)
        do {
            return try JSONDecoder().decode(NoteAttachment.self, from: resp)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    /// DELETE /api/notes/{id}/attachments/{aid}
    func deleteNoteAttachment(noteId: String, attachmentId: String) async throws {
        var req = try makeRequest(path: "/api/notes/\(noteId)/attachments/\(attachmentId)")
        req.httpMethod = "DELETE"
        _ = try await performRequest(req, retries: 0)
    }

    private func decodeNote(_ data: Data) throws -> NoteItem {
        do {
            return try JSONDecoder().decode(NoteItem.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
