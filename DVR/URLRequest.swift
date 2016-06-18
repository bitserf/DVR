import Foundation

extension URLRequest {
    init(dictionary: [String: AnyObject]) {
        if let string = dictionary["url"] as? String, url = URL(string: string) {
            self.init(url: url)
        } else {
            fatalError("Expected URL in parameter dictionary")
        }
        
        if let method = dictionary["method"] as? String {
            httpMethod = method
        }
                
        if let headers = dictionary["headers"] as? [String: String] {
            allHTTPHeaderFields = headers
        }
        
        if let body = dictionary["body"] {
            httpBody = Interaction.dencodeBody(body: body, headers: allHTTPHeaderFields)
        }
    }
    
    var dictionary: [String: AnyObject] {
        var dictionary = [String: AnyObject]()

        if let method = httpMethod {
            dictionary["method"] = method
        }

        if let url = self.url?.absoluteString {
            dictionary["url"] = url
        }

        if let headers = allHTTPHeaderFields {
            dictionary["headers"] = headers
        }

        if let data = httpBody, body = Interaction.encodeBody(body: data, headers: allHTTPHeaderFields) {
            dictionary["body"] = body
        }

        return dictionary
    }

    func appendingHeaders(headers: [NSObject: AnyObject]) -> URLRequest {
        var copy = self
        for (key, value) in headers {
            guard let key = key as? String else { continue }
            guard let value = value as? String else { continue }
            if let _ = allHTTPHeaderFields?[key] { continue }
            
            copy.setValue(value, forHTTPHeaderField: key)
        }
        return copy
    }
}
