//
//  PrivateAIModelHubApp.swift
//  Private AI Model Hub
//
//  Created by Kazi Tanjim Shakib on 4/6/26.
//

import SwiftUI
import SwiftData

@main
struct PrivateAIModelHubApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Conversation.self, PersistedMessage.self, SavedTaskResult.self])
    }
}
