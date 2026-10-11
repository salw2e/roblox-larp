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
            NavigationStack { ProfileView() }
                .environmentObject(store)
                .preferredColorScheme(.light)
                .tint(.primary)
        }
    }
}
