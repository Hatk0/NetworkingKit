import Foundation

/// Fluent builder for HTTP headers.
///
/// `HeaderBuilder` provides a type-safe, convenient API for
/// constructing HTTP headers with common values.
///
/// Example:
/// ```swift
/// let headers = HeaderBuilder()
///     .authorization(.bearer("token123"))
///     .contentType(.json)
///     .accept(.json)
///     .build()
/// ```
public struct HeaderBuilder {
    private var headers: [String: String] = [:]
    
    public init() {}
    
    /// Returns the built headers dictionary.
    public func build() -> [String: String] {
        headers
    }
    
    /// Sets a custom header.
    public func set(_ key: String, value: String) -> HeaderBuilder {
        var builder = self
        builder.headers[key] = value
        return builder
    }
    
    /// Sets multiple headers.
    public func set(_ newHeaders: [String: String]) -> HeaderBuilder {
        var builder = self
        builder.headers.merge(newHeaders) { _, new in new }
        return builder
    }
}

// MARK: - Authorization

extension HeaderBuilder {
    /// Authorization schemes.
    public enum AuthorizationScheme: Sendable {
        case bearer(String)
        case basic(username: String, password: String)
        case apiKey(String)
        case custom(String)
        
        var headerValue: String {
            switch self {
            case .bearer(let token):
                return "Bearer \(token)"
                
            case .basic(let username, let password):
                let credentials = "\(username):\(password)"
                let encodedCredentials = Data(credentials.utf8).base64EncodedString()
                return "Basic \(encodedCredentials)"
                
            case .apiKey(let key):
                return key
                
            case .custom(let value):
                return value
            }
        }
    }
    
    /// Sets the Authorization header.
    public func authorization(_ scheme: AuthorizationScheme) -> HeaderBuilder {
        set("Authorization", value: scheme.headerValue)
    }
}

// MARK: - Content-Type

extension HeaderBuilder {
    /// Common content types.
    public enum ContentType: String {
        case json = "application/json; charset=utf-8"
        case xml = "application/xml; charset=utf-8"
        case formURLEncoded = "application/x-www-form-urlencoded; charset=utf-8"
        case multipartFormData = "multipart/form-data"
        case plainText = "text/plain; charset=utf-8"
        case html = "text/html; charset=utf-8"
        case pdf = "application/pdf"
        case octetStream = "application/octet-stream"
    }
    
    /// Sets the Content-Type header.
    public func contentType(_ type: ContentType) -> HeaderBuilder {
        set("Content-Type", value: type.rawValue)
    }
    
    /// Sets a custom Content-Type header.
    public func contentType(_ type: String) -> HeaderBuilder {
        set("Content-Type", value: type)
    }
}

// MARK: - Accept

extension HeaderBuilder {
    /// Sets the Accept header.
    public func accept(_ type: ContentType) -> HeaderBuilder {
        set("Accept", value: type.rawValue)
    }
    
    /// Sets a custom Accept header.
    public func accept(_ type: String) -> HeaderBuilder {
        set("Accept", value: type)
    }
}

// MARK: - User-Agent

extension HeaderBuilder {
    /// Sets the User-Agent header.
    public func userAgent(_ agent: String) -> HeaderBuilder {
        set("User-Agent", value: agent)
    }
    
    /// Sets a default User-Agent with app name and version.
    public func userAgent(appName: String, version: String) -> HeaderBuilder {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let agent = "\(appName)/\(version) (\(osVersion))"
        return userAgent(agent)
    }
}

// MARK: - Cache Control

extension HeaderBuilder {
    /// Cache control directives.
    public enum CacheControl {
        case noCache
        case noStore
        case maxAge(seconds: Int)
        case custom(String)
        
        var headerValue: String {
            switch self {
            case .noCache:
                return "no-cache"
            case .noStore:
                return "no-store"
            case .maxAge(let seconds):
                return "max-age=\(seconds)"
            case .custom(let value):
                return value
            }
        }
    }
    
    /// Sets the Cache-Control header.
    public func cacheControl(_ control: CacheControl) -> HeaderBuilder {
        set("Cache-Control", value: control.headerValue)
    }
}

// MARK: - Common Headers

extension HeaderBuilder {
    /// Sets the Accept-Language header.
    public func acceptLanguage(_ language: String) -> HeaderBuilder {
        set("Accept-Language", value: language)
    }
    
    /// Sets the Accept-Encoding header.
    public func acceptEncoding(_ encodings: [String]) -> HeaderBuilder {
        set("Accept-Encoding", value: encodings.joined(separator: ", "))
    }
    
    /// Sets default Accept-Encoding (gzip, deflate).
    public func acceptEncoding() -> HeaderBuilder {
        acceptEncoding(["gzip", "deflate", "br"])
    }
    
    /// Sets the If-None-Match header (ETag).
    public func ifNoneMatch(_ etag: String) -> HeaderBuilder {
        set("If-None-Match", value: etag)
    }
    
    /// Sets the If-Modified-Since header.
    public func ifModifiedSince(_ date: Date) -> HeaderBuilder {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return set("If-Modified-Since", value: formatter.string(from: date))
    }
}

// MARK: - Convenience Initializers

extension HeaderBuilder {
    /// Creates a header builder with JSON content type and accept headers.
    public static var json: HeaderBuilder {
        HeaderBuilder()
            .contentType(.json)
            .accept(.json)
    }
    
    /// Creates a header builder with form URL encoded content type.
    public static var form: HeaderBuilder {
        HeaderBuilder()
            .contentType(.formURLEncoded)
    }
    
    /// Creates a header builder with multipart form data content type.
    public static var multipart: HeaderBuilder {
        HeaderBuilder()
            .contentType(.multipartFormData)
    }
}
