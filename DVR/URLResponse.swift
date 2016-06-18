import Foundation

extension URLResponse {
    var dictionary: [String: AnyObject] {
        if let url = self.url?.absoluteString {
            return ["url": url]
        }

        return [:]
    }
}
