import SwiftUI

@main
struct CutlineDNSApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        .defaultSize(width: 400, height: 560)
        #endif
    }
}
