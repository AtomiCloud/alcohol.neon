import SwiftUI

/// Signed-out screen. Kicks off Logto's browser-based sign-in (ASWebAuthenticationSession).
struct SignInView: View {
  @EnvironmentObject private var auth: AuthService

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
        Task { await auth.signIn() }
      } label: {
        Text("Sign in")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)

      Text("Environment: \(auth.config.landscape.rawValue)")
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
    .padding(24)
  }
}
