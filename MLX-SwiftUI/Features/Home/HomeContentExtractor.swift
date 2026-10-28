import Foundation
import ImageIO
import PDFKit
import Vision

enum HomeImportError: LocalizedError {
    case noText
    case unreadableFile
    case tooLong
    case fileTooLarge
    case tooManyPages

    nonisolated var errorDescription: String? {
        switch self {
        case .noText: String(localized: "No readable text was found. Try another image or document.")
        case .unreadableFile: String(localized: "This file could not be read. Choose a PDF, TXT, or Markdown file.")
        case .fileTooLarge: String(localized: "This file is too large. Choose a document of 10 MB or less.")
        case .tooManyPages: String(localized: "This PDF has too many pages. Choose a document with 100 pages or fewer.")
        case .tooLong: String(localized: "This content is too long for one chat request. Shorten it to 10,000 characters.")
        }
    }
}

enum HomeContentExtractor {
    nonisolated static func document(from url: URL) async throws -> String {
        let worker = Task.detached(priority: .userInitiated) {
            try extractDocument(from: url)
        }
        return try await withTaskCancellationHandler {
            let text = try await worker.value
            try Task.checkCancellation()
            return text
        } onCancel: {
            worker.cancel()
        }
    }

    nonisolated private static func extractDocument(from url: URL) throws -> String {
        try Task.checkCancellation()
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }

        // Bound the actual read, including files whose reported size changes.
        let byteLimit = 10_000_000
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = Data()
        while true {
            try Task.checkCancellation()
            guard let chunk = try handle.read(upToCount: min(65_536, byteLimit + 1 - data.count)),
                  !chunk.isEmpty else { break }
            data.append(chunk)
            guard data.count <= byteLimit else { throw HomeImportError.fileTooLarge }
        }
        try Task.checkCancellation()

        let text: String
        if url.pathExtension.lowercased() == "pdf" {
            guard let document = PDFDocument(data: data), !document.isLocked else {
                throw HomeImportError.unreadableFile
            }
            guard document.pageCount <= 100 else { throw HomeImportError.tooManyPages }
            var extracted = ""
            for index in 0..<document.pageCount {
                try Task.checkCancellation()
                let pageText: String? = autoreleasepool {
                    document.page(at: index)?.string?.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                try Task.checkCancellation()
                guard let pageText, !pageText.isEmpty else { continue }
                guard pageText.count <= 10_000 else { throw HomeImportError.tooLong }
                let section = String(localized: "Page \(index + 1):\n\(pageText)")
                let separator = extracted.isEmpty ? "" : "\n\n"
                guard extracted.count + separator.count + section.count <= 10_000 else {
                    throw HomeImportError.tooLong
                }
                extracted += separator + section
            }
            text = extracted
        } else {
            guard let decoded = String(data: data, encoding: .utf8) else {
                throw HomeImportError.unreadableFile
            }
            text = decoded
        }
        try Task.checkCancellation()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw HomeImportError.noText }
        guard trimmed.count <= 10_000 else { throw HomeImportError.tooLong }
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
