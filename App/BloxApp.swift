import SwiftUI

@main
struct BloxApp: App {
    @StateObject private var store: Store

    init() {
        if ProcessInfo.processInfo.arguments.contains("-uitest") { Store.wipe() }   // UI tests start from nothing
        _store = StateObject(wrappedValue: Store())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environment(\.font, .builder(17))
                .preferredColorScheme(.dark)
                .tint(.white)
        }
    }
}
