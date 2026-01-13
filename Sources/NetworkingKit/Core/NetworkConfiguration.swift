import Foundation

/// Configuration for network clients.
///
/// `NetworkConfiguration` encapsulates all settings needed to configure
/// an HTTP client, including base URL, default headers, timeouts, and more.
///
/// Example:
/// ```swift
/// let config = NetworkConfiguration(
///     baseURL: URL(string: "https://api.example.com")!,
///     defaultHeaders: ["User-Agent": "MyApp/1.0"]
/// )
/// ```
public struct NetworkConfiguration: Sendable {
    /// The base URL for all requests.
    public let baseURL: URL?
    
    /// Default headers to include in all requests.
    public let defaultHeaders: [String: String]
    
    /// Default timeout interval for requests.
    public let timeoutInterval: TimeInterval
    
    /// URLSession configuration to use.
    public let sessionConfiguration: URLSessionConfiguration
    
    /// Whether to enable request/response logging.
    public let enableLogging: Bool
    
    /// Log level for network operations.
    public let logLevel: LogLevel
    
    /// SSL pinning certificates (DER-encoded).
    public let pinnedCertificates: [Data]
    
    /// Initializes a new network configuration.
    ///
    /// - Parameters:
    ///   - baseURL: Base URL for all requests (default: nil)
    ///   - defaultHeaders: Default headers (default: empty)
    ///   - timeoutInterval: Request timeout (default: 60 seconds)
    ///   - sessionConfiguration: URLSession configuration (default: .default)
    ///   - enableLogging: Enable logging (default: false)
    ///   - logLevel: Log level (default: .none)
    ///   - pinnedCertificates: SSL certificates for pinning (default: empty)
    public init(
        baseURL: URL? = nil,
        defaultHeaders: [String: String] = [:],
        timeoutInterval: TimeInterval = 60.0,
        sessionConfiguration: URLSessionConfiguration = .default,
        enableLogging: Bool = false,
        logLevel: LogLevel = .none,
        pinnedCertificates: [Data] = []
    ) {
        self.baseURL = baseURL
        self.defaultHeaders = defaultHeaders
        self.timeoutInterval = timeoutInterval
        self.sessionConfiguration = sessionConfiguration
        self.enableLogging = enableLogging
        self.logLevel = logLevel
        self.pinnedCertificates = pinnedCertificates
    }
}

// MARK: - Log Level

/// Logging verbosity levels.
public enum LogLevel: Int, Sendable {
    /// No logging.
    case none = 0
    
    /// Log only errors.
    case error = 1
    
    /// Log errors and basic request/response info.
    case info = 2
    
    /// Log everything including headers and bodies.
    case verbose = 3
}

// MARK: - Default Configurations

extension NetworkConfiguration {
    
    /// A configuration suitable for development with verbose logging.
    public static var development: NetworkConfiguration {
        NetworkConfiguration(
            enableLogging: true,
            logLevel: .verbose
        )
    }
    
    /// A configuration suitable for production with minimal logging.
    public static var production: NetworkConfiguration {
        NetworkConfiguration(
            enableLogging: true,
            logLevel: .error
        )
    }
    
    /// A configuration with logging completely disabled.
    public static var `default`: NetworkConfiguration {
        NetworkConfiguration()
    }
}

// MARK: - Builder Pattern

extension NetworkConfiguration {
    
    /// Returns a new configuration with the specified base URL.
    public func baseURL(_ url: URL?) -> NetworkConfiguration {
        NetworkConfiguration(
            baseURL: url,
            defaultHeaders: defaultHeaders,
            timeoutInterval: timeoutInterval,
            sessionConfiguration: sessionConfiguration,
            enableLogging: enableLogging,
            logLevel: logLevel,
            pinnedCertificates: pinnedCertificates
        )
    }
    
    /// Returns a new configuration with the specified default headers.
    public func defaultHeaders(_ headers: [String: String]) -> NetworkConfiguration {
        NetworkConfiguration(
            baseURL: baseURL,
            defaultHeaders: headers,
            timeoutInterval: timeoutInterval,
            sessionConfiguration: sessionConfiguration,
            enableLogging: enableLogging,
            logLevel: logLevel,
            pinnedCertificates: pinnedCertificates
        )
    }
    
    /// Returns a new configuration with the specified timeout.
    public func timeout(_ interval: TimeInterval) -> NetworkConfiguration {
        NetworkConfiguration(
            baseURL: baseURL,
            defaultHeaders: defaultHeaders,
            timeoutInterval: interval,
            sessionConfiguration: sessionConfiguration,
            enableLogging: enableLogging,
            logLevel: logLevel,
            pinnedCertificates: pinnedCertificates
        )
    }
    
    /// Returns a new configuration with the specified log level.
    public func logLevel(_ level: LogLevel) -> NetworkConfiguration {
        NetworkConfiguration(
            baseURL: baseURL,
            defaultHeaders: defaultHeaders,
            timeoutInterval: timeoutInterval,
            sessionConfiguration: sessionConfiguration,
            enableLogging: level != .none,
            logLevel: level,
            pinnedCertificates: pinnedCertificates
        )
    }
    
    /// Returns a new configuration with the specified certificate pinning.
    public func certificatePinning(_ certificates: [Data]) -> NetworkConfiguration {
        NetworkConfiguration(
            baseURL: baseURL,
            defaultHeaders: defaultHeaders,
            timeoutInterval: timeoutInterval,
            sessionConfiguration: sessionConfiguration,
            enableLogging: enableLogging,
            logLevel: logLevel,
            pinnedCertificates: certificates
        )
    }
}
