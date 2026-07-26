//
//  MLX_SwiftUIWidgetLiveActivity.swift
//  MLX_SwiftUIWidget
//
//  Created by Kazi Tanjim Shakib on 27/7/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct MLX_SwiftUIWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct MLX_SwiftUIWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MLX_SwiftUIWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension MLX_SwiftUIWidgetAttributes {
    fileprivate static var preview: MLX_SwiftUIWidgetAttributes {
        MLX_SwiftUIWidgetAttributes(name: "World")
    }
}

extension MLX_SwiftUIWidgetAttributes.ContentState {
    fileprivate static var smiley: MLX_SwiftUIWidgetAttributes.ContentState {
        MLX_SwiftUIWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: MLX_SwiftUIWidgetAttributes.ContentState {
         MLX_SwiftUIWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: MLX_SwiftUIWidgetAttributes.preview) {
   MLX_SwiftUIWidgetLiveActivity()
} contentStates: {
    MLX_SwiftUIWidgetAttributes.ContentState.smiley
    MLX_SwiftUIWidgetAttributes.ContentState.starEyes
}
