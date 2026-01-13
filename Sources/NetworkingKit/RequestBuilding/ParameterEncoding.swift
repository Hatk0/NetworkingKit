import Foundation

/// Protocol for encoding request parameters.
///
/// `ParameterEncoding` defines how parameters should be encoded
/// into an HTTP request (URL query string, JSON body, etc.).
public protocol ParameterEncoding {
    /// Encodes parameters into the HTTP request.
    ///
    /// - Parameters:
    ///   - request: The request to encode parameters into
    ///   - parameters: The parameters to encode
    /// - Returns: A new request with encoded parameters
    /// - Throws: `NetworkError.encodingFailed` if encoding fails
    func encode(_ request: HTTPRequest, with parameters: [String: Any]?) throws -> HTTPRequest
}

// MARK: - URL Encoding

/// Encodes parameters as URL query string.
public struct URLEncoding: ParameterEncoding, Sendable {
    /// The destination for the parameters.
    public enum Destination: Sendable {
        /// Encode parameters in URL query string.
        case queryString
        
        /// Encode parameters in HTTP body (x-www-form-urlencoded).
        case httpBody
    }
    
    /// The destination for encoded parameters.
    public let destination: Destination
    
    /// Default URL encoding (query string).
    public static let `default` = URLEncoding()
    
    /// URL encoding with parameters in HTTP body.
    public static let httpBody = URLEncoding(destination: .httpBody)
    
    /// Initializes URL encoding with the specified destination.
    public init(destination: Destination = .queryString) {
        self.destination = destination
    }
    
    public func encode(_ request: HTTPRequest, with parameters: [String: Any]?) throws -> HTTPRequest {
        guard let parameters = parameters, !parameters.isEmpty else {
            return request
        }
        
        let query = parameters.map { key, value in
            let escapedKey = escape(key)
            let escapedValue = escape("\(value)")
            return "\(escapedKey)=\(escapedValue)"
        }.joined(separator: "&")
        
        switch destination {
        case .queryString:
            guard var components = URLComponents(url: request.url, resolvingAgainstBaseURL: false) else {
                throw NetworkError.invalidURL(request.url.absoluteString)
            }
            
            let existingQuery = components.percentEncodedQuery.map { $0 + "&" } ?? ""
            components.percentEncodedQuery = existingQuery + query
            
            guard let newURL = components.url else {
                throw NetworkError.invalidURL(request.url.absoluteString)
            }
            
            return HTTPRequest(
                url: newURL,
                method: request.method,
                headers: request.headers,
                body: request.body,
                timeoutInterval: request.timeoutInterval,
                cachePolicy: request.cachePolicy
            )
            
        case .httpBody:
            guard let data = query.data(using: .utf8) else {
                throw NetworkError.encodingFailed(EncodingError.invalidData)
            }
            
            var headers = request.headers
            if headers["Content-Type"] == nil {
                headers["Content-Type"] = "application/x-www-form-urlencoded; charset=utf-8"
            }
            
            return request
                .headers(headers)
                .body(data)
        }
    }
    
    private func escape(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? string
    }
}

// MARK: - JSON Encoding

/// Encodes parameters as JSON in the HTTP body.
public struct JSONEncoding: ParameterEncoding, Sendable {
    /// JSON writing options.
    public let options: JSONSerialization.WritingOptions
    
    /// Default JSON encoding.
    public static let `default` = JSONEncoding()
    
    /// Pretty-printed JSON encoding.
    public static let prettyPrinted = JSONEncoding(options: .prettyPrinted)
    
    /// Initializes JSON encoding with the specified options.
    public init(options: JSONSerialization.WritingOptions = []) {
        self.options = options
    }
    
    public func encode(_ request: HTTPRequest, with parameters: [String: Any]?) throws -> HTTPRequest {
        guard let parameters = parameters, !parameters.isEmpty else {
            return request
        }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: parameters, options: options)
            
            var headers = request.headers
            if headers["Content-Type"] == nil {
                headers["Content-Type"] = "application/json; charset=utf-8"
            }
            
            return request
                .headers(headers)
                .body(data)
        } catch {
            throw NetworkError.encodingFailed(error)
        }
    }
}

// MARK: - Multipart Form Data Encoding

/// Encodes parameters as multipart/form-data.
///
/// Commonly used for file uploads.
public struct MultipartFormDataEncoding: ParameterEncoding, Sendable {
    /// Represents a part in multipart form data.
    public struct Part: Sendable {
        /// The data to upload.
        public let data: Data
        
        /// The name of the form field.
        public let name: String
        
        /// The filename (optional, for file uploads).
        public let fileName: String?
        
        /// The MIME type (optional).
        public let mimeType: String?
        
        public init(data: Data, name: String, fileName: String? = nil, mimeType: String? = nil) {
            self.data = data
            self.name = name
            self.fileName = fileName
            self.mimeType = mimeType
        }
    }
    
    /// The parts to include in the multipart form.
    public let parts: [Part]
    
    /// The boundary string.
    private let boundary: String
    
    public init(parts: [Part]) {
        self.parts = parts
        self.boundary = "Boundary-\(UUID().uuidString)"
    }
    
    public func encode(_ request: HTTPRequest, with parameters: [String: Any]?) throws -> HTTPRequest {
        var body = Data()
        
        // Add regular parameters
        if let parameters = parameters {
            for (key, value) in parameters {
                body.append("--\(boundary)\r\n")
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
                body.append("\(value)\r\n")
            }
        }
        
        // Add parts
        for part in parts {
            body.append("--\(boundary)\r\n")
            
            var disposition = "Content-Disposition: form-data; name=\"\(part.name)\""
            if let fileName = part.fileName {
                disposition += "; filename=\"\(fileName)\""
            }
            body.append("\(disposition)\r\n")
            
            if let mimeType = part.mimeType {
                body.append("Content-Type: \(mimeType)\r\n")
            }
            
            body.append("\r\n")
            body.append(part.data)
            body.append("\r\n")
        }
        
        body.append("--\(boundary)--\r\n")
        
        var headers = request.headers
        headers["Content-Type"] = "multipart/form-data; boundary=\(boundary)"
        
        return request
            .headers(headers)
            .body(body)
    }
}

// MARK: - Custom Encoding

/// A custom encoding that uses a Codable type.
///
/// This is useful for type-safe parameter encoding.
public struct CodableEncoding<T: Encodable>: ParameterEncoding {
    private let value: T
    private let encoder: JSONEncoder
    
    public init(value: T, encoder: JSONEncoder = JSONEncoder()) {
        self.value = value
        self.encoder = encoder
    }
    
    public func encode(_ request: HTTPRequest, with parameters: [String: Any]?) throws -> HTTPRequest {
        do {
            let data = try encoder.encode(value)
            
            var headers = request.headers
            if headers["Content-Type"] == nil {
                headers["Content-Type"] = "application/json; charset=utf-8"
            }
            
            return request
                .headers(headers)
                .body(data)
        } catch {
            throw NetworkError.encodingFailed(error)
        }
    }
}

// MARK: - Helpers

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

/// Custom encoding error.
private enum EncodingError: Error {
    case invalidData
}
