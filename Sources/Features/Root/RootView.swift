import SwiftUI

/// Switches between signed-in and signed-out experiences based on auth state.
/// Mirrors argon's `useClaims()` match on authed/unauthed.
struct RootView: View {
  @EnvironmentObject private var auth: AuthService

  var body: some View {
    switch auth.status {
    case .loading:
      ProgressView("Loading…")
    case .unauthenticated:
      SignInView()
    case .authenticated:
      HomeView()
    case let .failed(problem):
      VStack(spacing: 12) {
        Text(problem.title).font(.headline)
        if let detail = problem.detail {
          Text(detail).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        Button("Try again") { Task { await auth.signIn() } }
          .buttonStyle(.borderedProminent)
      }
      .padding()
    }
  }
}
