import XCTest
import Foundation
@testable import NetworkingKit

final class RequestBuildingTests: XCTestCase {
    
    // MARK: - HeaderBuilder Tests
    
    func testHeaderBuilderCommonHeaders() {
        let headers = HeaderBuilder()
            .contentType(.json)
            .accept(.json)
            .userAgent(appName: "TestApp", version: "1.0")
            .build()
        
        XCTAssertEqual(headers["Content-Type"], "application/json; charset=utf-8")
        XCTAssertEqual(headers["Accept"], "application/json; charset=utf-8")
        XCTAssertTrue(headers["User-Agent"]?.contains("TestApp/1.0") == true)
    }
    
    func testHeaderBuilderAuth() {
        let bearerHeaders = HeaderBuilder()
            .authorization(.bearer("token123"))
            .build()
        XCTAssertEqual(bearerHeaders["Authorization"], "Bearer token123")
        
        let basicHeaders = HeaderBuilder()
            .authorization(.basic(username: "user", password: "pass"))
            .build()
        // Basic dXNlcjpwYXNz (user:pass in base64)
        XCTAssertEqual(basicHeaders["Authorization"], "Basic dXNlcjpwYXNz")
    }
    
    func testHeaderBuilderCaching() {
        let now = Date()
        let headers = HeaderBuilder()
            .cacheControl(.noCache)
            .ifModifiedSince(now)
            .build()
        
        XCTAssertEqual(headers["Cache-Control"], "no-cache")
        XCTAssertNotNil(headers["If-Modified-Since"])
    }
    
    // MARK: - ParameterEncoding Tests
    
    func testURLEncodingQueryString() throws {
        let url = URL(string: "https://api.com/search")!
        let request = HTTPRequest(url: url)
        let parameters: [String: Any] = ["q": "swift", "page": 1]
        
        let encodedRequest = try URLEncoding.default.encode(request, with: parameters)
        
        let urlString = encodedRequest.url.absoluteString
        XCTAssertTrue(urlString.contains("q=swift"))
        XCTAssertTrue(urlString.contains("page=1"))
        XCTAssertTrue(urlString.contains("&"))
    }
    
    func testURLEncodingHttpBody() throws {
        let url = URL(string: "https://api.com/login")!
        let request = HTTPRequest(url: url)
        let parameters = ["user": "john", "pass": "secret"]
        
        let encodedRequest = try URLEncoding.httpBody.encode(request, with: parameters)
        
        XCTAssertEqual(encodedRequest.headers["Content-Type"], "application/x-www-form-urlencoded; charset=utf-8")
        XCTAssertNotNil(encodedRequest.body)
        let bodyString = String(data: encodedRequest.body!, encoding: .utf8)
        XCTAssertTrue(bodyString?.contains("user=john") == true)
        XCTAssertTrue(bodyString?.contains("pass=secret") == true)
    }
    
    func testJSONEncoding() throws {
        let url = URL(string: "https://api.com/users")!
        let request = HTTPRequest(url: url)
        let parameters: [String: Any] = ["name": "Alice", "age": 30]
        
        let encodedRequest = try JSONEncoding.default.encode(request, with: parameters)
        
        XCTAssertEqual(encodedRequest.headers["Content-Type"], "application/json; charset=utf-8")
        XCTAssertNotNil(encodedRequest.body)
        
        let decoded = try JSONSerialization.jsonObject(with: encodedRequest.body!) as? [String: Any]
        XCTAssertEqual(decoded?["name"] as? String, "Alice")
        XCTAssertEqual(decoded?["age"] as? Int, 30)
    }
    
    // MARK: - RequestBuilder Tests
    
    func testRequestBuilderFullURL() throws {
        let builder = RequestBuilder()
        let endpoint = GetEndpoint(path: "https://absolute.com/api")
        
        let request = try builder.build(from: endpoint)
        XCTAssertEqual(request.url.absoluteString, "https://absolute.com/api")
    }
    
    func testRequestBuilderWithBaseURLAndParams() throws {
        let baseURL = URL(string: "https://api.example.com/v1")!
        let builder = RequestBuilder(baseURL: baseURL, defaultHeaders: ["X-App": "Test"])
        
        struct TestEndpoint: Endpoint {
            var path: String { "/users/profile" }
            var method: HTTPMethod { .post }
            var queryParameters: [String: Any]? { ["debug": true] }
            var bodyParameters: [String: Any]? { ["id": 123] }
        }
        
        let request = try builder.build(from: TestEndpoint())
        
        XCTAssertTrue(request.url.absoluteString.hasPrefix("https://api.example.com/v1/users/profile"))
        XCTAssertTrue(request.url.absoluteString.contains("debug=true"))
        XCTAssertEqual(request.headers["X-App"], "Test")
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.headers["Content-Type"], "application/json; charset=utf-8")
    }
    
    func testRequestBuilderConvenienceMethods() throws {
        let baseURL = URL(string: "https://api.example.com")!
        let builder = RequestBuilder(baseURL: baseURL)
        
        let getRequest = try builder.get("/users", queryParameters: ["sort": "desc"])
        XCTAssertEqual(getRequest.method, .get)
        XCTAssertTrue(getRequest.url.absoluteString.contains("sort=desc"))
        
        let postRequest = try builder.post("/users", bodyParameters: ["name": "Bob"])
        XCTAssertEqual(postRequest.method, .post)
        XCTAssertEqual(postRequest.headers["Content-Type"], "application/json; charset=utf-8")
    }
}
