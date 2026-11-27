import OSLog

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "Shakib053.Private-AI-Model-Hub"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let chat = Logger(subsystem: subsystem, category: "chat")
}
