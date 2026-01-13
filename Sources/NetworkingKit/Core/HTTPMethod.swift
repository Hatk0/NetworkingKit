import Foundation

/// Represents HTTP request methods.
///
/// This enum defines the standard HTTP methods used in RESTful APIs.
/// Each case maps directly to the corresponding HTTP method string.
///
/// - SeeAlso: `HTTPRequest`
public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case head = "HEAD"
    case options = "OPTIONS"
}

// MARK: - CustomStringConvertible

extension HTTPMethod: CustomStringConvertible {
    
    public var description: String {
        rawValue
    }
}
