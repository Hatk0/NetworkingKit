import Foundation

// MARK: - SSE Event

/// Represents a Server-Sent Event parsed from an SSE stream.
///
/// SSE is the standard protocol used by AI APIs (OpenAI, Claude, Gemini)
/// for streaming responses token-by-token.
///
/// Format:
/// ```
/// event: message
/// data: {"content": "Hello"}
/// id: 123
///
/// ```
public struct SSEEvent: Sendable, Equatable {
    /// The event type (optional, defaults to "message").
    public let event: String?
    
    /// The event data payload.
    public let data: String
    
    /// The event ID (optional).
    public let id: String?
    
    /// Retry interval in milliseconds (optional).
    public let retry: Int?
    
    public init(
        event: String? = nil,
        data: String,
        id: String? = nil,
        retry: Int? = nil
    ) {
        self.event = event
        self.data = data
        self.id = id
        self.retry = retry
    }
    
    /// Returns true if this is a stream termination event.
    public var isDone: Bool {
        data == "[DONE]"
    }
    
    /// Attempts to decode the data as JSON.
    public func decode<T: Decodable>(_ type: T.Type, using decoder: JSONDecoder = JSONDecoder()) throws -> T {
        guard let jsonData = data.data(using: .utf8) else {
            throw SSEParserError.invalidData
        }
        return try decoder.decode(type, from: jsonData)
    }
}

// MARK: - SSE Parser Error

/// Errors that can occur during SSE parsing.
public enum SSEParserError: Error, LocalizedError {
    case invalidData
    case streamClosed
    case decodingFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid SSE data format"
        case .streamClosed:
            return "SSE stream was closed unexpectedly"
        case .decodingFailed(let error):
            return "Failed to decode SSE data: \(error.localizedDescription)"
        }
    }
}

// MARK: - SSE Parser

/// Parses Server-Sent Events from a byte stream.
///
/// This parser handles the SSE protocol format:
/// - `event:` - Event type
/// - `data:` - Event data (can span multiple lines)
/// - `id:` - Event ID
/// - `retry:` - Reconnection time
/// - Empty line terminates an event
///
/// Example:
/// ```swift
/// let parser = SSEParser()
/// for try await event in parser.parse(dataStream) {
///     print(event.data)
/// }
/// ```
public actor SSEParser {
    private var buffer: String = ""
    private var currentEvent: String?
    private var currentData: [String] = []
    private var currentId: String?
    private var currentRetry: Int?
    
    public init() {}
    
    /// Parses an async stream of data chunks into SSE events.
    ///
    /// - Parameter stream: An async stream of data chunks
    /// - Returns: An async stream of parsed SSE events
    public func parse(_ stream: AsyncThrowingStream<Data, Error>) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await chunk in stream {
                        let events = self.processChunk(chunk)
                        for event in events {
                            continuation.yield(event)
                        }
                    }
                    // Process any remaining buffer
                    let finalEvents = self.flush()
                    for event in finalEvents {
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Processes a data chunk and returns any complete events.
    private func processChunk(_ chunk: Data) -> [SSEEvent] {
        guard let text = String(data: chunk, encoding: .utf8) else {
            return []
        }
        
        buffer.append(text)
        return extractEvents()
    }
    
    /// Extracts complete events from the buffer.
    private func extractEvents() -> [SSEEvent] {
        var events: [SSEEvent] = []
        
        // Split by double newline (event separator)
        let components = buffer.components(separatedBy: "\n\n")
        
        // Process all complete events (all but last component)
        for i in 0..<components.count - 1 {
            if let event = parseEventBlock(components[i]) {
                events.append(event)
            }
            resetCurrentEvent()
        }
        
        // Keep incomplete data in buffer
        buffer = components.last ?? ""
        
        return events
    }
    
    /// Parses a single event block.
    private func parseEventBlock(_ block: String) -> SSEEvent? {
        let lines = block.components(separatedBy: "\n")
        
        for line in lines {
            parseLine(line)
        }
        
        // Create event if we have data
        guard !currentData.isEmpty else {
            return nil
        }
        
        let data = currentData.joined(separator: "\n")
        return SSEEvent(
            event: currentEvent,
            data: data,
            id: currentId,
            retry: currentRetry
        )
    }
    
    /// Parses a single line of SSE data.
    private func parseLine(_ line: String) {
        // Ignore comments
        if line.hasPrefix(":") {
            return
        }
        
        // Parse field: value format
        if let colonIndex = line.firstIndex(of: ":") {
            let field = String(line[..<colonIndex])
            var value = String(line[line.index(after: colonIndex)...])
            
            // Remove leading space if present
            if value.hasPrefix(" ") {
                value.removeFirst()
            }
            
            switch field {
            case "event":
                currentEvent = value
            case "data":
                currentData.append(value)
            case "id":
                currentId = value
            case "retry":
                currentRetry = Int(value)
            default:
                break
            }
        }
    }
    
    /// Resets the current event state.
    private func resetCurrentEvent() {
        currentEvent = nil
        currentData = []
        currentId = nil
        currentRetry = nil
    }
    
    /// Flushes any remaining data in the buffer.
    private func flush() -> [SSEEvent] {
        guard !buffer.isEmpty else {
            return []
        }
        
        if let event = parseEventBlock(buffer) {
            resetCurrentEvent()
            buffer = ""
            return [event]
        }
        
        return []
    }
}

// MARK: - Convenience Extensions

extension SSEParser {
    /// Parses SSE events from raw data.
    ///
    /// - Parameter data: The complete SSE data to parse
    /// - Returns: An array of parsed events
    public func parseAll(_ data: Data) async -> [SSEEvent] {
        guard let text = String(data: data, encoding: .utf8) else {
            return []
        }
        
        buffer = text
        return extractEvents() + flush()
    }
}
