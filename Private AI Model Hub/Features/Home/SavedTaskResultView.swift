import SwiftUI
import UIKit

struct SavedTaskResultView: View {
    let item: SavedTaskResult
    @State private var showsSource = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(item.resultText).textSelection(.enabled)
                Button("View source") { showsSource = true }
                HStack {
                    Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = item.resultText }
                    ShareLink(item: item.resultText) { Label("Share", systemImage: "square.and.arrow.up") }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(item.title)
        .mainTabBar()
        .background(AppPalette.background)
        .sheet(isPresented: $showsSource) {
            NavigationStack {
                ScrollView { Text(item.sourceText).frame(maxWidth: .infinity, alignment: .leading).padding() }
                    .navigationTitle("Source")
                    .toolbar { Button("Done") { showsSource = false } }
            }
        }
    }
}
