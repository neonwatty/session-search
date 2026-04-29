import Foundation

struct ParsedSession {
    let sessionID: String
    let cwd: String?
    let firstTimestamp: Date
    let lastTimestamp: Date
    let messageCount: Int
    let content: String
}

enum JSONLParser {
    enum ParseError: Error {
        case emptyFile
        case noMessages
    }

    static func parse(fileAt url: URL) throws -> ParsedSession {
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else { throw ParseError.emptyFile }

        let text = String(decoding: data, as: UTF8.self)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)

        var sessionID: String?
        var cwd: String?
        var firstTimestamp: Date?
        var lastTimestamp: Date?
        var messageCount = 0
        var contentParts: [String] = []

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let isoFallback = ISO8601DateFormatter()
        isoFallback.formatOptions = [.withInternetDateTime]

        for line in lines {
            guard let lineData = line.data(using: .utf8),
                let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                let type = obj["type"] as? String
            else { continue }

            if type == "permission-mode" {
                sessionID = obj["sessionId"] as? String
                continue
            }

            guard type == "user" || type == "assistant" else { continue }

            if let ts = obj["timestamp"] as? String {
                if let date = isoFormatter.date(from: ts) ?? isoFallback.date(from: ts) {
                    if firstTimestamp == nil { firstTimestamp = date }
                    lastTimestamp = date
                }
            }

            if cwd == nil, let c = obj["cwd"] as? String {
                cwd = c
                contentParts.append(c)
            }

            if sessionID == nil, let sid = obj["sessionId"] as? String {
                sessionID = sid
            }

            guard let message = obj["message"] as? [String: Any] else { continue }
            messageCount += 1

            collectSearchableText(from: message["content"], into: &contentParts)
        }

        guard let sid = sessionID, let first = firstTimestamp, let last = lastTimestamp,
            messageCount > 0
        else {
            throw ParseError.noMessages
        }

        return ParsedSession(
            sessionID: sid,
            cwd: cwd,
            firstTimestamp: first,
            lastTimestamp: last,
            messageCount: messageCount,
            content: contentParts.joined(separator: "\n")
        )
    }

    private static func collectSearchableText(from value: Any?, into parts: inout [String]) {
        if let text = value as? String {
            parts.append(text)
            return
        }

        if let array = value as? [Any] {
            for item in array {
                collectSearchableText(from: item, into: &parts)
            }
            return
        }

        guard let object = value as? [String: Any] else { return }
        if let type = object["type"] as? String {
            parts.append(type)
        }
        if let text = object["text"] as? String {
            parts.append(text)
        }
        if let name = object["name"] as? String {
            parts.append(name)
        }
        if let content = object["content"] {
            collectSearchableText(from: content, into: &parts)
        }
        if let input = object["input"] {
            collectSearchableObjectText(from: input, into: &parts)
        }
    }

    private static func collectSearchableObjectText(from value: Any, into parts: inout [String]) {
        if let text = value as? String {
            parts.append(text)
        } else if let number = value as? NSNumber {
            parts.append(number.stringValue)
        } else if let array = value as? [Any] {
            for item in array {
                collectSearchableObjectText(from: item, into: &parts)
            }
        } else if let object = value as? [String: Any] {
            for (key, value) in object {
                parts.append(key)
                collectSearchableObjectText(from: value, into: &parts)
            }
        }
    }
}
