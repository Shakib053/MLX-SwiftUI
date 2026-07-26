import Foundation

enum ChatResponseSanitizer {
    private static let unavailableAnswer = "I could not produce a final answer. Please try again."

    static func clean(_ response: String) -> String {
        let original = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty else { return original }

        let protected = protectingFencedCodeBlocks(in: original)
        var cleaned = protected.text
        cleaned = extractingFinalAnswer(from: cleaned)
        guard !cleaned.isEmpty else { return unavailableAnswer }

        cleaned = replacingTemplateTokens(in: cleaned)
        cleaned = keepingFinalAssistantTurn(from: cleaned)
        cleaned = removingRoleWrapperLines(from: cleaned)
        cleaned = removingLeadingRoleLabels(from: cleaned)
        cleaned = restoringFencedCodeBlocks(in: cleaned, blocks: protected.blocks)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? unavailableAnswer : cleaned
    }

    private static func protectingFencedCodeBlocks(in text: String) -> (text: String, blocks: [String]) {
        var remaining = text
        var protected = ""
        var blocks: [String] = []

        while let openingFence = remaining.range(of: "```") {
            protected += String(remaining[..<openingFence.lowerBound])
            let afterOpeningFence = openingFence.upperBound..<remaining.endIndex

            guard let closingFence = remaining.range(of: "```", range: afterOpeningFence) else {
                protected += String(remaining[openingFence.lowerBound...])
                return (protected, blocks)
            }

            let blockRange = openingFence.lowerBound..<closingFence.upperBound
            let placeholder = "__CHAT_CODE_BLOCK_\(blocks.count)__"
            blocks.append(String(remaining[blockRange]))
            protected += placeholder
            remaining = String(remaining[closingFence.upperBound...])
        }

        protected += remaining
        return (protected, blocks)
    }

    private static func restoringFencedCodeBlocks(in text: String, blocks: [String]) -> String {
        var restored = text

        for index in blocks.indices {
            restored = restored.replacingOccurrences(
                of: "__CHAT_CODE_BLOCK_\(index)__",
                with: blocks[index]
            )
        }

        return restored
    }

    private static func extractingFinalAnswer(from text: String) -> String {
        if let finalThinkTag = text.range(of: "</think>", options: [.caseInsensitive, .backwards]) {
            return String(text[finalThinkTag.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let withoutPairedThinkingBlocks = text.replacingOccurrences(
            of: #"(?is)<think>.*?</think>"#,
            with: "",
            options: .regularExpression
        )

        if withoutPairedThinkingBlocks.range(
            of: #"(?is)<think\b[^>]*>"#,
            options: .regularExpression
        ) != nil {
            return ""
        }

        return withoutPairedThinkingBlocks
    }

    private static func replacingTemplateTokens(in text: String) -> String {
        var cleaned = text
        let tokens = [
            "<|im_start|>",
            "<|im_end|>",
            "<|assistant|>",
            "<|user|>",
            "<|system|>",
            "<s>",
            "</s>"
        ]

        for token in tokens {
            cleaned = cleaned.replacingOccurrences(of: token, with: "\n")
        }

        return cleaned
    }

    private static func keepingFinalAssistantTurn(from text: String) -> String {
        let pattern = #"(?im)^\s*(?:\*\*)?assistant(?:\*\*)?\s*:?\s*$|^\s*(?:\*\*)?assistant(?:\*\*)?\s*:\s*"#
        guard let match = text.range(of: pattern, options: .regularExpression) else {
            return text
        }

        var searchRange = match.upperBound..<text.endIndex
        var lastMatch = match

        while let next = text.range(of: pattern, options: .regularExpression, range: searchRange) {
            lastMatch = next
            searchRange = next.upperBound..<text.endIndex
        }

        return String(text[lastMatch.upperBound...])
    }

    private static func removingRoleWrapperLines(from text: String) -> String {
        let roleNames: Set<String> = ["assistant", "user", "system"]
        let filteredLines = text.split(separator: "\n", omittingEmptySubsequences: false).filter { line in
            let normalized = line.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "*`_: "))
                .lowercased()
            return !roleNames.contains(normalized)
        }

        return filteredLines.joined(separator: "\n")
    }

    private static func removingLeadingRoleLabels(from text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"(?is)^\s*(?:\*\*)?(?:assistant|system|user)(?:\*\*)?\s*:\s*"#

        while let range = cleaned.range(of: pattern, options: .regularExpression) {
            cleaned.removeSubrange(range)
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return cleaned
    }
}
