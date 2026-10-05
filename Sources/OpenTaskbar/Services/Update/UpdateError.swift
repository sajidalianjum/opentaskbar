import Foundation

enum UpdateError: LocalizedError, Equatable {
    case offline(String)
    case notModified
    case rateLimited(retryAfter: TimeInterval?)
    case httpStatus(Int)
    case invalidResponse
    case noAssetAvailable
    case checksumMismatch(expected: String, actual: String)
    case downloadFailed(String)
    case unpackFailed(String)
    case validationFailed(String)
    case destinationNotWritable(String)
    case selfUpdateBlocked(String)
    case helperFailed(String)

    var errorDescription: String? {
        switch self {
        case .offline(let message):
            return "\(L10n.updateErrorOffline): \(message)"
        case .notModified:
            return L10n.updateErrorNotModified
        case .rateLimited:
            return L10n.updateErrorRateLimited
        case .httpStatus(let code):
            return L10n.updateErrorHTTPStatus(code)
        case .invalidResponse:
            return L10n.updateErrorInvalidResponse
        case .noAssetAvailable:
            return L10n.updateErrorNoAsset
        case .checksumMismatch:
            return L10n.updateErrorChecksum
        case .downloadFailed(let message):
            return "\(L10n.updateErrorDownloadFailed): \(message)"
        case .unpackFailed(let message):
            return "\(L10n.updateErrorUnpackFailed): \(message)"
        case .validationFailed(let message):
            return "\(L10n.updateErrorValidationFailed): \(message)"
        case .destinationNotWritable(let path):
            return L10n.updateErrorNotWritable(path)
        case .selfUpdateBlocked(let path):
            return L10n.updateErrorSelfUpdateBlocked(path)
        case .helperFailed(let message):
            return "\(L10n.updateErrorInstallFailed): \(message)"
        }
    }
}