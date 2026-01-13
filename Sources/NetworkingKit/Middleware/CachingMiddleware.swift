import Foundation

/// Middleware for caching HTTP responses.
///
/// This middleware implements response caching with support for
/// ETag, Last-Modified headers, and configurable cache policies.
public struct CachingMiddleware: Middleware {
    /// Cache policy for requests.
    public enum CachePolicy: Sendable {
        /// Never cache responses.
        case never
        
        /// Always use cached response if available.
        case always
        
        /// Use cached response only if valid (respects cache headers).
        case conditional
        
        /// Cache for a specific duration.
        case duration(TimeInterval)
    }
    
    /// Cache storage protocol.
    public protocol CacheStorage: Sendable {
        func response(for request: HTTPRequest) async -> CachedResponse?
        func store(_ response: HTTPResponse, for request: HTTPRequest) async
        func clear() async
    }
    
    /// Represents a cached response with metadata.
    public struct CachedResponse: Sendable {
        public let response: HTTPResponse
        public let timestamp: Date
        public let etag: String?
        public let lastModified: String?
        
        public init(response: HTTPResponse, timestamp: Date = Date()) {
            self.response = response
            self.timestamp = timestamp
            self.etag = response.headers["ETag"] ?? response.headers["etag"]
            self.lastModified = response.headers["Last-Modified"] ?? response.headers["last-modified"]
        }
        
        /// Returns true if the cached response is still valid.
        public func isValid(maxAge: TimeInterval) -> Bool {
            Date().timeIntervalSince(timestamp) < maxAge
        }
    }
    
    private let policy: CachePolicy
    private let storage: CacheStorage
    
    /// Initializes caching middleware.
    ///
    /// - Parameters:
    ///   - policy: The cache policy to use
    ///   - storage: The cache storage implementation
    public init(policy: CachePolicy = .conditional, storage: CacheStorage = InMemoryCacheStorage()) {
        self.policy = policy
        self.storage = storage
    }
    
    public func intercept(
        _ request: HTTPRequest,
        next: @Sendable (HTTPRequest) async throws -> HTTPResponse
    ) async throws -> HTTPResponse {
        // Never cache for non-GET requests
        guard request.method == .get else {
            return try await next(request)
        }
        
        switch policy {
        case .never:
            return try await next(request)
            
        case .always:
            if let cached = await storage.response(for: request) {
                return cached.response
            }
            let response = try await next(request)
            await storage.store(response, for: request)
            return response
            
        case .conditional:
            return try await conditionalCache(request: request, next: next)
            
        case .duration(let maxAge):
            if let cached = await storage.response(for: request), cached.isValid(maxAge: maxAge) {
                return cached.response
            }
            let response = try await next(request)
            await storage.store(response, for: request)
            return response
        }
    }
    
    private func conditionalCache(
        request: HTTPRequest,
        next: @Sendable (HTTPRequest) async throws -> HTTPResponse
    ) async throws -> HTTPResponse {
        guard let cached = await storage.response(for: request) else {
            // No cached response, fetch and cache
            let response = try await next(request)
            await storage.store(response, for: request)
            return response
        }
        
        // Build conditional request
        var conditionalRequest = request
        var conditionalHeaders = request.headers
        
        if let etag = cached.etag {
            conditionalHeaders["If-None-Match"] = etag
        }
        
        if let lastModified = cached.lastModified {
            conditionalHeaders["If-Modified-Since"] = lastModified
        }
        
        conditionalRequest = conditionalRequest.headers(conditionalHeaders)
        
        do {
            let response = try await next(conditionalRequest)
            
            // If 304 Not Modified, use cached response
            if response.statusCode == 304 {
                return cached.response
            }
            
            // Otherwise, cache new response
            await storage.store(response, for: request)
            return response
            
        } catch {
            // On error, return cached response if available
            throw error
        }
    }
}

// MARK: - In-Memory Cache Storage

/// Simple in-memory cache storage implementation.
///
/// This is a basic implementation suitable for development and testing.
/// For production use, consider implementing persistent storage.
public actor InMemoryCacheStorage: CachingMiddleware.CacheStorage {
    private var cache: [String: CachingMiddleware.CachedResponse] = [:]
    
    public init() {}
    
    public func response(for request: HTTPRequest) async -> CachingMiddleware.CachedResponse? {
        cache[cacheKey(for: request)]
    }
    
    public func store(_ response: HTTPResponse, for request: HTTPRequest) async {
        cache[cacheKey(for: request)] = CachingMiddleware.CachedResponse(response: response)
    }
    
    public func clear() async {
        cache.removeAll()
    }
    
    private func cacheKey(for request: HTTPRequest) -> String {
        var key = "\(request.method.rawValue):\(request.url.absoluteString)"
        
        // Include query parameters in cache key
        if let query = request.url.query {
            key += "?\(query)"
        }
        
        return key
    }
}

// MARK: - Convenience Initializers

extension CachingMiddleware {
    /// Creates a caching middleware with conditional caching.
    public static var conditional: CachingMiddleware {
        CachingMiddleware(policy: .conditional)
    }
    
    /// Creates a caching middleware that caches for a specific duration.
    public static func duration(_ duration: TimeInterval) -> CachingMiddleware {
        CachingMiddleware(policy: .duration(duration))
    }
    
    /// Creates a caching middleware that caches for 5 minutes.
    public static var shortTerm: CachingMiddleware {
        CachingMiddleware(policy: .duration(300)) // 5 minutes
    }
    
    /// Creates a caching middleware that caches for 1 hour.
    public static var longTerm: CachingMiddleware {
        CachingMiddleware(policy: .duration(3600)) // 1 hour
    }
}
