import Foundation

// MARK: - Claude Provider

/// Anthropic Claude API provider.
///
/// Supports:
/// - Claude 4.5 Opus, Sonnet
/// - Claude 4 Opus, Sonnet
/// - Vision (multimodal) models
///
/// Example:
/// ```swift
/// let provider = ClaudeProvider(apiKey: "sk-ant-...")
/// let client = AIStreamClient(provider: provider)
///
/// for try await delta in client.chat(messages: [...]) {
///     print(delta.content ?? "", terminator: "")
/// }
/// ```
public struct ClaudeProvider: AIProvider {
    public static let name = "Claude"
    
    public let apiKey: String
    public let baseURL: URL
    public let anthropicVersion: String
    
    /// Creates a Claude provider.
    ///
    /// - Parameters:
    ///   - apiKey: Your Anthropic API key
    ///   - baseURL: Custom base URL (for proxies)
    ///   - anthropicVersion: API version (default: 2023-06-01)
    public init(
        apiKey: String,
        baseURL: URL = URL(string: "https://api.anthropic.com/v1")!,
        anthropicVersion: String = "2023-06-01"
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.anthropicVersion = anthropicVersion
    }
    
    public var defaultHeaders: [String: String] {
        HeaderBuilder()
            .contentType(.json)
            .set("x-api-key", value: apiKey)
            .set("anthropic-version", value: anthropicVersion)
            .build()
    }
    
    public func buildRequest(messages: [ChatMessage], options: ChatOptions) throws -> HTTPRequest {
        // Extract system message (Claude handles it separately)
        let systemMessage = messages.first { $0.role == .system }?.content.text
        let conversationMessages = messages.filter { $0.role != .system }
        
        let body = ClaudeRequest(
            model: options.model,
            messages: conversationMessages.map { ClaudeMessage(from: $0) },
            system: systemMessage,
            maxTokens: options.maxTokens ?? 4096,
            temperature: options.temperature,
            topP: options.topP,
            stopSequences: options.stop,
            stream: options.stream
        )
        
        let bodyData = try JSONEncoder().encode(body)
        guard let bodyParams = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            throw AIError.invalidRequest("Failed to encode request body")
        }
        
        let endpoint = PostEndpoint(path: "messages", bodyParameters: bodyParams)
        
        return try RequestBuilder(baseURL: baseURL, defaultHeaders: defaultHeaders)
            .build(from: endpoint)
    }
    
    public func parseStreamEvent(_ event: SSEEvent) throws -> ChatDelta? {
        guard let data = event.data.data(using: .utf8) else {
            return nil
        }
        
        do {
            let response = try JSONDecoder().decode(ClaudeStreamEvent.self, from: data)
            
            switch response.type {
            case "content_block_delta":
                return ChatDelta(content: response.delta?.text)
                
            case "message_start":
                return ChatDelta(role: .assistant)
                
            case "message_stop":
                return ChatDelta(finishReason: .stop)
                
            case "message_delta":
                let finishReason: FinishReason? = response.delta?.stopReason.flatMap { reason in
                    switch reason {
                    case "end_turn": return .stop
                    case "max_tokens": return .length
                    case "stop_sequence": return .stop
                    default: return .other
                    }
                }
                
                let usage: Usage? = response.usage.map {
                    Usage(promptTokens: $0.inputTokens ?? 0, completionTokens: $0.outputTokens ?? 0)
                }
                
                return ChatDelta(finishReason: finishReason, usage: usage)
                
            case "error":
                throw AIError.apiError(
                    code: response.error?.type,
                    message: response.error?.message ?? "Unknown error"
                )
                
            default:
                return nil
            }
        } catch let error as AIError {
            throw error
        } catch {
            // Ignore parsing errors for unknown event types
            return nil
        }
    }
}

// MARK: - Claude API Types

private struct ClaudeRequest: Encodable {
    let model: String
    let messages: [ClaudeMessage]
    let system: String?
    let maxTokens: Int
    let temperature: Double?
    let topP: Double?
    let stopSequences: [String]?
    let stream: Bool
    
    enum CodingKeys: String, CodingKey {
        case model, messages, system, temperature, stream
        case maxTokens = "max_tokens"
        case topP = "top_p"
        case stopSequences = "stop_sequences"
    }
}

private struct ClaudeMessage: Encodable {
    let role: String
    let content: [ClaudeContent]
    
    init(from message: ChatMessage) {
        self.role = message.role.rawValue
        
        switch message.content {
        case .text(let text):
            self.content = [ClaudeContent.text(text)]
        case .parts(let parts):
            self.content = parts.map { ClaudeContent(from: $0) }
        }
    }
}

private enum ClaudeContent: Encodable {
    case text(String)
    case image(source: ClaudeImageSource)
    
    init(from part: ChatMessage.ContentPart) {
        switch part {
        case .text(let text):
            self = .text(text)
        case .image(let image):
            self = .image(source: ClaudeImageSource(from: image))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .image(let source):
            try container.encode("image", forKey: .type)
            try container.encode(source, forKey: .source)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case type, text, source
    }
}

private struct ClaudeImageSource: Encodable {
    let type: String
    let mediaType: String
    let data: String
    
    init(from image: ChatMessage.ImageContent) {
        self.type = "base64"
        self.mediaType = image.mediaType ?? "image/jpeg"
        self.data = image.source
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case mediaType = "media_type"
        case data
    }
}

private struct ClaudeStreamEvent: Decodable {
    let type: String
    let delta: Delta?
    let usage: UsageInfo?
    let error: ErrorInfo?
    
    struct Delta: Decodable {
        let type: String?
        let text: String?
        let stopReason: String?
        
        enum CodingKeys: String, CodingKey {
            case type, text
            case stopReason = "stop_reason"
        }
    }
    
    struct UsageInfo: Decodable {
        let inputTokens: Int?
        let outputTokens: Int?
        
        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }
    
    struct ErrorInfo: Decodable {
        let type: String?
        let message: String?
    }
}
