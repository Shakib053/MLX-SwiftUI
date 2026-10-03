import OSLog

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "MLX-SwiftUI"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let chat = Logger(subsystem: subsystem, category: "chat")
    static let widget = Logger(subsystem: subsystem, category: "widget")
}
