import Testing
import Foundation
@testable import NetworkingKit

@Suite("Request Building Tests")
struct RequestBuildingTests {
    
    // MARK: - HeaderBuilder Tests
    
    @Test func testHeaderBuilderCommonHeaders() {
        let headers = HeaderBuilder()
            .contentType(.json)
            .accept(.json)
            .userAgent(appName: "TestApp", version: "1.0")
            .build()
        
        #expect(headers["Content-Type"] == "application/json; charset=utf-8")
        #expect(headers["Accept"] == "application/json; charset=utf-8")
        #expect(headers["User-Agent"]?.contains("TestApp/1.0") == true)
    }
    
    @Test func testHeaderBuilderAuth() {
        let bearerHeaders = HeaderBuilder()
            .authorization(.bearer("token123"))
            .build()
        #expect(bearerHeaders["Authorization"] == "Bearer token123")
        
        let basicHeaders = HeaderBuilder()
            .authorization(.basic(username: "user", password: "pass"))
            .build()
        // Basic dXNlcjpwYXNz (user:pass in base64)
        #expect(basicHeaders["Authorization"] == "Basic dXNlcjpwYXNz")
    }
    
    @Test func testHeaderBuilderCaching() {
        let now = Date()
        let headers = HeaderBuilder()
            .cacheControl(.noCache)
            .ifModifiedSince(now)
            .build()
        
        #expect(headers["Cache-Control"] == "no-cache")
        #expect(headers["If-Modified-Since"] != nil)
    }
    
    // MARK: - ParameterEncoding Tests
    
    @Test func testURLEncodingQueryString() throws {
        let url = URL(string: "https://api.com/search")!
        let request = HTTPRequest(url: url)
        let parameters: [String: Any] = ["q": "swift", "page": 1]
        
        let encodedRequest = try URLEncoding.default.encode(request, with: parameters)
        
        let urlString = encodedRequest.url.absoluteString
        #expect(urlString.contains("q=swift"))
        #expect(urlString.contains("page=1"))
        #expect(urlString.contains("&"))
    }
    
    @Test func testURLEncodingHttpBody() throws {
        let url = URL(string: "https://api.com/login")!
        let request = HTTPRequest(url: url)
        let parameters = ["user": "john", "pass": "secret"]
        
        let encodedRequest = try URLEncoding.httpBody.encode(request, with: parameters)
        
        #expect(encodedRequest.headers["Content-Type"] == "application/x-www-form-urlencoded; charset=utf-8")
        #expect(encodedRequest.body != nil)
        let bodyString = String(data: encodedRequest.body!, encoding: .utf8)
        #expect(bodyString?.contains("user=john") == true)
        #expect(bodyString?.contains("pass=secret") == true)
    }
    
    @Test func testJSONEncoding() throws {
        let url = URL(string: "https://api.com/users")!
        let request = HTTPRequest(url: url)
        let parameters: [String: Any] = ["name": "Alice", "age": 30]
        
        let encodedRequest = try JSONEncoding.default.encode(request, with: parameters)
        
        #expect(encodedRequest.headers["Content-Type"] == "application/json; charset=utf-8")
        #expect(encodedRequest.body != nil)
        
        let decoded = try JSONSerialization.jsonObject(with: encodedRequest.body!) as? [String: Any]
        #expect(decoded?["name"] as? String == "Alice")
        #expect(decoded?["age"] as? Int == 30)
    }
    
    // MARK: - RequestBuilder Tests
    
    @Test func testRequestBuilderFullURL() throws {
        let builder = RequestBuilder()
        let endpoint = GetEndpoint(path: "https://absolute.com/api")
        
        let request = try builder.build(from: endpoint)
        #expect(request.url.absoluteString == "https://absolute.com/api")
    }
    
    @Test func testRequestBuilderWithBaseURLAndParams() throws {
        let baseURL = URL(string: "https://api.example.com/v1")!
        let builder = RequestBuilder(baseURL: baseURL, defaultHeaders: ["X-App": "Test"])
        
        struct TestEndpoint: Endpoint {
            var path: String { "/users/profile" }
            var method: HTTPMethod { .post }
            var queryParameters: [String: Any]? { ["debug": true] }
            var bodyParameters: [String: Any]? { ["id": 123] }
        }
        
        let request = try builder.build(from: TestEndpoint())
        
        #expect(request.url.absoluteString.hasPrefix("https://api.example.com/v1/users/profile"))
        #expect(request.url.absoluteString.contains("debug=true"))
        #expect(request.headers["X-App"] == "Test")
        #expect(request.method == .post)
        #expect(request.headers["Content-Type"] == "application/json; charset=utf-8")
    }
    
    @Test func testRequestBuilderConvenienceMethods() throws {
        let baseURL = URL(string: "https://api.example.com")!
        let builder = RequestBuilder(baseURL: baseURL)
        
        let getRequest = try builder.get("/users", queryParameters: ["sort": "desc"])
        #expect(getRequest.method == .get)
        #expect(getRequest.url.absoluteString.contains("sort=desc"))
        
        let postRequest = try builder.post("/users", bodyParameters: ["name": "Bob"])
        #expect(postRequest.method == .post)
        #expect(postRequest.headers["Content-Type"] == "application/json; charset=utf-8")
    }
}
