// Copyright (c) 2015 Peter Siegesmund <peter.siegesmund@icloud.com>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation
import CryptoSwift

extension String {
    func dictionaryValue() -> NSDictionary? {
        if let data = self.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false) {
            let dictionary = try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(rawValue: 0)) as! NSDictionary
            return dictionary
        }
        return nil
    }
}

extension NSDictionary {
    func stringValue() -> String? {
        if let data = try? NSJSONSerialization.dataWithJSONObject(self, options: NSJSONWritingOptions(rawValue: 0)) {
            return NSString(data: data, encoding: NSASCIIStringEncoding) as? String
        }
        return nil
    }
}

// These are implemented as an extension because they're not a part of the DDP spec
extension DDP.Client {
    
    // callback is optional. If present, called with an error object as the first argument and,
    // if no error, the _id as the second.
    public func insert(collection:String, doc:NSArray, callback: ((result:AnyObject?, error:DDP.Error?) -> ())?) {
        let arg = "/\(collection)/insert"
        self.method(arg, params: doc, callback: callback)
    }
    
    // Insert without specifying a callback
    public func insert(collection:String, doc:NSArray) {
        insert(collection, doc:doc, callback:nil)
    }
    
    public func update(collection:String, doc:NSArray?, callback: ((result:AnyObject?, error:DDP.Error?) -> ())?) {
        let arg = "/\(collection)/update"
        method(arg, params: doc, callback: callback)
    }
    
    // Update without specifying a callback
    public func update(collection:String, doc:NSArray) {
        update(collection, doc:doc, callback:nil)
    }
    
    public func remove(collection:String, doc:NSArray, callback: ((result:AnyObject?, error:DDP.Error?) -> ())?) {
        let arg = "/\(collection)/remove"
        method(arg, params: doc, callback: callback)
    }
    
    // Remove without specifying a callback
    public func remove(collection:String, doc:NSArray) {
        remove(collection, doc:doc, callback:nil)
    }
    
    private func login(params: NSDictionary, callback: ((result:AnyObject?, error:DDP.Error?) -> ())?) {
        method("login", params: NSArray(arrayLiteral: params)) { result, error in
            guard let e = error where (e.isValid == true) else {
                if let data = result as? NSDictionary,
                   let id = data["id"] as? String,
                   let token = data["token"] as? String,
                   let tokenExpires = data["tokenExpires"] as? NSDictionary,
                   let date = tokenExpires["$date"] as? Int {
                        let timestamp = NSTimeInterval(Double(date)) / 1000.0
                        let expiration = NSDate(timeIntervalSince1970: timestamp)
                        self.userData.setObject(id, forKey: "id")
                        self.userData.setObject(token, forKey: "token")
                        self.userData.setObject(expiration, forKey: "tokenExpires")
                }
                if let c = callback { c(result:result, error:error) }
                return
            }
            
            log.debug("login error: \(e)")
            if let c = callback { c(result:result, error:error) }
        }
    }
    
    // Login with email and password
    public func loginWithPassword(email: String, password: String, callback: ((result:AnyObject?, error:DDP.Error?) -> ())?) {
        if !(loginWithToken(callback)) {
            let params = ["user":["email":email], "password":["digest":password.sha256()!, "algorithm":"sha-256"]] as NSDictionary
            login(params, callback:callback)
        }
    }
    
    // Does the date comparison account for TimeZone?
    public func loginWithToken(callback:((result:AnyObject?, error:DDP.Error?) -> ())?) -> Bool {
        if let token = userData.stringForKey("token"),
           let tokenDate = userData.objectForKey("tokenExpires") {
                if (tokenDate.compare(NSDate()) == NSComparisonResult.OrderedDescending) {
                    let params = ["resume":token] as NSDictionary
                    login(params, callback:callback)
                    return true
                }
        }
        return false
    }
    
    public func logout() {
        method("logout", params:nil, callback:nil)
    }
    
    public func logout(callback:((result:AnyObject?, error:DDP.Error?) -> ())?) {
        method("logout", params:nil, callback:callback)
    }
    
    public convenience init(url: String, email:String, password:String, callback:(result:AnyObject?, error:DDP.Error?) -> ()) {
        self.init(url:url)
        connect() { session in
            self.loginWithPassword(email, password: password, callback:callback)
        }
    }
}