import SwiftUI

@main
struct XPostingApp: App {
    @StateObject private var viewModel = ComposerViewModel.live()

    var body: some Scene {
        MenuBarExtra("X Posting", systemImage: "square.and.pencil") {
            MenuBarContentView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        WindowGroup(id: "composer") {
            ComposerWindowView(viewModel: viewModel)
        }
        .defaultSize(width: 980, height: 640)

        Window("x-posting Settings", id: "settings") {
            SettingsView(viewModel: viewModel)
        }
        .defaultSize(width: 700, height: 520)
    }
}
