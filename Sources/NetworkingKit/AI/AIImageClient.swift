import Foundation

// MARK: - AI Image Client

/// A client for generating AI images.
///
/// This is the main entry point for interacting with AI image generation APIs.
/// It works with any provider that conforms to `AIImageProvider`.
///
/// Example:
/// ```swift
/// let client = AIImageClient(provider: OpenAIProvider(apiKey: "..."))
///
/// let images = try await client.generate(
///     prompt: "A futuristic city on Mars",
///     model: "dall-e-3"
/// )
/// ```
public final class AIImageClient<Provider: AIImageProvider>: Sendable {
    private let provider: Provider
    
    /// Creates an AI image client.
    ///
    /// - Parameter provider: The AI image provider to use
    public init(provider: Provider) {
        self.provider = provider
    }
    
    /// Generates images based on the provided options.
    ///
    /// - Parameter options: The image generation options
    /// - Returns: A list of generated images
    public func generate(options: ImageGenerationOptions) async throws -> [GeneratedImage] {
        try await provider.generateImage(options: options)
    }
    
    /// Convenience method to generate a single image.
    ///
    /// - Parameters:
    ///   - prompt: The text description
    ///   - model: The model to use (default: provider specific default or "dall-e-3")
    ///   - size: The image size (default: "1024x1024")
    /// - Returns: The generated image
    public func generate(
        prompt: String,
        model: String = "dall-e-3",
        size: String = "1024x1024"
    ) async throws -> GeneratedImage {
        let options = ImageGenerationOptions(
            prompt: prompt,
            model: model,
            size: size
        )
        
        let images = try await generate(options: options)
        
        guard let firstImage = images.first else {
            throw AIError.apiError(code: "no_image", message: "No image was generated")
        }
        
        return firstImage
    }
}
