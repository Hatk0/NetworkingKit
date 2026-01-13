import Foundation

/// Middleware for logging HTTP requests and responses.
///
/// This middleware provides configurable logging of network operations,
/// including request details, response status, headers, and bodies.
public struct LoggingMiddleware: Middleware {
    /// Logging verbosity level.
    public enum Level: Sendable {
        /// No logging.
        case none
        
        /// Log basic info (URL, method, status code).
        case basic
        
        /// Log detailed info including headers.
        case headers
        
        /// Log everything including request/response bodies.
        case verbose
    }
    
    private let level: Level
    private let logger: @Sendable (String) -> Void
    
    /// Initializes logging middleware.
    ///
    /// - Parameters:
    ///   - level: The logging level
    ///   - logger: Custom logging closure (default: print)
    public init(level: Level = .basic, logger: @escaping @Sendable (String) -> Void = { print($0) }) {
        self.level = level
        self.logger = logger
    }
    
    public func intercept(
        _ request: HTTPRequest,
        next: @Sendable (HTTPRequest) async throws -> HTTPResponse
    ) async throws -> HTTPResponse {
        guard level != .none else {
            return try await next(request)
        }
        
        let startTime = Date()
        
        // Log request
        logRequest(request)
        
        // Execute request
        let result: Result<HTTPResponse, Error>
        do {
            let response = try await next(request)
            result = .success(response)
        } catch {
            result = .failure(error)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        // Log response or error
        switch result {
        case .success(let response):
            logResponse(response, duration: duration)
            return response
            
        case .failure(let error):
            logError(error, duration: duration)
            throw error
        }
    }
    
    // MARK: - Logging Helpers
    
    private func logRequest(_ request: HTTPRequest) {
        var lines: [String] = []
        
        lines.append("📤 \(request.method) \(request.url.absoluteString)")
        
        if level.rawValue >= Level.headers.rawValue {
            if !request.headers.isEmpty {
                lines.append("Headers:")
                for (key, value) in request.headers.sorted(by: { $0.key < $1.key }) {
                    lines.append("  \(key): \(value)")
                }
            }
        }
        
        if level == .verbose, let body = request.body {
            if let json = try? JSONSerialization.jsonObject(with: body),
               let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                lines.append("Body:")
                lines.append(prettyString)
            } else if let string = String(data: body, encoding: .utf8) {
                lines.append("Body:")
                lines.append(string)
            }
        }
        
        logger(lines.joined(separator: "\n"))
    }
    
    private func logResponse(_ response: HTTPResponse, duration: TimeInterval) {
        var lines: [String] = []
        
        let statusEmoji = response.isSuccess ? "✅" : "❌"
        let durationMs = String(format: "%.0f ms", duration * 1000)
        lines.append("\(statusEmoji) \(response.statusCode) (\(durationMs))")
        
        if level.rawValue >= Level.headers.rawValue {
            if !response.headers.isEmpty {
                lines.append("Headers:")
                for (key, value) in response.headers.sorted(by: { $0.key < $1.key }) {
                    lines.append("  \(key): \(value)")
                }
            }
        }
        
        if level == .verbose {
            if let json = try? JSONSerialization.jsonObject(with: response.data),
               let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                lines.append("Body:")
                lines.append(prettyString)
            } else if let string = response.stringValue {
                lines.append("Body:")
                lines.append(string)
            }
        }
        
        logger(lines.joined(separator: "\n"))
    }
    
    private func logError(_ error: Error, duration: TimeInterval) {
        let durationMs = String(format: "%.0f ms", duration * 1000)
        logger("💥 Error (\(durationMs)): \(error.localizedDescription)")
    }
}

// MARK: - Level Ordering

private extension LoggingMiddleware.Level {
    var rawValue: Int {
        switch self {
        case .none: return 0
        case .basic: return 1
        case .headers: return 2
        case .verbose: return 3
        }
    }
}

// MARK: - Convenience Initializers

extension LoggingMiddleware {
    /// Creates a logging middleware with basic logging.
    public static var basic: LoggingMiddleware {
        LoggingMiddleware(level: .basic)
    }
    
    /// Creates a logging middleware with verbose logging.
    public static var verbose: LoggingMiddleware {
        LoggingMiddleware(level: .verbose)
    }
    
    /// Creates a logging middleware with header logging.
    public static var headers: LoggingMiddleware {
        LoggingMiddleware(level: .headers)
    }
}
