import XCTest
import Foundation
@testable import NetworkingKit

final class MiddlewareTests: XCTestCase {
    
    // MARK: - Mocks
    
    struct MockClient: HTTPClient {
        var response: HTTPResponse?
        var error: Error?
        var requestHandler: (@Sendable (HTTPRequest) -> Void)?
        
        func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
            requestHandler?(request)
            if let error = error { throw error }
            return response!
        }
    }
    
    struct SimpleMiddleware: Middleware {
        let id: String
        let onIntercept: @Sendable (HTTPRequest) -> Void
        
        func intercept(_ request: HTTPRequest, next: @Sendable (HTTPRequest) async throws -> HTTPResponse) async throws -> HTTPResponse {
            onIntercept(request)
            return try await next(request)
        }
    }
    
    actor OrderTracker {
        var order: [String] = []
        func add(_ id: String) { order.append(id) }
    }
    
    // MARK: - MiddlewareChain Tests
    
    func testMiddlewareChainExecutionOrder() async throws {
        let response = try! HTTPResponse(data: Data(), urlResponse: HTTPURLResponse(url: URL(string: "https://a.com")!, statusCode: 200, httpVersion: nil, headerFields: [:])!)
        let mockClient = MockClient(response: response)
        
        let tracker = OrderTracker()
        let m1 = SimpleMiddleware(id: "1") { _ in Task { await tracker.add("1") } }
        let m2 = SimpleMiddleware(id: "2") { _ in Task { await tracker.add("2") } }
        
        let chain = MiddlewareChain(client: mockClient)
        await chain.add(m1)
        await chain.add(m2)
        
        _ = try await chain.execute(HTTPRequest(url: URL(string: "https://test.com")!))
        
        // Wait a small amount for tasks to complete
        try await Task.sleep(nanoseconds: 100_000_000)
        let finalOrder = await tracker.order
        XCTAssertEqual(finalOrder, ["1", "2"])
    }
    
    // MARK: - AuthenticationMiddleware Tests
    
    func testAuthenticationMiddlewareAddsHeader() async throws {
        let response = try! HTTPResponse(data: Data(), urlResponse: HTTPURLResponse(url: URL(string: "https://a.com")!, statusCode: 200, httpVersion: nil, headerFields: [:])!)
        
        actor CapturedRequest {
            var request: HTTPRequest?
            func set(_ r: HTTPRequest) { self.request = r }
        }
        
        let captured = CapturedRequest()
        let mockClient = MockClient(response: response) { request in
            Task { await captured.set(request) }
        }
        
        let authMiddleware = AuthenticationMiddleware.bearer(token: "secret123")
        let chain = MiddlewareChain(client: mockClient)
        await chain.add(authMiddleware)
        
        _ = try await chain.execute(HTTPRequest(url: URL(string: "https://test.com")!))
        
        try await Task.sleep(nanoseconds: 100_000_000)
        let request = await captured.request
        XCTAssertEqual(request?.headers["Authorization"], "Bearer secret123")
    }
    
    // MARK: - RetryMiddleware Tests
    
    func testRetryMiddlewareRetriesOnFailure() async throws {
        // Setup client to fail with 500 then succeed
        let response500 = try! HTTPResponse(data: Data(), urlResponse: HTTPURLResponse(url: URL(string: "https://a.com")!, statusCode: 500, httpVersion: nil, headerFields: [:])!)
        let response200 = try! HTTPResponse(data: Data(), urlResponse: HTTPURLResponse(url: URL(string: "https://a.com")!, statusCode: 200, httpVersion: nil, headerFields: [:])!)
        
        let client = ControlledMockClient(responses: [response500, response200])
        
        let retryConfig = RetryMiddleware.RetryConfiguration(
            maxRetries: 1,
            baseDelay: 0.1,
            retryableStatusCodes: [500]
        )
        let retryMiddleware = RetryMiddleware(configuration: retryConfig)
        
        let chain = MiddlewareChain(client: client)
        await chain.add(retryMiddleware)
        
        let finalResponse = try await chain.execute(HTTPRequest(url: URL(string: "https://test.com")!))
        
        XCTAssertEqual(finalResponse.statusCode, 200)
        let count = await client.callCount
        XCTAssertEqual(count, 2)
    }
}

// MARK: - Helper Mock

actor ControlledMockClient: HTTPClient {
    private var responses: [HTTPResponse]
    var callCount = 0
    
    init(responses: [HTTPResponse]) {
        self.responses = responses
    }
    
    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        callCount += 1
        return responses.removeFirst()
    }
}
