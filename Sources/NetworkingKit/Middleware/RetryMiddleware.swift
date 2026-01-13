import Foundation

/// Middleware for automatic request retry with exponential backoff.
///
/// This middleware automatically retries failed requests based on
/// configurable conditions, with exponential backoff between attempts.
public struct RetryMiddleware: Middleware {
    /// Retry strategy configuration.
    public struct RetryConfiguration: Sendable {
        /// Maximum number of retry attempts.
        public let maxRetries: Int
        
        /// Base delay between retries (in seconds).
        public let baseDelay: TimeInterval
        
        /// Maximum delay between retries (in seconds).
        public let maxDelay: TimeInterval
        
        /// Multiplier for exponential backoff.
        public let backoffMultiplier: Double
        
        /// HTTP status codes that should trigger a retry.
        public let retryableStatusCodes: Set<Int>
        
        /// HTTP methods that are safe to retry (idempotent).
        public let retryableMethods: Set<HTTPMethod>
        
        /// Initializes retry configuration.
        ///
        /// - Parameters:
        ///   - maxRetries: Maximum retry attempts (default: 3)
        ///   - baseDelay: Base delay in seconds (default: 1.0)
        ///   - maxDelay: Maximum delay in seconds (default: 60.0)
        ///   - backoffMultiplier: Exponential backoff multiplier (default: 2.0)
        ///   - retryableStatusCodes: Status codes to retry (default: 408, 429, 500, 502, 503, 504)
        ///   - retryableMethods: Methods to retry (default: GET, HEAD, OPTIONS, PUT, DELETE)
        public init(
            maxRetries: Int = 3,
            baseDelay: TimeInterval = 1.0,
            maxDelay: TimeInterval = 60.0,
            backoffMultiplier: Double = 2.0,
            retryableStatusCodes: Set<Int> = [408, 429, 500, 502, 503, 504],
            retryableMethods: Set<HTTPMethod> = [.get, .head, .options, .put, .delete]
        ) {
            self.maxRetries = maxRetries
            self.baseDelay = baseDelay
            self.maxDelay = maxDelay
            self.backoffMultiplier = backoffMultiplier
            self.retryableStatusCodes = retryableStatusCodes
            self.retryableMethods = retryableMethods
        }
    }
    
    private let configuration: RetryConfiguration
    
    /// Initializes retry middleware.
    ///
    /// - Parameter configuration: The retry configuration
    public init(configuration: RetryConfiguration = RetryConfiguration()) {
        self.configuration = configuration
    }
    
    public func intercept(
        _ request: HTTPRequest,
        next: @Sendable (HTTPRequest) async throws -> HTTPResponse
    ) async throws -> HTTPResponse {
        var attemptCount = 0
        var lastError: Error?
        
        while attemptCount <= configuration.maxRetries {
            do {
                let response = try await next(request)
                
                // Check if we should retry based on status code
                if attemptCount < configuration.maxRetries,
                   configuration.retryableStatusCodes.contains(response.statusCode),
                   configuration.retryableMethods.contains(request.method) {
                    
                    // Wait before retrying
                    let delay = calculateDelay(for: attemptCount)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    
                    attemptCount += 1
                    continue
                }
                
                return response
                
            } catch {
                lastError = error
                
                // Check if we should retry based on error type
                if attemptCount < configuration.maxRetries,
                   shouldRetry(error: error, method: request.method) {
                    
                    // Wait before retrying
                    let delay = calculateDelay(for: attemptCount)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    
                    attemptCount += 1
                    continue
                }
                
                throw error
            }
        }
        
        // All retries exhausted
        throw lastError ?? NetworkError.custom("Max retries exceeded")
    }
    
    // MARK: - Helpers
    
    private func shouldRetry(error: Error, method: HTTPMethod) -> Bool {
        // Only retry idempotent methods
        guard configuration.retryableMethods.contains(method) else {
            return false
        }
        
        // Retry on network errors
        if let networkError = error as? NetworkError {
            switch networkError {
            case .noConnection, .timeout, .underlying:
                return true
            case .httpError(let statusCode, _):
                return configuration.retryableStatusCodes.contains(statusCode)
            default:
                return false
            }
        }
        
        return false
    }
    
    private func calculateDelay(for attemptCount: Int) -> TimeInterval {
        let exponentialDelay = configuration.baseDelay * pow(configuration.backoffMultiplier, Double(attemptCount))
        let jitter = Double.random(in: 0...0.1) * exponentialDelay // Add 0-10% jitter
        return min(exponentialDelay + jitter, configuration.maxDelay)
    }
}

// MARK: - HTTPMethod Hashable

extension HTTPMethod: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}

// MARK: - Convenience Initializers

extension RetryMiddleware {
    /// Creates a retry middleware with default configuration.
    public static var `default`: RetryMiddleware {
        RetryMiddleware()
    }
    
    /// Creates a retry middleware with aggressive retry settings.
    public static var aggressive: RetryMiddleware {
        RetryMiddleware(configuration: RetryConfiguration(
            maxRetries: 5,
            baseDelay: 0.5,
            maxDelay: 30.0
        ))
    }
    
    /// Creates a retry middleware with conservative retry settings.
    public static var conservative: RetryMiddleware {
        RetryMiddleware(configuration: RetryConfiguration(
            maxRetries: 2,
            baseDelay: 2.0,
            maxDelay: 10.0
        ))
    }
}
