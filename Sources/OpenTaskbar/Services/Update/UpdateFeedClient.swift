import Foundation

// Reads the newest GitHub release. The unauthenticated GitHub API allows 60
// requests per hour per IP, so the client:
//   * honours a 24h cadence driven by UpdateHistoryStore, and
//   * replays the server's ETag with `If-None-Match` so routine checks that
//     find nothing new cost no rate-limit budget (the API answers 304).
final class UpdateFeedClient {
    static let defaultAPIBase = URL(string: "https://api.github.com")!
    static let defaultOwner = "sajidalianjum"
    static let defaultRepository = "opentaskbar"

    private let session: URLSession
    private let endpoint: URL
    private let etagStore: ETagStoring

    init(
        endpoint: URL? = nil,
        session: URLSession = .shared,
        etagStore: ETagStoring = UserDefaultsETagStore()
    ) {
        self.endpoint = endpoint ?? UpdateFeedClient.defaultEndpoint()
        self.session = session
        self.etagStore = etagStore
    }

    static func defaultEndpoint(bundle: Bundle = .main) -> URL {
        if let raw = bundle.object(forInfoDictionaryKey: "OpenTaskbarReleaseAPIBase") as? String,
           let url = URL(string: raw) {
            return url
        }
        return defaultAPIBase
            .appendingPathComponent("repos/\(defaultOwner)/\(defaultRepository)/releases/latest")
    }

    static func releasePageURL(bundle: Bundle = .main) -> URL {
        if let raw = bundle.object(forInfoDictionaryKey: "OpenTaskbarReleasesPageURL") as? String,
           let url = URL(string: raw) {
            return url
        }
        return URL(string: "https://github.com/\(defaultOwner)/\(defaultRepository)/releases/latest")!
    }

    func fetchLatestRelease(completion: @escaping (Result<UpdateRelease, UpdateError>) -> Void) {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("OpenTaskbar/\(AppVersion.bundleVersion?.description ?? "dev")", forHTTPHeaderField: "User-Agent")
        if let etag = etagStore.etag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let session = self.session
        let etagStore = self.etagStore
        session.dataTask(with: request) { data, response, error in
            let result: Result<UpdateRelease, UpdateError> = UpdateFeedClient.interpret(
                data: data,
                response: response,
                error: error
            )
            if case .success = result {
                if let http = response as? HTTPURLResponse,
                   let etag = http.value(forHTTPHeaderField: "ETag") {
                    etagStore.etag = etag
                }
            }
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }

    // Pure so the mapping of HTTP responses to failures is unit-testable.
    static func interpret(
        data: Data?,
        response: URLResponse?,
        error: Error?
    ) -> Result<UpdateRelease, UpdateError> {
        if let urlError = error as? URLError {
            return .failure(.offline(urlError.localizedDescription))
        }
        if let error {
            return .failure(.offline(error.localizedDescription))
        }

        guard let http = response as? HTTPURLResponse else {
            return .failure(.invalidResponse)
        }

        switch http.statusCode {
        case 200..<300:
            guard let data, let release = UpdateRelease.parse(json: data) else {
                return .failure(.invalidResponse)
            }
            return .success(release)
        case 304:
            return .failure(.notModified)
        case 403, 429:
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            return .failure(.rateLimited(retryAfter: retryAfter))
        default:
            return .failure(.httpStatus(http.statusCode))
        }
    }
}

protocol ETagStoring: AnyObject {
    var etag: String? { get set }
}

final class UserDefaultsETagStore: ETagStoring {
    private let key: String
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, key: String = "opentaskbar.update.etag") {
        self.defaults = defaults
        self.key = key
    }

    var etag: String? {
        get { defaults.string(forKey: key) }
        set {
            if let newValue {
                defaults.set(newValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }
}