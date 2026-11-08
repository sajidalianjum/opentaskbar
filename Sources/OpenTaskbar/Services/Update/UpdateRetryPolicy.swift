import Foundation

// Decides whether a failed update request deserves another attempt before the
// user ever sees an error. GitHub's release CDN answers 502/503/504 while it is
// busy or cannot reach its asset backend, and those responses are almost always
// gone a few seconds later, so both the version check and the asset download
// retry with a short backoff.
//
// Pure and injectable: the backoff arithmetic is unit-tested without waiting for
// real delays, and the tests use `.immediate` so retries do not slow the suite.
struct UpdateRetryPolicy: Equatable {
    let maxAttempts: Int
    let initialDelay: TimeInterval
    let multiplier: Double

    static let `default` = UpdateRetryPolicy(maxAttempts: 3, initialDelay: 1, multiplier: 3)
    static let immediate = UpdateRetryPolicy(maxAttempts: 3, initialDelay: 0, multiplier: 1)

    init(maxAttempts: Int = 3, initialDelay: TimeInterval = 1, multiplier: Double = 3) {
        self.maxAttempts = Swift.max(1, maxAttempts)
        self.initialDelay = Swift.max(0, initialDelay)
        self.multiplier = Swift.max(1, multiplier)
    }

    // `attempt` is 1-based and counts the attempts already made, so the delay
    // before attempt 2 is `initialDelay`, before attempt 3 it is `3 ×` that.
    func delay(afterAttempt attempt: Int) -> TimeInterval {
        guard attempt >= 1 else { return initialDelay }
        return initialDelay * pow(multiplier, Double(attempt - 1))
    }

    // A 5xx means "the server could not serve this right now", which is worth
    // retrying. 404/403/304 and friends are answers, not glitches.
    static func isTransient(statusCode: Int) -> Bool {
        (500...599).contains(statusCode)
    }

    // Transport failures that are worth another try. `.notConnectedToInternet`
    // and `.cancelled` are deliberately absent: no amount of retrying fixes them.
    static func isTransient(urlErrorCode: URLError.Code) -> Bool {
        switch urlErrorCode {
        case .timedOut, .networkConnectionLost, .cannotConnectToHost, .cannotLoadFromNetwork, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }

    func shouldRetry(afterAttempt attempt: Int, error: UpdateError, urlError: URLError? = nil) -> Bool {
        guard attempt < maxAttempts else { return false }
        switch error {
        case .httpStatus(let code):
            return UpdateRetryPolicy.isTransient(statusCode: code)
        case .offline:
            // `.offline` wraps a transport error, but only the underlying
            // URLError says whether a retry could plausibly change the outcome.
            guard let urlError else { return false }
            return UpdateRetryPolicy.isTransient(urlErrorCode: urlError.code)
        default:
            return false
        }
    }
}
