import Foundation

/// Per-landscape configuration. Per-landscape defaults mirror alcohol.argon's
/// settings.yaml (zinc API base URL, Logto endpoint, the `alcohol-zinc` API resource
/// indicator), but the auth values are **overridable via environment variables** so the
/// app can be pointed at any Logto tenant without editing source (handy for testing and
/// CI; set them in the Xcode scheme or via `simctl … --setenv`):
///
///   NEON_LANDSCAPE       lapras | pichu | pikachu | raichu   (default: pichu)
///   NEON_LOGTO_ENDPOINT  Logto OIDC issuer URL
///   NEON_LOGTO_APP_ID    Logto **Native** application ID
///   NEON_ZINC_URL        zinc REST API base URL
///   NEON_ZINC_RESOURCE   zinc API resource indicator ("" → request no resource)
///
/// NOTE: a native iOS app needs its own Logto application of type **Native** (with
/// redirect URI `cloud.atomi.alcohol.neon://callback`); the per-landscape `logtoAppId`
/// defaults are placeholders. Supply a real one via `NEON_LOGTO_APP_ID` or by editing
/// the defaults. Sign-in cannot complete until a valid Native App ID is set.
struct AppConfig: Sendable {
  let landscape: Landscape

  /// zinc REST API base URL (e.g. https://api.zinc.alcohol.pichu.cluster.atomi.cloud).
  let zincBaseURL: URL

  /// Logto OIDC issuer/endpoint (the "lithium" auth service).
  let logtoEndpoint: String

  /// Logto Native application ID.
  let logtoAppId: String

  /// API resource indicator registered in Logto for the zinc API. Access tokens are
  /// minted *for* this resource and sent as the Bearer token to zinc. Empty string
  /// means "request no resource" (e.g. a tenant without the zinc resource registered).
  let zincResource: String

  /// Custom-scheme redirect handled during sign-in. Must match the Native app's
  /// redirect URI in Logto and the URL scheme in project.yml.
  let redirectURI: String = "cloud.atomi.alcohol.neon://callback"

  /// Scopes requested at sign-in. `admin`/`active` are custom scopes the backend uses.
  let scopes: [String] = ["openid", "profile", "offline_access", "email", "admin", "active"]

  /// Resources to request at sign-in — empty when no zinc resource is configured.
  var apiResources: [String] { zincResource.isEmpty ? [] : [zincResource] }
}

extension AppConfig {
  /// The active config: per-landscape defaults with environment-variable overrides.
  static let current: AppConfig = {
    let landscape = ProcessInfo.processInfo.environment["NEON_LANDSCAPE"]
      .flatMap(Landscape.init(rawValue:)) ?? .pichu
    return config(for: landscape)
  }()

  static func config(for landscape: Landscape) -> AppConfig {
    let env = ProcessInfo.processInfo.environment
    let d = defaults(for: landscape)
    return AppConfig(
      landscape: landscape,
      zincBaseURL: env["NEON_ZINC_URL"].flatMap { URL(string: $0) } ?? d.zincBaseURL,
      logtoEndpoint: env["NEON_LOGTO_ENDPOINT"] ?? d.logtoEndpoint,
      logtoAppId: env["NEON_LOGTO_APP_ID"] ?? d.logtoAppId,
      zincResource: env["NEON_ZINC_RESOURCE"] ?? d.zincResource
    )
  }

  /// Per-landscape defaults. Endpoints/URLs are public infra; app IDs are placeholders.
  private static func defaults(
    for landscape: Landscape
  ) -> (zincBaseURL: URL, logtoEndpoint: String, logtoAppId: String, zincResource: String) {
    switch landscape {
    case .lapras:
      return (URL(string: "http://localhost:9003")!,
              "http://localhost:3301/", // local Logto; adjust to your setup
              "REPLACE_WITH_NATIVE_LOGTO_APP_ID",
              "https://api.zinc.alcohol.lapras")
    case .pichu:
      return (URL(string: "https://api.zinc.alcohol.pichu.cluster.atomi.cloud")!,
              "https://api.lithium.alcohol.pichu.cluster.atomi.cloud/",
              "REPLACE_WITH_NATIVE_LOGTO_APP_ID",
              "https://api.zinc.alcohol.pichu")
    case .pikachu:
      return (URL(string: "https://api.zinc.alcohol.pikachu.cluster.atomi.cloud")!,
              "https://api.lithium.alcohol.pikachu.cluster.atomi.cloud/",
              "REPLACE_WITH_NATIVE_LOGTO_APP_ID",
              "https://api.zinc.alcohol.pikachu")
    case .raichu:
      return (URL(string: "https://api.zinc.alcohol.raichu.cluster.atomi.cloud")!,
              "https://api.lithium.alcohol.raichu.cluster.atomi.cloud/",
              "REPLACE_WITH_NATIVE_LOGTO_APP_ID",
              "https://api.zinc.alcohol.raichu")
    }
  }
}
