import Foundation

/// Deployment environments, mirroring the AtomiCloud landscapes used by
/// alcohol.zinc (backend) and alcohol.argon (web).
enum Landscape: String, CaseIterable, Sendable {
  case lapras   // local development
  case pichu    // development
  case pikachu  // staging
  case raichu   // production
}
