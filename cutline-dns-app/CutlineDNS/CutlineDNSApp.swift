import SwiftUI

@main
struct CutlineDNSApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        .defaultSize(width: 520, height: 720)
        #endif
    }
}
