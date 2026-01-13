import Foundation

// MARK: - Gemini Provider

/// Google Gemini API provider.
///
/// Supports:
/// - Gemini 3.0 Pro, Gemini 3.0 Flash
/// - Gemini 2.0 Pro, Gemini 2.0 Flash
/// - Vision (multimodal) models
///
/// Example:
/// ```swift
/// let provider = GeminiProvider(apiKey: "...")
/// let client = AIStreamClient(provider: provider)
///
/// for try await delta in client.chat(messages: [...]) {
///     print(delta.content ?? "", terminator: "")
/// }
/// ```
public struct GeminiProvider: AIProvider {
    public static let name = "Gemini"
    
    public let apiKey: String
    public let baseURL: URL
    
    /// Creates a Gemini provider.
    ///
    /// - Parameters:
    ///   - apiKey: Your Google AI API key
    ///   - baseURL: Custom base URL
    public init(
        apiKey: String,
        baseURL: URL = URL(string: "https://generativelanguage.googleapis.com/v1beta")!
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
    }
    
    public var defaultHeaders: [String: String] {
        HeaderBuilder()
            .contentType(.json)
            .build()
    }
    
    public func buildRequest(messages: [ChatMessage], options: ChatOptions) throws -> HTTPRequest {
        let action = options.stream ? "streamGenerateContent" : "generateContent"
        
        // Convert messages to Gemini format
        let contents = convertMessagesToContents(messages)
        
        // Extract system instruction
        let systemInstruction = messages.first { $0.role == .system }?.content.text
        
        let body = GeminiRequest(
            contents: contents,
            systemInstruction: systemInstruction.map { GeminiSystemInstruction(parts: [GeminiPart.text($0)]) },
            generationConfig: GeminiGenerationConfig(
                temperature: options.temperature,
                topP: options.topP,
                maxOutputTokens: options.maxTokens,
                stopSequences: options.stop
            )
        )
        
        // Encode body to dictionary for RequestBuilder
        let bodyData = try JSONEncoder().encode(body)
        guard let bodyParams = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            throw AIError.invalidRequest("Failed to encode request body")
        }
        
        let endpoint = GeminiEndpoint(
            model: options.model,
            action: action,
            apiKey: apiKey,
            isStream: options.stream,
            bodyParameters: bodyParams
        )
        
        return try RequestBuilder(baseURL: baseURL, defaultHeaders: defaultHeaders)
            .build(from: endpoint)
    }

    private struct GeminiEndpoint: Endpoint {
        let model: String
        let action: String
        let apiKey: String
        let isStream: Bool
        let bodyParameters: [String: Any]?
        
        var path: String {
            "models/\(model)/\(action)"
        }
        
        var method: HTTPMethod { .post }
        
        var queryParameters: [String: Any]? {
            var params = ["key": apiKey]
            if isStream {
                params["alt"] = "sse"
            }
            return params
        }
    }
    
    private func convertMessagesToContents(_ messages: [ChatMessage]) -> [GeminiContent] {
        messages
            .filter { $0.role != .system } // System is handled separately
            .map { message in
                let role: String = message.role == .assistant ? "model" : "user"
                let parts: [GeminiPart]
                
                switch message.content {
                case .text(let text):
                    parts = [.text(text)]
                case .parts(let contentParts):
                    parts = contentParts.map { part in
                        switch part {
                        case .text(let text):
                            return .text(text)
                        case .image(let image):
                            return .inlineData(GeminiInlineData(
                                mimeType: image.mediaType ?? "image/jpeg",
                                data: image.source
                            ))
                        }
                    }
                }
                
                return GeminiContent(role: role, parts: parts)
            }
    }
    
    public func parseStreamEvent(_ event: SSEEvent) throws -> ChatDelta? {
        guard !event.data.isEmpty else {
            return nil
        }
        
        guard let data = event.data.data(using: .utf8) else {
            return nil
        }
        
        do {
            let response = try JSONDecoder().decode(GeminiStreamResponse.self, from: data)
            
            guard let candidate = response.candidates?.first else {
                // Check for error
                if let error = response.error {
                    throw AIError.apiError(code: "\(error.code)", message: error.message)
                }
                return nil
            }
            
            // Extract text from parts
            let content = candidate.content?.parts?.compactMap { part -> String? in
                if case .text(let text) = part {
                    return text
                }
                return nil
            }.joined()
            
            // Map finish reason
            let finishReason: FinishReason? = candidate.finishReason.flatMap { reason in
                switch reason {
                case "STOP": return .stop
                case "MAX_TOKENS": return .length
                case "SAFETY": return .contentFilter
                default: return .other
                }
            }
            
            // Usage stats
            let usage: Usage? = response.usageMetadata.map {
                Usage(
                    promptTokens: $0.promptTokenCount ?? 0,
                    completionTokens: $0.candidatesTokenCount ?? 0
                )
            }
            
            return ChatDelta(
                content: content?.isEmpty == false ? content : nil,
                finishReason: finishReason,
                usage: usage
            )
        } catch let error as AIError {
            throw error
        } catch {
            throw AIError.parsingFailed("Failed to parse Gemini response: \(error)")
        }
    }
}

// MARK: - Gemini API Types

private struct GeminiRequest: Encodable {
    let contents: [GeminiContent]
    let systemInstruction: GeminiSystemInstruction?
    let generationConfig: GeminiGenerationConfig?
}

private struct GeminiContent: Encodable {
    let role: String
    let parts: [GeminiPart]
}

private struct GeminiSystemInstruction: Encodable {
    let parts: [GeminiPart]
}

private enum GeminiPart: Encodable {
    case text(String)
    case inlineData(GeminiInlineData)
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode(text, forKey: .text)
        case .inlineData(let data):
            try container.encode(data, forKey: .inlineData)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case text
        case inlineData = "inline_data"
    }
}

private struct GeminiInlineData: Encodable {
    let mimeType: String
    let data: String
    
    enum CodingKeys: String, CodingKey {
        case mimeType = "mime_type"
        case data
    }
}

private struct GeminiGenerationConfig: Encodable {
    let temperature: Double?
    let topP: Double?
    let maxOutputTokens: Int?
    let stopSequences: [String]?
}

private struct GeminiStreamResponse: Decodable {
    let candidates: [Candidate]?
    let usageMetadata: UsageMetadata?
    let error: ErrorInfo?
    
    struct Candidate: Decodable {
        let content: Content?
        let finishReason: String?
    }
    
    struct Content: Decodable {
        let parts: [Part]?
        let role: String?
    }
    
    enum Part: Decodable {
        case text(String)
        case other
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let text = try container.decodeIfPresent(String.self, forKey: .text) {
                self = .text(text)
            } else {
                self = .other
            }
        }
        
        enum CodingKeys: String, CodingKey {
            case text
        }
    }
    
    struct UsageMetadata: Decodable {
        let promptTokenCount: Int?
        let candidatesTokenCount: Int?
    }
    
    struct ErrorInfo: Decodable {
        let code: Int
        let message: String
    }
}
