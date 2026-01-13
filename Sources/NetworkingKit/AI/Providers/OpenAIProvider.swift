import Foundation

// MARK: - OpenAI Provider

/// OpenAI API provider for GPT models.
///
/// Supports:
/// - GPT-5.2, GPT-5, o3
/// - GPT-4o, GPT-4 Turbo
/// - Vision (multimodal) models
///
/// Example:
/// ```swift
/// let provider = OpenAIProvider(apiKey: "sk-...")
/// let client = AIStreamClient(provider: provider)
///
/// for try await delta in client.chat(messages: [...]) {
///     print(delta.content ?? "", terminator: "")
/// }
/// ```
public struct OpenAIProvider: AIProvider {
    public static let name = "OpenAI"
    
    public let apiKey: String
    public let organizationId: String?
    public let baseURL: URL
    
    /// Creates an OpenAI provider.
    ///
    /// - Parameters:
    ///   - apiKey: Your OpenAI API key
    ///   - organizationId: Optional organization ID
    ///   - baseURL: Custom base URL (for Azure OpenAI or proxies)
    public init(
        apiKey: String,
        organizationId: String? = nil,
        baseURL: URL = URL(string: "https://api.openai.com/v1")!
    ) {
        self.apiKey = apiKey
        self.organizationId = organizationId
        self.baseURL = baseURL
    }
    
    public var defaultHeaders: [String: String] {
        var builder = HeaderBuilder()
            .contentType(.json)
            .authorization(.bearer(apiKey))
        
        if let orgId = organizationId {
            builder = builder.set("OpenAI-Organization", value: orgId)
        }
        return builder.build()
    }
    
    public func buildRequest(messages: [ChatMessage], options: ChatOptions) throws -> HTTPRequest {
        let body = OpenAIRequest(
            model: options.model,
            messages: messages.map { OpenAIMessage(from: $0) },
            temperature: options.temperature,
            maxTokens: options.maxTokens,
            topP: options.topP,
            stop: options.stop,
            stream: options.stream
        )
        
        let bodyData = try JSONEncoder().encode(body)
        guard let bodyParams = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            throw AIError.invalidRequest("Failed to encode request body")
        }
        
        let endpoint = PostEndpoint(path: "chat/completions", bodyParameters: bodyParams)
        
        return try RequestBuilder(baseURL: baseURL, defaultHeaders: defaultHeaders)
            .build(from: endpoint)
    }
    
    public func parseStreamEvent(_ event: SSEEvent) throws -> ChatDelta? {
        // Check for stream termination
        if event.isDone {
            return ChatDelta(finishReason: .stop)
        }
        
        // Parse the JSON data
        guard let data = event.data.data(using: .utf8) else {
            return nil
        }
        
        do {
            let response = try JSONDecoder().decode(OpenAIStreamResponse.self, from: data)
            
            guard let choice = response.choices.first else {
                return nil
            }
            
            let finishReason: FinishReason? = choice.finishReason.flatMap { reason in
                FinishReason(rawValue: reason) ?? .other
            }
            
            return ChatDelta(
                content: choice.delta.content,
                role: choice.delta.role.flatMap { ChatMessage.Role(rawValue: $0) },
                finishReason: finishReason,
                usage: response.usage.map { Usage(promptTokens: $0.promptTokens, completionTokens: $0.completionTokens) }
            )
        } catch {
            throw AIError.parsingFailed("Failed to parse OpenAI response: \(error)")
        }
    }
}

// MARK: - OpenAI API Types

private struct OpenAIRequest: Encodable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double?
    let maxTokens: Int?
    let topP: Double?
    let stop: [String]?
    let stream: Bool
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, stop, stream
        case maxTokens = "max_tokens"
        case topP = "top_p"
    }
}

private struct OpenAIMessage: Encodable {
    let role: String
    let content: OpenAIContent
    
    init(from message: ChatMessage) {
        self.role = message.role.rawValue
        
        switch message.content {
        case .text(let text):
            self.content = .text(text)
        case .parts(let parts):
            self.content = .parts(parts.map { OpenAIContentPart(from: $0) })
        }
    }
}

private enum OpenAIContent: Encodable {
    case text(String)
    case parts([OpenAIContentPart])
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let string):
            try container.encode(string)
        case .parts(let parts):
            try container.encode(parts)
        }
    }
}

private struct OpenAIContentPart: Encodable {
    let type: String
    let text: String?
    let imageUrl: ImageURL?
    
    init(from part: ChatMessage.ContentPart) {
        switch part {
        case .text(let text):
            self.type = "text"
            self.text = text
            self.imageUrl = nil
        case .image(let image):
            self.type = "image_url"
            self.text = nil
            switch image.type {
            case .url:
                self.imageUrl = ImageURL(url: image.source)
            case .base64:
                let dataUrl = "data:\(image.mediaType ?? "image/jpeg");base64,\(image.source)"
                self.imageUrl = ImageURL(url: dataUrl)
            }
        }
    }
    
    struct ImageURL: Encodable {
        let url: String
    }
    
    enum CodingKeys: String, CodingKey {
        case type, text
        case imageUrl = "image_url"
    }
}

private struct OpenAIStreamResponse: Decodable {
    let id: String
    let choices: [Choice]
    let usage: UsageResponse?
    
    struct Choice: Decodable {
        let delta: Delta
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case delta
            case finishReason = "finish_reason"
        }
    }
    
    struct Delta: Decodable {
        let role: String?
        let content: String?
    }
    
    struct UsageResponse: Decodable {
        let promptTokens: Int
        let completionTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
        }
    }
}
