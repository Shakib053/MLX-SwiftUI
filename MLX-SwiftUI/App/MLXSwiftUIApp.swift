//
//  MLXSwiftUIApp.swift
//  MLX-SwiftUI
//
//  Created by Kazi Tanjim Shakib on 4/6/26.
//

import SwiftUI
import SwiftData

@main
struct MLXSwiftUIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Conversation.self, PersistedMessage.self])
    }
}
