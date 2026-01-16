import Foundation

// MARK: - AI Image Provider Protocol

/// Protocol that defines an AI image generation provider.
///
/// Implement this protocol to add support for AI image generation APIs
/// (e.g., DALL-E, Midjourney, Stability AI).
public protocol AIImageProvider: AIProvider {
    /// Generates images based on the provided options.
    ///
    /// - Parameter options: The image generation options (prompt, size, etc.)
    /// - Returns: A list of generated images
    func generateImage(options: ImageGenerationOptions) async throws -> [GeneratedImage]
}

// MARK: - Image Generation Options

/// Options for generating images.
public struct ImageGenerationOptions: Sendable {
    /// The text prompt describing the image.
    public var prompt: String
    
    /// The model to use for generation (e.g., "dall-e-3").
    public var model: String
    
    /// The number of images to generate.
    public var n: Int
    
    /// The size of the generated images (e.g., "1024x1024").
    public var size: String
    
    /// The quality of the image (e.g., "standard", "hd").
    public var quality: String?
    
    /// The style of the image (e.g., "vivid", "natural").
    public var style: String?
    
    /// The format of the returned image (url or base64).
    public var responseFormat: ImageResponseFormat
    
    /// Optional user identifier for monitoring.
    public var user: String?
    
    public init(
        prompt: String,
        model: String = "dall-e-3",
        n: Int = 1,
        size: String = "1024x1024",
        quality: String? = nil,
        style: String? = nil,
        responseFormat: ImageResponseFormat = .url,
        user: String? = nil
    ) {
        self.prompt = prompt
        self.model = model
        self.n = n
        self.size = size
        self.quality = quality
        self.style = style
        self.responseFormat = responseFormat
        self.user = user
    }
}

// MARK: - Generated Image

/// Represents a generated image.
public struct GeneratedImage: Sendable, Codable {
    /// The URL of the generated image (if `resultFormat` was URL).
    public let url: URL?
    
    /// The base64-encoded image data (if `resultFormat` was b64_json).
    public let base64Data: String?
    
    /// The revised prompt (some models rewrite the prompt).
    public let revisedPrompt: String?
    
    public init(
        url: URL? = nil,
        base64Data: String? = nil,
        revisedPrompt: String? = nil
    ) {
        self.url = url
        self.base64Data = base64Data
        self.revisedPrompt = revisedPrompt
    }
}

// MARK: - Image Response Format

/// The format in which the generated images are returned.
public enum ImageResponseFormat: String, Sendable, Codable {
    /// Return a URL to the image.
    case url = "url"
    
    /// Return the image as a base64-encoded JSON string.
    case b64Json = "b64_json"
}
