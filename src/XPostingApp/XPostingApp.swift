import AppKit
import SwiftUI

@main
struct XPostingApp: App {
    @StateObject private var viewModel = ComposerViewModel.live()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
        if let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
           let iconImage = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = iconImage
        }
    }

    var body: some Scene {
        MenuBarExtra("X Posting", systemImage: "square.and.pencil") {
            MenuBarContentView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        Window("x-posting Settings", id: "settings") {
            SettingsView(viewModel: viewModel)
        }
        .defaultSize(width: 700, height: 520)
    }
}
