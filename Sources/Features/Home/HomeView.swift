import SwiftUI

/// Signed-in landing screen. For the foundation it proves the whole stack works:
/// Logto claims are readable, and a zinc-scoped access token can be minted (which
/// exercises Logto → API-resource authorization). Real habit screens replace this.
struct HomeView: View {
  @EnvironmentObject private var auth: AuthService
  @State private var apiCheck: ApiCheck = .idle

  enum ApiCheck: Equatable {
    case idle, checking, ok, failed(Problem)
    static func == (l: ApiCheck, r: ApiCheck) -> Bool {
      switch (l, r) {
      case (.idle, .idle), (.checking, .checking), (.ok, .ok): return true
      case let (.failed(a), .failed(b)): return a.id == b.id
      default: return false
      }
    }
  }

  var body: some View {
    NavigationStack {
      List {
        Section("Signed in") {
          let claims = auth.claims()
          LabeledContent("Name", value: claims?.name ?? "—")
          LabeledContent("Email", value: claims?.email ?? "—")
          LabeledContent("Subject", value: claims?.sub ?? "—")
        }

        Section("Environment") {
          LabeledContent("Landscape", value: auth.config.landscape.rawValue)
          LabeledContent("API", value: auth.config.zincBaseURL.host ?? "—")
        }

        Section("API access") {
          switch apiCheck {
          case .idle:
            Button("Check zinc API access") { Task { await checkApi() } }
          case .checking:
            HStack { ProgressView(); Text("Minting access token…") }
          case .ok:
            Label("Access token acquired for zinc", systemImage: "checkmark.seal.fill")
              .foregroundStyle(.green)
          case let .failed(problem):
            VStack(alignment: .leading, spacing: 4) {
              Label(problem.title, systemImage: "xmark.octagon.fill").foregroundStyle(.red)
              if let detail = problem.detail {
                Text(detail).font(.caption).foregroundStyle(.secondary)
              }
              Button("Retry") { Task { await checkApi() } }
            }
          }
        }
      }
      .navigationTitle("LazyTax")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Sign out") { Task { await auth.signOut() } }
        }
      }
    }
  }

  private func checkApi() async {
    apiCheck = .checking
    if let _ = await auth.zincAccessToken() {
      apiCheck = .ok
    } else {
      apiCheck = .failed(.local("Could not acquire zinc access token",
                                detail: "Check the Logto Native app config (appId / API resource / redirect URI).",
                                type: "neon:auth"))
    }
  }
}
