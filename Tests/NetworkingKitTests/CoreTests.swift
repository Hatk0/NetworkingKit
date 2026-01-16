import XCTest
import Foundation
@testable import NetworkingKit

final class CoreTests: XCTestCase {
    
    // MARK: - HTTPMethod Tests
    
    func testHTTPMethodRawValues() {
        XCTAssertEqual(HTTPMethod.get.rawValue, "GET")
        XCTAssertEqual(HTTPMethod.post.rawValue, "POST")
        XCTAssertEqual(HTTPMethod.put.rawValue, "PUT")
        XCTAssertEqual(HTTPMethod.patch.rawValue, "PATCH")
        XCTAssertEqual(HTTPMethod.delete.rawValue, "DELETE")
        XCTAssertEqual(HTTPMethod.head.rawValue, "HEAD")
        XCTAssertEqual(HTTPMethod.options.rawValue, "OPTIONS")
    }
    
    func testHTTPMethodDescription() {
        XCTAssertEqual(HTTPMethod.get.description, "GET")
        XCTAssertEqual(HTTPMethod.post.description, "POST")
    }
    
    // MARK: - HTTPRequest Tests
    
    func testHTTPRequestInitialization() {
        let url = URL(string: "https://api.example.com")!
        let request = HTTPRequest(url: url)
        
        XCTAssertEqual(request.url, url)
        XCTAssertEqual(request.method, .get)
        XCTAssertTrue(request.headers.isEmpty)
        XCTAssertNil(request.body)
        XCTAssertEqual(request.timeoutInterval, 60.0)
    }
    
    func testHTTPRequestToURLRequest() {
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
        
        XCTAssertEqual(urlRequest.url, url)
        XCTAssertEqual(urlRequest.httpMethod, "POST")
        XCTAssertEqual(urlRequest.allHTTPHeaderFields?["X-Test"], "Value")
        XCTAssertEqual(urlRequest.httpBody, bodyData)
        XCTAssertEqual(urlRequest.timeoutInterval, 30.0)
    }
    
    func testHTTPRequestBuilder() {
        let url = URL(string: "https://api.example.com")!
        let request = HTTPRequest(url: url)
            .method(.put)
            .headers(["H": "V"])
            .timeout(10.0)
        
        XCTAssertEqual(request.method, .put)
        XCTAssertEqual(request.headers["H"], "V")
        XCTAssertEqual(request.timeoutInterval, 10.0)
    }
    
    // MARK: - HTTPResponse Tests
    
    func testHTTPResponseInitialization() throws {
        let data = "{}".data(using: .utf8)!
        let url = URL(string: "https://api.example.com")!
        let urlResponse = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        
        let response = try HTTPResponse(data: data, urlResponse: urlResponse)
        
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertTrue(response.isSuccess)
        XCTAssertEqual(response.headers["Content-Type"], "application/json")
        XCTAssertTrue(response.isJSON)
    }
    
    func testHTTPResponseErrorCodes() throws {
        let data = Data()
        let url = URL(string: "https://api.example.com")!
        
        let clientErrorResponse = try HTTPResponse(
            data: data,
            urlResponse: HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: [:])!
        )
        XCTAssertTrue(clientErrorResponse.isClientError)
        XCTAssertFalse(clientErrorResponse.isSuccess)
        
        let serverErrorResponse = try HTTPResponse(
            data: data,
            urlResponse: HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: [:])!
        )
        XCTAssertTrue(serverErrorResponse.isServerError)
    }
    
    // MARK: - NetworkConfiguration Tests
    
    func testNetworkConfigurationDefaults() {
        let config = NetworkConfiguration.default
        XCTAssertNil(config.baseURL)
        XCTAssertEqual(config.timeoutInterval, 60.0)
        XCTAssertFalse(config.enableLogging)
    }
    
    func testNetworkConfigurationPresets() {
        let dev = NetworkConfiguration.development
        XCTAssertTrue(dev.enableLogging)
        XCTAssertEqual(dev.logLevel, .verbose)
        
        let prod = NetworkConfiguration.production
        XCTAssertEqual(prod.logLevel, .error)
    }
    
    func testNetworkConfigurationBuilder() {
        let url = URL(string: "https://stage.api.com")!
        let config = NetworkConfiguration.default
            .baseURL(url)
            .logLevel(.info)
        
        XCTAssertEqual(config.baseURL, url)
        XCTAssertEqual(config.logLevel, .info)
        XCTAssertTrue(config.enableLogging)
    }
    
    // MARK: - NetworkError Tests
    
    func testNetworkErrorDescriptions() {
        let error = NetworkError.invalidURL("bad-url")
        XCTAssertTrue(error.errorDescription?.contains("bad-url") == true)
        
        let httpError = NetworkError.httpError(statusCode: 401, data: nil)
        XCTAssertTrue(httpError.errorDescription?.contains("401") == true)
        XCTAssertTrue(httpError.recoverySuggestion?.contains("log in again") == true)
    }
    
    func testNetworkErrorFromURLError() {
        let urlError = URLError(.timedOut)
        let networkError = NetworkError.from(urlError: urlError)
        
        if case .timeout = networkError {
            // Success
        } else {
            XCTFail("Expected timeout error")
        }
    }
}
