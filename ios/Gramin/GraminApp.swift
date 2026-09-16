import SwiftUI

@main
struct GraminApp: App {
    var body: some Scene {
        WindowGroup {
            WebAppView()
                .ignoresSafeArea()
                .preferredColorScheme(nil)
        }
    }
}
