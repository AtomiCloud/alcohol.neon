import Foundation
import Logto
import LogtoClient

/// App-owned view of the signed-in user's ID-token claims (keeps the Logto SDK
/// type out of the view layer).
struct UserClaims: Equatable {
  let sub: String?
  let name: String?
  let email: String?
}

/// Authentication state, mirroring argon's discriminated auth union.
enum AuthStatus: Equatable {
  case loading
  case authenticated
  case unauthenticated
  case failed(Problem)

  static func == (lhs: AuthStatus, rhs: AuthStatus) -> Bool {
    switch (lhs, rhs) {
    case (.loading, .loading), (.authenticated, .authenticated), (.unauthenticated, .unauthenticated):
      return true
    case let (.failed(a), .failed(b)):
      return a.id == b.id
    default:
      return false
    }
  }
}

/// Wraps the Logto iOS SDK. The SDK persists tokens in the Keychain
/// (`usingPersistStorage` default) and refreshes them, so we don't manage storage.
@MainActor
final class AuthService: ObservableObject {
  @Published private(set) var status: AuthStatus = .loading

  let config: AppConfig
  private let client: LogtoClient

  init(config: AppConfig = .current) {
    self.config = config
    // LogtoConfig only throws on malformed input; our values are static & valid.
    let logtoConfig = try! LogtoConfig(
      endpoint: config.logtoEndpoint,
      appId: config.logtoAppId,
      scopes: config.scopes,
      // Empty unless a zinc resource is configured. Requesting a resource the Logto
      // tenant doesn't have registered makes the authorize request error (blank
      // bounce-back), so resource-less tenants set NEON_ZINC_RESOURCE="".
      resources: config.apiResources,
      usingPersistStorage: true
    )
    self.client = LogtoClient(useConfig: logtoConfig)
    self.status = client.isAuthenticated ? .authenticated : .unauthenticated
  }

  func signIn() async {
    // IMPORTANT: do NOT swap the root view (e.g. to `.loading`) while Logto's web
    // sheet is presented. The sheet is presented over the current SwiftUI view tree;
    // replacing that view tears the sheet down before the redirect returns, which
    // surfaces as `.authFailed`. Keep the presenting view (SignInView) mounted —
    // mirror Logto's quickstart, which uses one stable view + local state.
    do {
      try await client.signInWithBrowser(redirectUri: config.redirectURI)
      status = client.isAuthenticated ? .authenticated : .unauthenticated
    } catch {
      status = .failed(.local("Sign-in failed", detail: error.localizedDescription, type: "neon:auth"))
    }
  }

  func signOut() async {
    await client.signOut()
    status = .unauthenticated
  }

  /// ID-token claims (name, email, sub …) — available offline once signed in.
  /// Returns our own value type so the Logto SDK type doesn't leak into views.
  func claims() -> UserClaims? {
    guard let c = try? client.getIdTokenClaims() else { return nil }
    return UserClaims(sub: c.sub, name: c.name, email: c.email)
  }

  /// A zinc-scoped access token for the Bearer header. Returns nil if unauthenticated.
  /// (Logto SDK 1.1.0: `getAccessToken(for:)` is `async throws -> String`.)
  func zincAccessToken() async -> String? {
    guard client.isAuthenticated else { return nil }
    return try? await client.getAccessToken(for: config.zincResource)
  }

  /// Convenience: an ApiClient pre-wired with this user's token provider.
  func makeApiClient() -> ApiClient {
    ApiClient(baseURL: config.zincBaseURL) { [weak self] in
      await self?.zincAccessToken()
    }
  }
}
