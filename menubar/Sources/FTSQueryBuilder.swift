import Foundation

extension SessionStore {
    static func sanitizeFTSQuery(_ input: String) -> String {
        var result = input.replacingOccurrences(of: "\"", with: "\"\"")
        let ftsSpecials: [Character] = ["*", "^", "(", ")", "{", "}", "[", "]", "+", "|"]
        result.removeAll { ftsSpecials.contains($0) }
        return result
    }

    static func makeFTSQuery(_ input: String) -> String? {
        let terms = tokenizeSearchTerms(input)
        guard !terms.isEmpty else { return nil }
        return terms.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"*" }
            .joined(separator: " ")
    }

    private static func tokenizeSearchTerms(_ input: String) -> [String] {
        var terms: [String] = []
        var current = ""
        let tokenCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))

        for scalar in input.unicodeScalars {
            if tokenCharacters.contains(scalar) {
                current.unicodeScalars.append(scalar)
            } else if !current.isEmpty {
                terms.append(current)
                current = ""
            }
        }

        if !current.isEmpty {
            terms.append(current)
        }
        return terms
    }
}
