import SwiftUI

@main
struct SalBloxApp: App {
    @StateObject private var store: Store

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uitest") { Store.wipe() }   // UI tests start from nothing
        #endif
        _store = StateObject(wrappedValue: Store())
        URLCache.shared = URLCache(memoryCapacity: 32 << 20, diskCapacity: 200 << 20)   // pictures survive a relaunch
        let bar = UINavigationBarAppearance()
        bar.configureWithOpaqueBackground()
        bar.backgroundColor = UIColor(Color.bg)
        bar.shadowColor = .clear
        bar.titleTextAttributes = [.font: UIFont(name: "BuilderSans-Bold", size: 17) ?? .boldSystemFont(ofSize: 17), .foregroundColor: UIColor(Color.ink)]
        bar.backButtonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.clear]
        bar.backButtonAppearance.highlighted.titleTextAttributes = [.foregroundColor: UIColor.clear]
        UINavigationBar.appearance().standardAppearance = bar
        UINavigationBar.appearance().scrollEdgeAppearance = bar
    }

    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .onChange(of: phase) { _, now in
                    if now == .active { store.resumeDrawing() } else { store.saveNow() }     // nothing typed last is lost
                }
                .environment(\.font, .builder(17))
                .foregroundStyle(Color.ink)
                .preferredColorScheme(.dark)
                .tint(.white)
        }
    }
}
