import SwiftUI

@main
struct BloxApp: App {
    @StateObject private var store: Store

    init() {
        if ProcessInfo.processInfo.arguments.contains("-uitest") { Store.wipe() }   // UI tests start from nothing
        _store = StateObject(wrappedValue: Store())
        let bar = UINavigationBarAppearance()
        bar.configureWithOpaqueBackground()
        bar.backgroundColor = UIColor(Color.bg)
        bar.shadowColor = .clear
        bar.titleTextAttributes = [.font: UIFont(name: "BuilderSans-Bold", size: 17) ?? .boldSystemFont(ofSize: 17), .foregroundColor: UIColor(Color.ink)]
        UINavigationBar.appearance().standardAppearance = bar
        UINavigationBar.appearance().scrollEdgeAppearance = bar
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environment(\.font, .builder(17))
                .foregroundStyle(Color.ink)
                .preferredColorScheme(.dark)
                .tint(.white)
        }
    }
}
