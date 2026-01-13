import Foundation

// MARK: - AI Provider Protocol

/// Protocol that defines an AI chat provider.
///
/// Implement this protocol to add support for any AI API that uses
/// streaming chat completions (OpenAI, Claude, Gemini, etc.).
///
/// Example:
/// ```swift
/// struct MyProvider: AIProvider {
///     static var name: String { "MyAI" }
///     var baseURL: URL { URL(string: "https://api.myai.com")! }
///     // ... implement other requirements
/// }
/// ```
public protocol AIProvider: Sendable {
    /// The name of the provider (for logging).
    static var name: String { get }
    
    /// The base URL for the API.
    var baseURL: URL { get }
    
    /// The API key for authentication.
    var apiKey: String { get }
    
    /// Builds an HTTP request for a chat completion.
    ///
    /// - Parameters:
    ///   - messages: The conversation messages
    ///   - options: Chat options (model, temperature, etc.)
    /// - Returns: The configured HTTP request
    func buildRequest(messages: [ChatMessage], options: ChatOptions) throws -> HTTPRequest
    
    /// Parses an SSE event into a chat delta.
    ///
    /// - Parameter event: The SSE event to parse
    /// - Returns: The parsed delta, or nil if not a content event
    func parseStreamEvent(_ event: SSEEvent) throws -> ChatDelta?
    
    /// Returns the default headers for this provider.
    var defaultHeaders: [String: String] { get }
}

// MARK: - Default Implementation

extension AIProvider {
    public var defaultHeaders: [String: String] {
        [
            "Content-Type": "application/json",
            "Accept": "text/event-stream"
        ]
    }
}

// MARK: - AI Error

/// Errors specific to AI API operations.
public enum AIError: Error, LocalizedError {
    /// The API returned an error.
    case apiError(code: String?, message: String)
    
    /// Rate limit exceeded.
    case rateLimited(retryAfter: TimeInterval?)
    
    /// Invalid API key or unauthorized.
    case unauthorized
    
    /// The model is not available.
    case modelNotFound(String)
    
    /// Content was filtered/blocked.
    case contentFiltered
    
    /// Invalid request parameters.
    case invalidRequest(String)
    
    /// Failed to parse streaming response.
    case parsingFailed(String)
    
    /// Context length exceeded.
    case contextLengthExceeded
    
    /// Network or unknown error.
    case underlying(Error)
    
    public var errorDescription: String? {
        switch self {
        case .apiError(let code, let message):
            if let code = code {
                return "API Error [\(code)]: \(message)"
            }
            return "API Error: \(message)"
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Rate limited. Retry after \(Int(seconds)) seconds."
            }
            return "Rate limited. Please try again later."
        case .unauthorized:
            return "Invalid API key or unauthorized access."
        case .modelNotFound(let model):
            return "Model '\(model)' not found or not accessible."
        case .contentFiltered:
            return "Content was filtered due to safety settings."
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        case .parsingFailed(let message):
            return "Failed to parse response: \(message)"
        case .contextLengthExceeded:
            return "Context length exceeded. Try reducing message history."
        case .underlying(let error):
            return "Error: \(error.localizedDescription)"
        }
    }
}
