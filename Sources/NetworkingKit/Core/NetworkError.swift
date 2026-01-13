import Foundation

/// Comprehensive error types for network operations.
///
/// `NetworkError` covers all common failure scenarios in networking,
/// providing detailed error information and recovery suggestions.
public enum NetworkError: Error, Sendable {
    /// The request was invalid or malformed.
    case invalidRequest
    
    /// The response from the server was invalid or could not be parsed.
    case invalidResponse
    
    /// The URL is invalid or malformed.
    case invalidURL(String)
    
    /// No internet connection is available.
    case noConnection
    
    /// The request timed out.
    case timeout
    
    /// HTTP error with status code and response data.
    case httpError(statusCode: Int, data: Data?)
    
    /// Failed to encode the request body.
    case encodingFailed(Error)
    
    /// Failed to decode the response data.
    case decodingFailed(Error)
    
    /// SSL/TLS certificate validation failed.
    case certificateValidationFailed
    
    /// The request was cancelled.
    case cancelled
    
    /// An underlying URLSession error occurred.
    case underlying(Error)
    
    /// A custom error with a message.
    case custom(String)
}

// MARK: - LocalizedError

extension NetworkError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "The request is invalid or malformed."
            
        case .invalidResponse:
            return "The server response is invalid or could not be parsed."
            
        case .invalidURL(let urlString):
            return "The URL is invalid: '\(urlString)'"
            
        case .noConnection:
            return "No internet connection is available."
            
        case .timeout:
            return "The request timed out."
            
        case .httpError(let statusCode, _):
            return "HTTP error with status code \(statusCode)."
            
        case .encodingFailed(let error):
            return "Failed to encode request: \(error.localizedDescription)"
            
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
            
        case .certificateValidationFailed:
            return "SSL/TLS certificate validation failed."
            
        case .cancelled:
            return "The request was cancelled."
            
        case .underlying(let error):
            return "Network error: \(error.localizedDescription)"
            
        case .custom(let message):
            return message
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .httpError(let statusCode, _):
            return HTTPStatusCode.reason(for: statusCode)
        case .noConnection:
            return "The device may be offline or not connected to the internet."
        case .timeout:
            return "The server did not respond within the allowed time."
        default:
            return nil
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .noConnection:
            return "Please check your internet connection and try again."
        case .timeout:
            return "Please try again later or check your network connection."
        case .httpError(let statusCode, _) where statusCode >= 500:
            return "The server is experiencing issues. Please try again later."
        case .httpError(let statusCode, _) where statusCode == 401:
            return "Your session may have expired. Please log in again."
        default:
            return nil
        }
    }
}

// MARK: - Error Mapping

extension NetworkError {
    
    /// Maps a URLError to a NetworkError.
    ///
    /// This provides a more semantic error representation for common URLSession errors.
    ///
    /// - Parameter error: The URLError to map
    /// - Returns: The corresponding NetworkError
    public static func from(urlError: URLError) -> NetworkError {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .noConnection
            
        case .timedOut:
            return .timeout
            
        case .cancelled:
            return .cancelled
            
        case .serverCertificateUntrusted, .serverCertificateHasUnknownRoot,
             .serverCertificateNotYetValid, .serverCertificateHasBadDate:
            return .certificateValidationFailed
            
        case .badURL, .unsupportedURL:
            return .invalidURL(urlError.failingURL?.absoluteString ?? "")
            
        default:
            return .underlying(urlError)
        }
    }
}

// MARK: - HTTP Status Codes

/// Helper for HTTP status code descriptions.
private enum HTTPStatusCode {
    static func reason(for statusCode: Int) -> String {
        switch statusCode {
        // 2xx Success
        case 200: return "OK"
        case 201: return "Created"
        case 202: return "Accepted"
        case 204: return "No Content"
            
        // 3xx Redirection
        case 301: return "Moved Permanently"
        case 302: return "Found"
        case 304: return "Not Modified"
            
        // 4xx Client Errors
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 408: return "Request Timeout"
        case 409: return "Conflict"
        case 422: return "Unprocessable Entity"
        case 429: return "Too Many Requests"
            
        // 5xx Server Errors
        case 500: return "Internal Server Error"
        case 501: return "Not Implemented"
        case 502: return "Bad Gateway"
        case 503: return "Service Unavailable"
        case 504: return "Gateway Timeout"
            
        default:
            if (200..<300).contains(statusCode) {
                return "Success"
            } else if (300..<400).contains(statusCode) {
                return "Redirection"
            } else if (400..<500).contains(statusCode) {
                return "Client Error"
            } else if (500..<600).contains(statusCode) {
                return "Server Error"
            } else {
                return "Unknown Status Code"
            }
        }
    }
}
