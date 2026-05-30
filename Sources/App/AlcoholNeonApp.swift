import SwiftUI

/// App entry point. Owns the single `AuthService` and injects it into the view tree
/// (the lightweight DI approach for the foundation — can grow into a container later).
@main
struct AlcoholNeonApp: App {
  @StateObject private var auth = AuthService()

  var body: some Scene {
    WindowGroup {
      RootView()
        .environmentObject(auth)
    }
  }
}
