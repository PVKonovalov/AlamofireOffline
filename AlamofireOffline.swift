//
//  AlamofireOffline.swift
//
//  Copyright © 2018 Pavel Konovalov. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation
import Alamofire
import SwiftyJSON

///
/// Sources of data
///
public enum requestResponseJSONWithOfflineSource {
  /// - online: Data received from the external site
  case online
  /// - offline: Data restored from the internal cache
  case offline
}

///
/// HTTP status code
///
public enum HTTPStatusCode: Int {
  /// - ok: Status OK
  case ok=200
}


/// Returns a date of the file last modified
///
/// - Parameter path: Path to the file
/// - Returns: Date of the last modified as NSDate or nil
func lastModified(path: String) -> NSDate? {
  let fileUrl = NSURL(fileURLWithPath: path)
  var modified: AnyObject?
  do {
    try fileUrl.getResourceValue(&modified, forKey: URLResourceKey.contentModificationDateKey)
    return modified as? NSDate
  } catch _ as NSError {
    return nil
  }
}

// MARK: - Data Request

/// Creates and executes a 'Alamofire DataRequest' using the default 'SessionManager' to retrieve the contents of the specified
/// 'url', 'cacheName', 'method', 'parameters', 'encoding', 'headers' and 'result'. If the response from the external site is valid,
/// all data saved to local cache otherwise an attempt is made to read data from the local cache and converted to JSON.
/// Returns JSON.null if the local cache is empty.
/// See Alamofire documentation for detail about Alamofire.
///
/// - Parameters:
///   - url: URL
///   - cacheName: Internal cache name for the specific URL
///   - method: HTTP method. '.get' by default
///   - parameters: Parameters. 'nil' by default
///   - encoding: Parameter encoding. 'URLEncoding.default' by default
///   - headers: HTTP headers. 'nil' by default
///   - result: Closure used to determine JSON data from the result of the URL request
///   - statusCode: HTTP status code
///   - json: JSON data
///   - source: Source of data as requestResponseJSONWithOfflineSource
public func requestResponseJSONWithOffline(_ url: URLConvertible,
                                           cacheName: String,
                                           method: HTTPMethod = .get,
                                           parameters: Parameters? = nil,
                                           encoding: ParameterEncoding = URLEncoding.default,
                                           headers: HTTPHeaders? = nil,
                                           result: @escaping (_ statusCode: Int?, _ json: JSON, _ source: requestResponseJSONWithOfflineSource) -> Void) {
  Alamofire.request(url, method: method, parameters: parameters, encoding: encoding, headers: headers).responseJSON {
    response in
    
    let manager = FileManager.default
    let url = manager.urls(for: .cachesDirectory, in: .userDomainMask).first
    let cacheUrl = url!.appendingPathComponent(cacheName)
    let cachePath = cacheUrl.path
    
    if response.value != nil {
      let statusCode = response.response?.statusCode
      let json = JSON(response.value!)
      if statusCode == HTTPStatusCode.ok.rawValue {
        NSKeyedArchiver.archiveRootObject(response.value!, toFile: cachePath)
      }
      result(statusCode, json, .online)
    } else {
      if let response_value = NSKeyedUnarchiver.unarchiveObject(withFile: cachePath)  {
        let statusCode = HTTPStatusCode.ok.rawValue
        let json = JSON(response_value)
        result(statusCode, json, .offline)
      } else {
        result(nil, JSON.null, .offline)
      }
    }
  }
}


/// Loads data from the internal cache by name as JSON
///
/// - Parameters:
///   - cacheName: Internal cache name for the specific URL
///   - result: Closure used to determine JSON data from the result of the internal cache load
///   - statusCode: HTTP status code
///   - json: JSON data
///   - source: Source of data as requestResponseJSONWithOfflineSource. Always '.offline'
///   - modificationDate: Date of modifications of cache
public func requestResponseFromOffline( cacheName: String, result: @escaping (_ statusCode: Int?, _ json: JSON, _ source: requestResponseJSONWithOfflineSource, _ modificationDate: Date?) -> Void) {
  DispatchQueue.main.async() {
    let manager = FileManager.default
    let url = manager.urls(for: .cachesDirectory, in: .userDomainMask).first
    let cacheUrl = url!.appendingPathComponent(cacheName)
    let cachePath = cacheUrl.path
    var modificationDate: Date?
    do {
      try  modificationDate = cacheUrl.resourceValues(forKeys: [URLResourceKey.contentModificationDateKey]).contentModificationDate
    } catch {
      modificationDate = nil
    }
    
    if let response_value = NSKeyedUnarchiver.unarchiveObject(withFile: cachePath)  {
      let status = HTTPStatusCode.ok.rawValue
      let json = JSON(response_value)
      result(status, json, .offline, modificationDate)
    } else {
      result(nil, JSON.null, .offline, modificationDate)
    }
  }
}
