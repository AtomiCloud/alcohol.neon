import SwiftUI

/// Signed-out screen. Kicks off Logto's browser-based sign-in (ASWebAuthenticationSession).
struct SignInView: View {
  @EnvironmentObject private var auth: AuthService
  @State private var isSigningIn = false

  var body: some View {
    VStack(spacing: 24) {
      Spacer()
      Text("LazyTax")
        .font(.largeTitle.bold())
      Text("Stake money on your habits.\nMiss one, it goes to charity.")
        .font(.body)
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
      Spacer()
      Button {
        Task { isSigningIn = true; await auth.signIn(); isSigningIn = false }
      } label: {
        Group {
          if isSigningIn { ProgressView() } else { Text("Sign in") }
        }
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .disabled(isSigningIn)

      Text("Environment: \(auth.config.landscape.rawValue)")
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
    .padding(24)
  }
}
