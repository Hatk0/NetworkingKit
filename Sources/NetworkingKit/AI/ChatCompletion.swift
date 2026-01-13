import Foundation

// MARK: - Chat Completion

/// Represents a complete chat completion response.
public struct ChatCompletion: Sendable {
    /// Unique identifier for the completion.
    public let id: String
    
    /// The generated message.
    public let message: ChatMessage
    
    /// The reason the generation stopped.
    public let finishReason: FinishReason?
    
    /// Token usage statistics.
    public let usage: Usage?
    
    /// The model used for generation.
    public let model: String?
    
    public init(
        id: String,
        message: ChatMessage,
        finishReason: FinishReason? = nil,
        usage: Usage? = nil,
        model: String? = nil
    ) {
        self.id = id
        self.message = message
        self.finishReason = finishReason
        self.usage = usage
        self.model = model
    }
}

// MARK: - Chat Delta

/// Represents a streaming chunk of a chat completion.
///
/// When streaming, the AI response arrives token-by-token.
/// Each delta contains a partial piece of the full response.
public struct ChatDelta: Sendable {
    /// Partial content token.
    public let content: String?
    
    /// The role (usually only in first delta).
    public let role: ChatMessage.Role?
    
    /// Reason for finishing (only in final delta).
    public let finishReason: FinishReason?
    
    /// Token usage (only in final delta for some providers).
    public let usage: Usage?
    
    public init(
        content: String? = nil,
        role: ChatMessage.Role? = nil,
        finishReason: FinishReason? = nil,
        usage: Usage? = nil
    ) {
        self.content = content
        self.role = role
        self.finishReason = finishReason
        self.usage = usage
    }
    
    /// Returns true if this is the final delta.
    public var isFinished: Bool {
        finishReason != nil
    }
}

// MARK: - Finish Reason

/// The reason a generation stopped.
public enum FinishReason: String, Codable, Sendable {
    /// Natural end of generation.
    case stop
    
    /// Maximum token limit reached.
    case length
    
    /// Content was filtered.
    case contentFilter = "content_filter"
    
    /// Tool/function call requested.
    case toolCalls = "tool_calls"
    
    /// Unknown or provider-specific reason.
    case other
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = FinishReason(rawValue: value) ?? .other
    }
}

// MARK: - Usage

/// Token usage statistics for a completion.
public struct Usage: Codable, Sendable {
    /// Number of tokens in the prompt.
    public let promptTokens: Int
    
    /// Number of tokens in the completion.
    public let completionTokens: Int
    
    /// Total tokens used.
    public var totalTokens: Int {
        promptTokens + completionTokens
    }
    
    public init(promptTokens: Int, completionTokens: Int) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
    }
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
    }
}

// MARK: - Chat Options

/// Options for configuring chat completions.
public struct ChatOptions: Sendable {
    /// The model to use.
    public var model: String
    
    /// Sampling temperature (0.0 - 2.0).
    public var temperature: Double?
    
    /// Maximum tokens to generate.
    public var maxTokens: Int?
    
    /// Top-p sampling.
    public var topP: Double?
    
    /// Stop sequences.
    public var stop: [String]?
    
    /// Whether to stream the response.
    public var stream: Bool
    
    public init(
        model: String,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        topP: Double? = nil,
        stop: [String]? = nil,
        stream: Bool = true
    ) {
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.topP = topP
        self.stop = stop
        self.stream = stream
    }
}

// MARK: - Common Models

extension ChatOptions {
    
    // MARK: OpenAI Models (Late 2026)
    public static func gpt52(_ options: ChatOptions = ChatOptions(model: "gpt-5.2")) -> ChatOptions {
        var opts = options
        opts.model = "gpt-5.2"
        return opts
    }
    
    public static func gpt5(_ options: ChatOptions = ChatOptions(model: "gpt-5")) -> ChatOptions {
        var opts = options
        opts.model = "gpt-5"
        return opts
    }
    
    // MARK: Claude Models (Late 2026)
    public static func claude45Opus(_ options: ChatOptions = ChatOptions(model: "claude-4.5-opus")) -> ChatOptions {
        var opts = options
        opts.model = "claude-4.5-opus"
        return opts
    }
    
    public static func claude45Sonnet(_ options: ChatOptions = ChatOptions(model: "claude-4.5-sonnet")) -> ChatOptions {
        var opts = options
        opts.model = "claude-4.5-sonnet"
        return opts
    }
    
    public static func claude4Sonnet(_ options: ChatOptions = ChatOptions(model: "claude-4-sonnet")) -> ChatOptions {
        var opts = options
        opts.model = "claude-4-sonnet"
        return opts
    }
    
    // MARK: Gemini Models (Late 2026)
    public static func gemini3Pro(_ options: ChatOptions = ChatOptions(model: "gemini-3.0-pro")) -> ChatOptions {
        var opts = options
        opts.model = "gemini-3.0-pro"
        return opts
    }
    
    public static func gemini3Flash(_ options: ChatOptions = ChatOptions(model: "gemini-3.0-flash")) -> ChatOptions {
        var opts = options
        opts.model = "gemini-3.0-flash"
        return opts
    }
    
    public static func gemini2Pro(_ options: ChatOptions = ChatOptions(model: "gemini-2.0-pro")) -> ChatOptions {
        var opts = options
        opts.model = "gemini-2.0-pro"
        return opts
    }
}
