import Testing
import Foundation
@testable import NetworkingKit

@Suite("API Layer Tests")
struct APIClientTests {
    
    struct User: Codable, Equatable {
        let id: Int
        let name: String
    }
    
    actor MockClient: HTTPClient {
        var response: HTTPResponse?
        var error: Error?
        var capturedRequest: HTTPRequest?
        
        func setResponse(_ response: HTTPResponse) { self.response = response }
        func setError(_ error: Error) { self.error = error }
        
        func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
            capturedRequest = request
            if let error = error { throw error }
            return response!
        }
    }
    
    @Test func testAPIClientRequestDecoding() async throws {
        let mock = MockClient()
        let userData = #"{"id": 1, "name": "John"}"#.data(using: .utf8)!
        let response = try HTTPResponse(
            data: userData,
            urlResponse: HTTPURLResponse(url: URL(string: "https://a.com")!, statusCode: 200, httpVersion: nil, headerFields: [:])!
        )
        await mock.setResponse(response)
        
        let client = APIClient(baseURL: URL(string: "https://api.example.com"), httpClient: mock)
        
        let user: User = try await client.get("/users/1")
        
        #expect(user.id == 1)
        #expect(user.name == "John")
        let captured = await mock.capturedRequest
        #expect(captured?.url.absoluteString.contains("/users/1") == true)
    }
    
    @Test func testAPIClientPostWithBody() async throws {
        let mock = MockClient()
        let response = try HTTPResponse(
            data: Data(),
            urlResponse: HTTPURLResponse(url: URL(string: "https://a.com")!, statusCode: 201, httpVersion: nil, headerFields: [:])!
        )
        await mock.setResponse(response)
        
        let client = APIClient(baseURL: URL(string: "https://api.example.com"), httpClient: mock)
        let newUser = User(id: 2, name: "Jane")
        
        try await client.post("/users", body: newUser)
        
        let captured = await mock.capturedRequest
        #expect(captured?.method == .post)
        #expect(captured?.body != nil)
        
        let decoded = try JSONDecoder().decode(User.self, from: captured!.body!)
        #expect(decoded == newUser)
    }
    
    @Test func testRequestModifiers() async throws {
        let mock = MockClient()
        let response = try HTTPResponse(
            data: Data(),
            urlResponse: HTTPURLResponse(url: URL(string: "https://a.com")!, statusCode: 200, httpVersion: nil, headerFields: [:])!
        )
        await mock.setResponse(response)
        
        let client = APIClient(baseURL: URL(string: "https://api.example.com"), httpClient: mock)
        
        _ = try await client.requestRaw(
            GetEndpoint(path: "/test"),
            modifiers: [
                TimeoutModifier(timeout: 5.0),
                HeadersModifier(headers: ["X-Custom": "Value"])
            ]
        )
        
        let captured = await mock.capturedRequest
        #expect(captured?.timeoutInterval == 5.0)
        #expect(captured?.headers["X-Custom"] == "Value")
    }
    
    @Test func testAuthorizationModifier() async throws {
        let mock = MockClient()
        let response = try HTTPResponse(
            data: Data(),
            urlResponse: HTTPURLResponse(url: URL(string: "https://a.com")!, statusCode: 200, httpVersion: nil, headerFields: [:])!
        )
        await mock.setResponse(response)
        
        let client = APIClient(baseURL: nil, httpClient: mock)
        
        _ = try await client.requestRaw(
            GetEndpoint(path: "https://api.com"),
            modifiers: [AuthorizationModifier.bearer("token")]
        )
        
        let captured = await mock.capturedRequest
        #expect(captured?.headers["Authorization"] == "Bearer token")
    }
}
