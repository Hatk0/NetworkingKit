import Foundation

// MARK: - Chat Message

/// Represents a message in a chat conversation.
///
/// This is a universal type that works with all AI providers
/// (OpenAI, Claude, Gemini, etc.).
public struct ChatMessage: Codable, Sendable, Equatable {
    /// The role of the message sender.
    public let role: Role
    
    /// The content of the message.
    public let content: Content
    
    /// Optional name for the message author.
    public let name: String?
    
    /// Creates a text chat message.
    ///
    /// - Parameters:
    ///   - role: The role of the sender
    ///   - content: The text content
    ///   - name: Optional author name
    public init(role: Role, content: String, name: String? = nil) {
        self.role = role
        self.content = .text(content)
        self.name = name
    }
    
    /// Creates a chat message with structured content.
    ///
    /// - Parameters:
    ///   - role: The role of the sender
    ///   - content: The structured content
    ///   - name: Optional author name
    public init(role: Role, content: Content, name: String? = nil) {
        self.role = role
        self.content = content
        self.name = name
    }
    
    // MARK: - Role
    
    /// The role of a message sender in a conversation.
    public enum Role: String, Codable, Sendable {
        /// System instructions that guide the AI's behavior.
        case system
        
        /// Messages from the user.
        case user
        
        /// Responses from the AI assistant.
        case assistant
        
        /// Tool/function call results.
        case tool
    }
    
    // MARK: - Content
    
    /// The content of a chat message.
    public enum Content: Codable, Sendable, Equatable {
        /// Plain text content.
        case text(String)
        
        /// Multiple content parts (for multimodal messages).
        case parts([ContentPart])
        
        /// Extracts the text content if available.
        public var text: String? {
            switch self {
            case .text(let string):
                return string
            case .parts(let parts):
                return parts.compactMap { part in
                    if case .text(let text) = part {
                        return text
                    }
                    return nil
                }.joined()
            }
        }
    }
    
    // MARK: - Content Part
    
    /// A part of a multimodal message.
    public enum ContentPart: Codable, Sendable, Equatable {
        /// Text content.
        case text(String)
        
        /// Image content with base64 data or URL.
        case image(ImageContent)
    }
    
    // MARK: - Image Content
    
    /// Image content for multimodal messages.
    public struct ImageContent: Codable, Sendable, Equatable {
        /// The image source type.
        public let type: ImageType
        
        /// The image data or URL.
        public let source: String
        
        /// The MIME type of the image.
        public let mediaType: String?
        
        public init(type: ImageType, source: String, mediaType: String? = nil) {
            self.type = type
            self.source = source
            self.mediaType = mediaType
        }
        
        /// Creates image content from base64-encoded data.
        public static func base64(_ data: String, mediaType: String) -> ImageContent {
            ImageContent(type: .base64, source: data, mediaType: mediaType)
        }
        
        /// Creates image content from a URL.
        public static func url(_ urlString: String) -> ImageContent {
            ImageContent(type: .url, source: urlString, mediaType: nil)
        }
        
        public enum ImageType: String, Codable, Sendable {
            case base64
            case url
        }
    }
}

// MARK: - Convenience Initializers

extension ChatMessage {
    /// Creates a system message.
    public static func system(_ content: String) -> ChatMessage {
        ChatMessage(role: .system, content: content)
    }
    
    /// Creates a user message.
    public static func user(_ content: String) -> ChatMessage {
        ChatMessage(role: .user, content: content)
    }
    
    /// Creates an assistant message.
    public static func assistant(_ content: String) -> ChatMessage {
        ChatMessage(role: .assistant, content: content)
    }
    
    /// Creates a user message with an image.
    public static func user(text: String, imageURL: String) -> ChatMessage {
        ChatMessage(
            role: .user,
            content: .parts([
                .text(text),
                .image(.url(imageURL))
            ])
        )
    }
    
    /// Creates a user message with base64 image data.
    public static func user(text: String, imageData: Data, mediaType: String = "image/jpeg") -> ChatMessage {
        ChatMessage(
            role: .user,
            content: .parts([
                .text(text),
                .image(.base64(imageData.base64EncodedString(), mediaType: mediaType))
            ])
        )
    }
}
