import Foundation

enum EuropeanArticleNumberNormalizer {
    static func normalizeRawOrURL(_ rawInput: String) -> String? {
        let decoded = rawInput.removingPercentEncoding ?? rawInput
        let digitRuns = decoded.split { !$0.isNumber }.map(String.init)
        let eligibleRuns = digitRuns.filter { (8...14).contains($0.count) }
        let candidate: String
        if let lastRun = eligibleRuns.last {
            candidate = lastRun
        } else {
            candidate = String(decoded.filter(\.isNumber))
        }
        guard !candidate.isEmpty else { return nil }
        if candidate.count == 12 {
            return "0" + candidate
        }
        if (8...14).contains(candidate.count) {
            return candidate
        }
        return nil
    }
}
