import Foundation

/// Minimal async HTTP client for the zinc REST API. Every call returns
/// `Result<T, Problem>` — no throwing across boundaries (house rule from argon).
///
/// Bearer tokens are supplied lazily via `tokenProvider`, which mints a Logto access
/// token *for the zinc resource* on demand (the SDK caches/refreshes it).
struct ApiClient {
  let baseURL: URL
  let session: URLSession
  /// Returns a zinc-scoped access token, or nil when unauthenticated.
  let tokenProvider: () async -> String?

  init(baseURL: URL, session: URLSession = .shared, tokenProvider: @escaping () async -> String?) {
    self.baseURL = baseURL
    self.session = session
    self.tokenProvider = tokenProvider
  }

  func get<T: Decodable>(_ path: String, as _: T.Type) async -> Result<T, Problem> {
    await send(path: path, method: "GET", body: Optional<Data>.none, as: T.self)
  }

  func send<T: Decodable>(
    path: String,
    method: String,
    body: Data?,
    as _: T.Type,
    requiresAuth: Bool = true
  ) async -> Result<T, Problem> {
    guard let url = URL(string: path, relativeTo: baseURL) else {
      return .failure(.local("Invalid URL", detail: path))
    }

    var request = URLRequest(url: url)
    request.httpMethod = method
    request.httpBody = body
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }

    if requiresAuth {
      guard let token = await tokenProvider() else { return .failure(.unauthenticated) }
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(for: request)
    } catch {
      return .failure(.network(error))
    }

    guard let http = response as? HTTPURLResponse else {
      return .failure(.local("No HTTP response"))
    }

    guard (200..<300).contains(http.statusCode) else {
      // Prefer the server's RFC 7807 body; fall back to a synthetic Problem.
      if let problem = try? JSONDecoder().decode(Problem.self, from: data) {
        return .failure(problem)
      }
      return .failure(.local("Request failed", status: http.statusCode,
                             detail: String(data: data, encoding: .utf8)))
    }

    // 204 / empty body where caller expects Void-like Empty.
    if T.self == EmptyResponse.self, let empty = EmptyResponse() as? T {
      return .success(empty)
    }

    do {
      let decoder = JSONDecoder()
      return .success(try decoder.decode(T.self, from: data))
    } catch {
      return .failure(.decoding(error))
    }
  }
}

/// Placeholder for endpoints that return no meaningful body.
struct EmptyResponse: Decodable { init() {} }
