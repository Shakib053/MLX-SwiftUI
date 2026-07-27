//
//  SharedWidgetData.swift
//  MLX-SwiftUI
//
//  Created by Kazi Tanjim Shakib on 27/7/26.
//

import Foundation

enum SharedWidgetData {
    static let appGroupID = "group.Shakib053.MLX-SwiftUI"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID)!
    }

    static var activeModelName: String {
        defaults.string(forKey: "activeModelName") ?? "No model selected"
    }

    static func save(activeModelName: String) {
        defaults.set(activeModelName, forKey: "activeModelName")
    }
}
