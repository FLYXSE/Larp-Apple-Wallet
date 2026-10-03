import SwiftUI

@main
struct AppleWalletCloneApp: App {
    @StateObject private var store = WalletStore()
    @StateObject private var settings = SettingsStore()

    var body: some Scene {
        WindowGroup {
            WalletHome()
                .environmentObject(store)
                .environmentObject(settings)
                .preferredColorScheme(.dark)
                .tint(Color(hex: "0A84FF"))
        }
    }
}
