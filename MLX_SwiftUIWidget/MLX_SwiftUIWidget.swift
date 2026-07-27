//
//  MLX_SwiftUIWidget.swift
//  MLX_SwiftUIWidget
//
//  Created by Kazi Tanjim Shakib on 27/7/26.
//

import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: .now,
            configuration: ConfigurationAppIntent(),
            activeModelName: "Qwen"
        )
    }

    func snapshot(
        for configuration: ConfigurationAppIntent,
        in context: Context
    ) async -> SimpleEntry {
        let modelName = SharedWidgetData.activeModelName

        print("WIDGET read model:", modelName)

        return SimpleEntry(
            date: .now,
            configuration: configuration,
            activeModelName: modelName
        )
    }

    func timeline(
        for configuration: ConfigurationAppIntent,
        in context: Context
    ) async -> Timeline<SimpleEntry> {
        let modelName = SharedWidgetData.activeModelName

        print("WIDGET read model:", modelName)

        let entry = SimpleEntry(
            date: .now,
            configuration: configuration,
            activeModelName: modelName
        )

        return Timeline(
            entries: [entry],
            policy: .after(Date().addingTimeInterval(15 * 60))
        )
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let activeModelName: String
}

struct MLX_SwiftUIWidgetEntryView: View {
    let entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "cpu")
                .font(.title2)
                .foregroundStyle(.blue)

            Text("Active model")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(entry.activeModelName)
                .font(.headline)
                .lineLimit(2)

            Spacer()
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .padding()
    }
}

struct MLX_SwiftUIWidget: Widget {
    let kind: String = "MLX_SwiftUIWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: Provider()
        ) { entry in
            MLX_SwiftUIWidgetEntryView(entry: entry)
//                .containerBackground(.fill.tertiary, for: .widget)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [
                            Color(red: 0.01, green: 0.18, blue: 0.22),
                            Color(red: 0.00, green: 0.38, blue: 0.32)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
    }
}

#Preview(as: .systemSmall) {
    MLX_SwiftUIWidget()
} timeline: {
    SimpleEntry(
        date: .now,
        configuration: ConfigurationAppIntent(),
        activeModelName: "Qwen"
    )
}
