import Foundation

// There isn't a mutable NSHTTPURLResponse, so we have to make our own.
class MutableHTTPURLResponse: HTTPURLResponse {

    // MARK: - Properties

    private var _url: URL?
    override var url: URL? {
        get {
            return _url ?? super.url
        }

        set {
            _url = newValue
        }
    }

    private var _statusCode: Int?
    override var statusCode: Int {
        get {
            return _statusCode ?? super.statusCode
        }

        set {
            _statusCode = newValue
        }
    }

    private var _allHeaderFields: [NSObject : AnyObject]?
    override var allHeaderFields: [NSObject : AnyObject] {
        get {
            return _allHeaderFields ?? super.allHeaderFields
        }

        set {
            _allHeaderFields = newValue
        }
    }
}


extension HTTPURLResponse {
    override var dictionary: [String: AnyObject] {
        var dictionary = super.dictionary

        dictionary["headers"] = allHeaderFields
        dictionary["status"] = statusCode

        return dictionary
    }
}


extension MutableHTTPURLResponse {
    convenience init(dictionary: [String: AnyObject]) {
        if let string = dictionary["url"] as? String, url = URL(string: string) {
            self.init(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
        } else {
            fatalError("Expected URL in parameter dictionary")
        }
        

        if let headers = dictionary["headers"] as? [String: String] {
            allHeaderFields = headers
        }

        if let status = dictionary["status"] as? Int {
            statusCode = status
        }
    }
}
