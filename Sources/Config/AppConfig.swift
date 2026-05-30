import Foundation

/// Per-landscape configuration. Values mirror alcohol.argon's settings.yaml
/// (zinc API base URL, Logto endpoint, the `alcohol-zinc` API resource indicator).
///
/// NOTE: `logtoAppId` is intentionally a placeholder. The argon app IDs are for the
/// *web* (SPA) Logto application. A native iOS app needs its own Logto application of
/// type **Native**, with redirect URI `cloud.atomi.alcohol.neon://callback`. Register
/// it in the Logto admin console and paste the IDs below. Sign-in will not complete
/// until this is done.
struct AppConfig: Sendable {
  let landscape: Landscape

  /// zinc REST API base URL (e.g. https://api.zinc.alcohol.pichu.cluster.atomi.cloud).
  let zincBaseURL: URL

  /// Logto OIDC issuer/endpoint (the "lithium" auth service).
  let logtoEndpoint: String

  /// Logto Native application ID — see note above.
  let logtoAppId: String

  /// API resource indicator registered in Logto for the zinc API. Access tokens are
  /// minted *for* this resource and sent as the Bearer token to zinc.
  let zincResource: String

  /// Custom-scheme redirect handled by ASWebAuthenticationSession during sign-in.
  let redirectURI: String = "cloud.atomi.alcohol.neon://callback"

  /// Scopes requested at sign-in. `admin`/`active` are custom scopes the backend uses.
  let scopes: [String] = ["openid", "profile", "offline_access", "email", "admin", "active"]
}

extension AppConfig {
  /// The landscape this build targets. Override via the `NEON_LANDSCAPE` env var
  /// (handy in schemes/CI); defaults to pichu (the shared dev environment).
  static let current: AppConfig = {
    let raw = ProcessInfo.processInfo.environment["NEON_LANDSCAPE"]
    let landscape = raw.flatMap(Landscape.init(rawValue:)) ?? .pichu
    return config(for: landscape)
  }()

  static func config(for landscape: Landscape) -> AppConfig {
    switch landscape {
    case .lapras:
      return AppConfig(
        landscape: .lapras,
        zincBaseURL: URL(string: "http://localhost:9003")!,
        logtoEndpoint: "http://localhost:3301/", // local Logto; adjust to your setup
        logtoAppId: "REPLACE_WITH_NATIVE_LOGTO_APP_ID",
        zincResource: "https://api.zinc.alcohol.lapras"
      )
    case .pichu:
      return AppConfig(
        landscape: .pichu,
        zincBaseURL: URL(string: "https://api.zinc.alcohol.pichu.cluster.atomi.cloud")!,
        logtoEndpoint: "https://api.lithium.alcohol.pichu.cluster.atomi.cloud/",
        logtoAppId: "REPLACE_WITH_NATIVE_LOGTO_APP_ID",
        zincResource: "https://api.zinc.alcohol.pichu"
      )
    case .pikachu:
      return AppConfig(
        landscape: .pikachu,
        zincBaseURL: URL(string: "https://api.zinc.alcohol.pikachu.cluster.atomi.cloud")!,
        logtoEndpoint: "https://api.lithium.alcohol.pikachu.cluster.atomi.cloud/",
        logtoAppId: "REPLACE_WITH_NATIVE_LOGTO_APP_ID",
        zincResource: "https://api.zinc.alcohol.pikachu"
      )
    case .raichu:
      return AppConfig(
        landscape: .raichu,
        zincBaseURL: URL(string: "https://api.zinc.alcohol.raichu.cluster.atomi.cloud")!,
        logtoEndpoint: "https://api.lithium.alcohol.raichu.cluster.atomi.cloud/",
        logtoAppId: "REPLACE_WITH_NATIVE_LOGTO_APP_ID",
        zincResource: "https://api.zinc.alcohol.raichu"
      )
    }
  }
}
