import Foundation

/// Protocol defining the core HTTP client interface.
///
/// `HTTPClient` provides an abstraction over network execution,
/// allowing for different implementations (URLSession, mocks, etc.)
/// and middleware injection.
///
/// Implementations must be thread-safe and support async/await.
public protocol HTTPClient: Sendable {
    /// Executes an HTTP request asynchronously.
    ///
    /// - Parameter request: The HTTP request to execute
    /// - Returns: The HTTP response
    /// - Throws: `NetworkError` if the request fails
    func execute(_ request: HTTPRequest) async throws -> HTTPResponse
}

// MARK: - URLSession-based Implementation

/// A concrete HTTPClient implementation using URLSession.
///
/// `URLSessionHTTPClient` is the default implementation that uses
/// Apple's URLSession for network operations. It supports all standard
/// URLSession features including background transfers, authentication,
/// and certificate pinning.
///
/// Example:
/// ```swift
/// let config = NetworkConfiguration(
///     baseURL: URL(string: "https://api.example.com")!
/// )
/// let client = URLSessionHTTPClient(configuration: config)
/// let response = try await client.execute(request)
/// ```
public final class URLSessionHTTPClient: HTTPClient {
    
    private let session: URLSession
    private let configuration: NetworkConfiguration
    private let delegate: SessionDelegate
    
    /// Initializes a new URLSession-based HTTP client.
    ///
    /// - Parameter configuration: The network configuration to use
    public init(configuration: NetworkConfiguration = .default) {
        self.configuration = configuration
        self.delegate = SessionDelegate(pinnedCertificates: configuration.pinnedCertificates)
        
        // Configure URLSession with our delegate for certificate pinning
        let sessionConfig = configuration.sessionConfiguration
        sessionConfig.timeoutIntervalForRequest = configuration.timeoutInterval
        sessionConfig.httpAdditionalHeaders = configuration.defaultHeaders
        
        self.session = URLSession(
            configuration: sessionConfig,
            delegate: delegate,
            delegateQueue: nil
        )
    }
    
    deinit {
        session.invalidateAndCancel()
    }
    
    public func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        // Merge configuration default headers with request headers
        let mergedHeaders = configuration.defaultHeaders.merging(request.headers) { _, new in new }
        let finalRequest = request.headers(mergedHeaders)
        
        // Convert to URLRequest
        let urlRequest = finalRequest.toURLRequest()
        
        // Log request if enabled
        if configuration.enableLogging {
            logRequest(urlRequest, level: configuration.logLevel)
        }
        
        // Execute request
        let (data, urlResponse): (Data, URLResponse)
        do {
            (data, urlResponse) = try await session.data(for: urlRequest)
        } catch let error as URLError {
            throw NetworkError.from(urlError: error)
        } catch {
            throw NetworkError.underlying(error)
        }
        
        // Create HTTPResponse
        let response: HTTPResponse
        do {
            response = try HTTPResponse(data: data, urlResponse: urlResponse)
        } catch {
            throw error
        }
        
        // Log response if enabled
        if configuration.enableLogging {
            logResponse(response, level: configuration.logLevel)
        }
        
        // Check for HTTP errors
        if !response.isSuccess {
            throw NetworkError.httpError(statusCode: response.statusCode, data: data)
        }
        
        return response
    }
    
    // MARK: - Logging
    
    private func logRequest(_ request: URLRequest, level: LogLevel) {
        guard level != .none else { return }
        
        print("\nHTTP Request")
        print("URL: \(request.url?.absoluteString ?? "nil")")
        print("Method: \(request.httpMethod ?? "nil")")
        
        if level.rawValue >= LogLevel.info.rawValue {
            print("Headers: \(request.allHTTPHeaderFields ?? [:])")
        }
        
        if level == .verbose, let body = request.httpBody {
            print("Body: \(String(data: body, encoding: .utf8) ?? "binary data")")
        }
        
        if level == .verbose {
            print("cURL: \(request.curlString)")
        }
    }
    
    private func logResponse(_ response: HTTPResponse, level: LogLevel) {
        guard level != .none else { return }
        
        print("\nHTTP Response")
        print("Status: \(response.statusCode)")
        
        if level.rawValue >= LogLevel.info.rawValue {
            print("Headers: \(response.headers)")
        }
        
        if level == .verbose {
            if let json = try? JSONSerialization.jsonObject(with: response.data),
               let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                print("Body: \(prettyString)")
            } else if let string = response.stringValue {
                print("Body: \(string)")
            }
        }
    }
}

// MARK: - Session Delegate for Certificate Pinning

private final class SessionDelegate: NSObject, URLSessionDelegate {
    
    private let pinnedCertificates: [Data]
    
    init(pinnedCertificates: [Data]) {
        self.pinnedCertificates = pinnedCertificates
    }
    
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Only handle server trust challenges
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // If no certificates are pinned, use default validation
        guard !pinnedCertificates.isEmpty else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // Validate certificate pinning
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // Get server certificate chain (modern API)
        guard let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
              let serverCertificate = certificateChain.first else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        let serverCertificateData = SecCertificateCopyData(serverCertificate) as Data
        
        // Check if server certificate matches any pinned certificate
        if pinnedCertificates.contains(serverCertificateData) {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

// MARK: - URLRequest Extensions

private extension URLRequest {
    
    /// Generates a cURL command string for debugging.
    var curlString: String {
        guard let url = url else { return "" }
        
        var components = ["curl -v"]
        
        if let method = httpMethod, method != "GET" {
            components.append("-X \(method)")
        }
        
        if let headers = allHTTPHeaderFields {
            for (key, value) in headers {
                let escapedValue = value.replacingOccurrences(of: "\"", with: "\\\"")
                components.append("-H \"\(key): \(escapedValue)\"")
            }
        }
        
        if let body = httpBody, let bodyString = String(data: body, encoding: .utf8) {
            let escapedBody = bodyString.replacingOccurrences(of: "\"", with: "\\\"")
            components.append("-d \"\(escapedBody)\"")
        }
        
        components.append("\"\(url.absoluteString)\"")
        
        return components.joined(separator: " \\\n\t")
    }
}
