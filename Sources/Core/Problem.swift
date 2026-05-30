import Foundation

/// RFC 7807 Problem Details — the single error currency across the app, mirroring
/// alcohol.argon's `Problem`. The zinc backend returns these on error; we also
/// synthesize local ones (network/decoding/auth) so every failure has the same shape.
///
/// House rule (from argon): never throw across boundaries — convert to `Result<T, Problem>`.
struct Problem: Error, Decodable, Identifiable, Sendable {
  let type: String
  let title: String
  let status: Int
  let detail: String?
  let instance: String?

  var id: String { instance ?? type }

  init(type: String, title: String, status: Int, detail: String? = nil, instance: String? = nil) {
    self.type = type
    self.title = title
    self.status = status
    self.detail = detail
    self.instance = instance
  }

  // Tolerant decoding: zinc Problems are well-formed, but fall back gracefully.
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.type = (try? c.decode(String.self, forKey: .type)) ?? "about:blank"
    self.title = (try? c.decode(String.self, forKey: .title)) ?? "Error"
    self.status = (try? c.decode(Int.self, forKey: .status)) ?? 0
    self.detail = try? c.decodeIfPresent(String.self, forKey: .detail)
    self.instance = try? c.decodeIfPresent(String.self, forKey: .instance)
  }

  private enum CodingKeys: String, CodingKey {
    case type, title, status, detail, instance
  }
}

extension Problem {
  /// Locally-generated problems for failures that never reach the server.
  static func local(_ title: String, status: Int = 0, detail: String? = nil, type: String = "about:blank") -> Problem {
    Problem(type: type, title: title, status: status, detail: detail)
  }

  static func network(_ error: Error) -> Problem {
    .local("Network error", detail: error.localizedDescription, type: "neon:network")
  }

  static func decoding(_ error: Error) -> Problem {
    .local("Unexpected response", detail: error.localizedDescription, type: "neon:decoding")
  }

  static let unauthenticated = Problem.local("Not signed in", status: 401, type: "neon:unauthenticated")
}
