import Testing
import Foundation
@testable import NetworkingKit

@Suite("Core Layer Tests")
struct CoreTests {
    
    // MARK: - HTTPMethod Tests
    
    @Test func testHTTPMethodRawValues() {
        #expect(HTTPMethod.get.rawValue == "GET")
        #expect(HTTPMethod.post.rawValue == "POST")
        #expect(HTTPMethod.put.rawValue == "PUT")
        #expect(HTTPMethod.patch.rawValue == "PATCH")
        #expect(HTTPMethod.delete.rawValue == "DELETE")
        #expect(HTTPMethod.head.rawValue == "HEAD")
        #expect(HTTPMethod.options.rawValue == "OPTIONS")
    }
    
    @Test func testHTTPMethodDescription() {
        #expect(HTTPMethod.get.description == "GET")
        #expect(HTTPMethod.post.description == "POST")
    }
    
    // MARK: - HTTPRequest Tests
    
    @Test func testHTTPRequestInitialization() {
        let url = URL(string: "https://api.example.com")!
        let request = HTTPRequest(url: url)
        
        #expect(request.url == url)
        #expect(request.method == .get)
        #expect(request.headers.isEmpty)
        #expect(request.body == nil)
        #expect(request.timeoutInterval == 60.0)
    }
    
    @Test func testHTTPRequestToURLRequest() {
        let url = URL(string: "https://api.example.com")!
        let bodyData = "test".data(using: .utf8)
        let request = HTTPRequest(
            url: url,
            method: .post,
            headers: ["X-Test": "Value"],
            body: bodyData,
            timeoutInterval: 30.0
        )
        
        let urlRequest = request.toURLRequest()
        
        #expect(urlRequest.url == url)
        #expect(urlRequest.httpMethod == "POST")
        #expect(urlRequest.allHTTPHeaderFields?["X-Test"] == "Value")
        #expect(urlRequest.httpBody == bodyData)
        #expect(urlRequest.timeoutInterval == 30.0)
    }
    
    @Test func testHTTPRequestBuilder() {
        let url = URL(string: "https://api.example.com")!
        let request = HTTPRequest(url: url)
            .method(.put)
            .headers(["H": "V"])
            .timeout(10.0)
        
        #expect(request.method == .put)
        #expect(request.headers["H"] == "V")
        #expect(request.timeoutInterval == 10.0)
    }
    
    // MARK: - HTTPResponse Tests
    
    @Test func testHTTPResponseInitialization() throws {
        let data = "{}".data(using: .utf8)!
        let url = URL(string: "https://api.example.com")!
        let urlResponse = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        
        let response = try HTTPResponse(data: data, urlResponse: urlResponse)
        
        #expect(response.statusCode == 200)
        #expect(response.isSuccess == true)
        #expect(response.headers["Content-Type"] == "application/json")
        #expect(response.isJSON == true)
    }
    
    @Test func testHTTPResponseErrorCodes() throws {
        let data = Data()
        let url = URL(string: "https://api.example.com")!
        
        let clientErrorResponse = try HTTPResponse(
            data: data,
            urlResponse: HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: [:])!
        )
        #expect(clientErrorResponse.isClientError == true)
        #expect(clientErrorResponse.isSuccess == false)
        
        let serverErrorResponse = try HTTPResponse(
            data: data,
            urlResponse: HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: [:])!
        )
        #expect(serverErrorResponse.isServerError == true)
    }
    
    // MARK: - NetworkConfiguration Tests
    
    @Test func testNetworkConfigurationDefaults() {
        let config = NetworkConfiguration.default
        #expect(config.baseURL == nil)
        #expect(config.timeoutInterval == 60.0)
        #expect(config.enableLogging == false)
    }
    
    @Test func testNetworkConfigurationPresets() {
        let dev = NetworkConfiguration.development
        #expect(dev.enableLogging == true)
        #expect(dev.logLevel == .verbose)
        
        let prod = NetworkConfiguration.production
        #expect(prod.logLevel == .error)
    }
    
    @Test func testNetworkConfigurationBuilder() {
        let url = URL(string: "https://stage.api.com")!
        let config = NetworkConfiguration.default
            .baseURL(url)
            .logLevel(.info)
        
        #expect(config.baseURL == url)
        #expect(config.logLevel == .info)
        #expect(config.enableLogging == true)
    }
    
    // MARK: - NetworkError Tests
    
    @Test func testNetworkErrorDescriptions() {
        let error = NetworkError.invalidURL("bad-url")
        #expect(error.errorDescription?.contains("bad-url") == true)
        
        let httpError = NetworkError.httpError(statusCode: 401, data: nil)
        #expect(httpError.errorDescription?.contains("401") == true)
        #expect(httpError.recoverySuggestion?.contains("log in again") == true)
    }
    
    @Test func testNetworkErrorFromURLError() {
        let urlError = URLError(.timedOut)
        let networkError = NetworkError.from(urlError: urlError)
        
        if case .timeout = networkError {
            // Success
        } else {
            Issue.record("Expected timeout error")
        }
    }
}
