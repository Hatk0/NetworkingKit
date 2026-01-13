import Foundation

// MARK: - AI Stream Client

/// A client for streaming AI chat completions.
///
/// This is the main entry point for interacting with AI APIs.
/// It supports multiple providers through the AIProvider protocol.
///
/// Example:
/// ```swift
/// let client = AIStreamClient(
///     provider: OpenAIProvider(apiKey: "sk-..."),
///     streamingClient: URLSessionStreamingClient()
/// )
///
/// let messages = [
///     ChatMessage.system("You are a helpful assistant."),
///     ChatMessage.user("Explain Swift concurrency in simple terms.")
/// ]
///
/// for try await delta in client.stream(messages: messages, options: .gpt4()) {
///     print(delta.content ?? "", terminator: "")
/// }
/// print() // New line at end
/// ```
public final class AIStreamClient<Provider: AIProvider>: Sendable {
    private let provider: Provider
    private let streamingClient: StreamingHTTPClient
    private let sseParser: SSEParser
    
    /// Creates an AI stream client.
    ///
    /// - Parameters:
    ///   - provider: The AI provider to use
    ///   - streamingClient: The streaming HTTP client
    public init(
        provider: Provider,
        streamingClient: StreamingHTTPClient = URLSessionStreamingClient()
    ) {
        self.provider = provider
        self.streamingClient = streamingClient
        self.sseParser = SSEParser()
    }
    
    // MARK: - Streaming Chat
    
    /// Streams a chat completion.
    ///
    /// - Parameters:
    ///   - messages: The conversation messages
    ///   - options: Chat options including model, temperature, etc.
    /// - Returns: An async stream of chat deltas
    public func stream(
        messages: [ChatMessage],
        options: ChatOptions
    ) -> AsyncThrowingStream<ChatDelta, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var streamOptions = options
                    streamOptions.stream = true
                    
                    let request = try provider.buildRequest(messages: messages, options: streamOptions)
                    let dataStream = streamingClient.stream(request)
                    let eventStream = await sseParser.parse(dataStream)
                    
                    for try await event in eventStream {
                        if let delta = try provider.parseStreamEvent(event) {
                            continuation.yield(delta)
                            
                            // Stop if we received a finish signal
                            if delta.isFinished {
                                break
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: mapError(error))
                }
            }
        }
    }
    
    /// Streams a chat completion and collects the full response.
    ///
    /// - Parameters:
    ///   - messages: The conversation messages
    ///   - options: Chat options
    /// - Returns: The complete chat message
    public func chat(
        messages: [ChatMessage],
        options: ChatOptions
    ) async throws -> ChatMessage {
        var fullContent = ""
        var finalUsage: Usage?
        
        for try await delta in stream(messages: messages, options: options) {
            if let content = delta.content {
                fullContent += content
            }
            if let usage = delta.usage {
                finalUsage = usage
            }
        }
        
        return ChatMessage(role: .assistant, content: fullContent)
    }
    
    // MARK: - Non-Streaming Chat
    
    /// Performs a non-streaming chat completion.
    ///
    /// - Parameters:
    ///   - messages: The conversation messages
    ///   - options: Chat options
    /// - Returns: The complete response
    public func complete(
        messages: [ChatMessage],
        options: ChatOptions
    ) async throws -> ChatCompletion {
        var nonStreamOptions = options
        nonStreamOptions.stream = false
        
        let request = try provider.buildRequest(messages: messages, options: nonStreamOptions)
        
        // Use regular HTTP client for non-streaming
        let client = URLSessionHTTPClient()
        let response = try await client.execute(request)
        
        // Check for errors
        guard response.isSuccess else {
            throw mapHTTPError(response)
        }
        
        // Parse response (provider-specific)
        // For now, return a simple completion
        guard let text = response.stringValue else {
            throw AIError.parsingFailed("Empty response")
        }
        
        return ChatCompletion(
            id: UUID().uuidString,
            message: ChatMessage(role: .assistant, content: text),
            finishReason: .stop,
            usage: nil,
            model: options.model
        )
    }
    
    // MARK: - Error Handling
    
    private func mapError(_ error: Error) -> Error {
        if let aiError = error as? AIError {
            return aiError
        }
        if let networkError = error as? NetworkError {
            switch networkError {
            case .httpError(let statusCode, let data):
                return mapHTTPStatusError(statusCode: statusCode, data: data)
            case .timeout:
                return AIError.apiError(code: "timeout", message: "Request timed out")
            case .noConnection:
                return AIError.apiError(code: "no_connection", message: "No internet connection")
            default:
                return AIError.underlying(networkError)
            }
        }
        return AIError.underlying(error)
    }
    
    private func mapHTTPError(_ response: HTTPResponse) -> AIError {
        mapHTTPStatusError(statusCode: response.statusCode, data: response.data)
    }
    
    private func mapHTTPStatusError(statusCode: Int, data: Data?) -> AIError {
        switch statusCode {
        case 401:
            return .unauthorized
        case 429:
            return .rateLimited(retryAfter: nil)
        case 400:
            let message = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Bad request"
            return .invalidRequest(message)
        case 404:
            return .modelNotFound("Model not found")
        default:
            let message = data.flatMap { String(data: $0, encoding: .utf8) } ?? "HTTP \(statusCode)"
            return .apiError(code: "\(statusCode)", message: message)
        }
    }
}

// MARK: - Convenience Extensions

extension AIStreamClient {
    /// Streams a simple prompt.
    ///
    /// - Parameters:
    ///   - prompt: The user prompt
    ///   - model: The model to use
    /// - Returns: An async stream of content strings
    public func stream(
        prompt: String,
        model: String
    ) -> AsyncThrowingStream<String, Error> {
        let messages = [ChatMessage.user(prompt)]
        let options = ChatOptions(model: model)
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await delta in self.stream(messages: messages, options: options) {
                        if let content = delta.content {
                            continuation.yield(content)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Sends a simple prompt and collects the full response.
    ///
    /// - Parameters:
    ///   - prompt: The user prompt
    ///   - model: The model to use
    /// - Returns: The complete response text
    public func ask(
        prompt: String,
        model: String
    ) async throws -> String {
        let messages = [ChatMessage.user(prompt)]
        let options = ChatOptions(model: model)
        
        let response = try await chat(messages: messages, options: options)
        return response.content.text ?? ""
    }
}
