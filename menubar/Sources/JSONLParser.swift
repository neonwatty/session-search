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

        for line in lines {
            guard let lineData = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let type = obj["type"] as? String else { continue }

            if type == "permission-mode" {
                sessionID = obj["sessionId"] as? String
                continue
            }

            guard type == "user" || type == "assistant" else { continue }

            if let ts = obj["timestamp"] as? String {
                if let date = isoFormatter.date(from: ts) {
                    if firstTimestamp == nil { firstTimestamp = date }
                    lastTimestamp = date
                }
            }

            if cwd == nil, let c = obj["cwd"] as? String {
                cwd = c
            }

            if sessionID == nil, let sid = obj["sessionId"] as? String {
                sessionID = sid
            }

            guard let message = obj["message"] as? [String: Any] else { continue }
            messageCount += 1

            if let contentStr = message["content"] as? String {
                contentParts.append(contentStr)
            } else if let contentArr = message["content"] as? [[String: Any]] {
                for block in contentArr {
                    if block["type"] as? String == "text",
                       let text = block["text"] as? String {
                        contentParts.append(text)
                    }
                }
            }
        }

        guard let sid = sessionID, let first = firstTimestamp, let last = lastTimestamp,
              messageCount > 0 else {
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
}
