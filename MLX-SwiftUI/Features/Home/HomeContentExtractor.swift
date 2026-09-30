import Foundation
import ImageIO
import PDFKit
import Vision

enum HomeImportError: LocalizedError {
    case noText
    case unreadableFile
    case tooLong

    var errorDescription: String? {
        switch self {
        case .noText: "No readable text was found. Try another image or document."
        case .unreadableFile: "This file could not be read. Choose a PDF, TXT, or Markdown file."
        case .tooLong: "This content is too long for one chat request. Shorten it to 10,000 characters."
        }
    }
}

enum HomeContentExtractor {
    static func document(from url: URL) async throws -> String {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        let text: String
        if url.pathExtension.lowercased() == "pdf" {
            guard let document = PDFDocument(data: data) else { throw HomeImportError.unreadableFile }
            text = (0..<document.pageCount).compactMap { index in
                guard let pageText = document.page(at: index)?.string,
                      !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                return "Page \(index + 1):\n\(pageText)"
            }.joined(separator: "\n\n")
        } else {
            guard let decoded = String(data: data, encoding: .utf8) else {
                throw HomeImportError.unreadableFile
            }
            text = decoded
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw HomeImportError.noText }
        return trimmed
    }

    static func image(from data: Data) async throws -> String {
        try await Task.detached {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                throw HomeImportError.unreadableFile
            }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            try VNImageRequestHandler(cgImage: image).perform([request])
            let text = (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { throw HomeImportError.noText }
            return text
        }.value
    }
}
