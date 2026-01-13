# NetworkingKit

A professional, modular iOS networking framework built with Swift 6.2. NetworkingKit provides a clean, protocol-oriented architecture with 4 distinct layers for maximum flexibility and reusability.

## Features

✅ **4-Layer Architecture** - Clean separation of concerns  
✅ **Protocol-Oriented** - Testable and flexible design  
✅ **Async/Await** - Modern Swift concurrency support  
✅ **Type-Safe** - Compile-time safety with Codable  
✅ **Middleware System** - Composable request/response interceptors  
✅ **Zero Dependencies** - Pure Swift implementation  
✅ **Certificate Pinning** - Enhanced security  
✅ **Comprehensive Logging** - Request/response debugging  
✅ **Auto-Retry** - Exponential backoff with jitter  
✅ **Response Caching** - ETag and conditional requests  
✅ **AI Streaming** - Token-by-token responses (OpenAI, Claude, Gemini)

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/NetworkingKit.git", from: "1.0.0")
]
```

## Quick Start

### Basic Usage

```swift
import NetworkingKit

// 1. Create HTTP client
let httpClient = URLSessionHTTPClient(
    configuration: NetworkConfiguration(
        baseURL: URL(string: "https://api.example.com")!
    )
)

// 2. Create API client
let apiClient = APIClient(
    baseURL: URL(string: "https://api.example.com")!,
    httpClient: httpClient
)

// 3. Define your model
struct User: Codable {
    let id: Int
    let name: String
    let email: String
}

// 4. Make requests
let users: [User] = try await apiClient.get("/users")
```

### With Middleware

```swift
// Add authentication, logging, and retry logic
let client = MiddlewareChain(client: URLSessionHTTPClient())
    .add(AuthenticationMiddleware.bearer(token: "your-token"))
    .add(LoggingMiddleware.verbose)
    .add(RetryMiddleware.default)
    .add(CachingMiddleware.conditional)

let apiClient = APIClient(
    baseURL: URL(string: "https://api.example.com")!,
    httpClient: client
)
```

### Custom Endpoints

```swift
struct CreateUserEndpoint: Endpoint {
    let name: String
    let email: String
    
    var path: String { "/users" }
    var method: HTTPMethod { .post }
    var bodyParameters: [String: Any]? {
        ["name": name, "email": email]
    }
}

// Use the endpoint
let newUser: User = try await apiClient.request(CreateUserEndpoint(
    name: "John Doe",
    email: "john@example.com"
))
```

## Architecture

NetworkingKit is built with 4 distinct layers:

### Layer 1: Core HTTP

Low-level HTTP communication.

- `HTTPClient` - Protocol for HTTP execution
- `URLSessionHTTPClient` - URLSession-based implementation
- `HTTPRequest` / `HTTPResponse` - Value types for requests/responses
- `NetworkError` - Comprehensive error handling
- `NetworkConfiguration` - Client configuration

### Layer 2: Request Building

Declarative request construction.

- `Endpoint` - Protocol for API endpoints
- `RequestBuilder` - Fluent request builder
- `ParameterEncoding` - URL, JSON, Multipart encoding
- `HeaderBuilder` - Type-safe header construction

### Layer 3: Middleware

Composable request/response interceptors.

- `Middleware` - Protocol for interceptors
- `MiddlewareChain` - Sequential middleware execution
- `AuthenticationMiddleware` - Bearer, API Key, Basic auth
- `LoggingMiddleware` - Request/response logging
- `RetryMiddleware` - Exponential backoff retry
- `CachingMiddleware` - Response caching with ETag

### Layer 4: High-Level API

Developer-friendly abstractions.

- `APIClient` - Type-safe API client
- `RequestModifier` - Per-request customization
- `MockHTTPClient` - Testing utilities

## Examples

### GET Request

```swift
struct GetUsersEndpoint: Endpoint {
    var path: String { "/users" }
    var method: HTTPMethod { .get }
}

let users: [User] = try await apiClient.request(GetUsersEndpoint())
```

### POST Request with Body

```swift
struct CreateUserRequest: Encodable {
    let name: String
    let email: String
}

let request = CreateUserRequest(name: "Jane", email: "jane@example.com")
let user: User = try await apiClient.post("/users", body: request)
```

### File Upload

```swift
let imageData = image.jpegData(compressionQuality: 0.8)!
let response: UploadResponse = try await apiClient.upload(
    "/upload",
    fileData: imageData,
    fileName: "photo.jpg",
    fieldName: "image",
    mimeType: "image/jpeg"
)
```

### With Request Modifiers

```swift
let user: User = try await apiClient.request(
    GetUserEndpoint(userId: 123),
    modifiers: [
        TimeoutModifier(timeout: 10),
        HeadersModifier(headers: ["X-Custom": "value"])
    ]
)
```

### AI Streaming (v1.1.0+)

Stream token-by-token responses from AI APIs:

```swift
import NetworkingKit

// Create AI client with any provider
let client = AIStreamClient(
    provider: OpenAIProvider(apiKey: "sk-..."),
    streamingClient: URLSessionStreamingClient()
)

// Stream chat completion
let messages = [
    ChatMessage.system("You are a helpful assistant."),
    ChatMessage.user("Explain Swift concurrency")
]

for try await delta in client.stream(messages: messages, options: .gpt52()) {
    print(delta.content ?? "", terminator: "")
}

// Or use Claude
let claude = AIStreamClient(provider: ClaudeProvider(apiKey: "sk-ant-..."))
for try await delta in claude.stream(messages: messages, options: .claude45Sonnet()) {
    print(delta.content ?? "", terminator: "")
}

// Or Gemini
let gemini = AIStreamClient(provider: GeminiProvider(apiKey: "..."))
for try await delta in gemini.stream(messages: messages, options: .gemini3Flash()) {
    print(delta.content ?? "", terminator: "")
}
```


### Testing with MockHTTPClient

```swift
let mock = MockHTTPClient()

// Stub a response
try mock.stub(
    url: "https://api.example.com/users",
    object: [User(id: 1, name: "Test", email: "test@example.com")]
)

let client = APIClient(
    baseURL: URL(string: "https://api.example.com")!,
    httpClient: mock
)

let users: [User] = try await client.get("/users")

// Verify requests
XCTAssertTrue(mock.didRequest(url: "https://api.example.com/users"))
```

## Advanced Configuration

### Custom Logging

```swift
let config = NetworkConfiguration(
    baseURL: URL(string: "https://api.example.com")!,
    enableLogging: true,
    logLevel: .verbose
)

let client = URLSessionHTTPClient(configuration: config)
```

### Certificate Pinning

```swift
let certificateData = try Data(contentsOf: certificateURL)

let config = NetworkConfiguration(
    baseURL: URL(string: "https://api.example.com")!
)
.certificatePinning([certificateData])

let client = URLSessionHTTPClient(configuration: config)
```

### Custom Retry Configuration

```swift
let retryConfig = RetryMiddleware.RetryConfiguration(
    maxRetries: 5,
    baseDelay: 1.0,
    maxDelay: 30.0,
    backoffMultiplier: 2.0,
    retryableStatusCodes: [408, 429, 500, 502, 503, 504]
)

let retry = RetryMiddleware(configuration: retryConfig)
```

### Custom Authentication

```swift
struct CustomAuthProvider: AuthenticationProvider {
    func authenticationHeader() async throws -> (key: String, value: String)? {
        let token = await getTokenFromSecureStorage()
        return ("Authorization", "Custom \(token)")
    }
    
    func reauthenticate() async throws -> Bool {
        // Refresh token logic
        return true
    }
}

let auth = AuthenticationMiddleware(provider: CustomAuthProvider())
```

## Best Practices

1. **Use Endpoints** - Define reusable endpoint types for your API
2. **Add Middleware** - Leverage middleware for cross-cutting concerns
3. **Type Safety** - Use Codable for compile-time safety
4. **Error Handling** - Handle `NetworkError` cases appropriately
5. **Testing** - Use `MockHTTPClient` for unit tests
6. **Configuration** - Use different configs for dev/staging/production

## Requirements

- iOS 15.0+ / macOS 12.0+ / tvOS 15.0+ / watchOS 8.0+
- Swift 6.2+
- Xcode 16.0+

## License

MIT License - See LICENSE file for details

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## Future Extensions

The architecture supports future specialized packages:

- **NetworkingKit-REST** - RESTful API patterns, HATEOAS, pagination
- **NetworkingKit-GraphQL** - GraphQL queries, mutations, subscriptions
- **NetworkingKit-WebSocket** - WebSocket connections, auto-reconnect
- **NetworkingKit-AI** - Streaming responses for AI APIs (OpenAI, etc.)
