//
//  BookProvider.swift
//  FolioReaderKit
//
//  Created by David Pei on 9/24/19.
//

import Foundation
import WebKit

final class BookProvider: NSObject, WKURLSchemeHandler {
    
    static let shared = BookProvider()
    
    var currentBook = FRBook()
    
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        // TODO: may not need this anymore
        guard let url = urlSchemeTask.request.url else { urlSchemeTask.didFailWithError(BookProviderURLProtocolError.urlNotExist)
            return
        }
        
        let urlResponse = URLResponse(url: url, mimeType: nil, expectedContentLength: -1, textEncodingName: nil)
        urlSchemeTask.didReceive(urlResponse)
        
        guard url.absoluteString.hasPrefix(BookProvider.shared.currentBook.baseURL.absoluteString) else {
            
            var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
            components?.scheme = "file"
            if let fileUrl = components?.url,
                let data = try? Data(contentsOf: fileUrl) {
                
                urlSchemeTask.didReceive(data)
                urlSchemeTask.didFinish()
                return
            }
            
            
            print("WWWWWW - can't load bookprovider url\n\(url)")
            urlSchemeTask.didFailWithError(BookProviderURLProtocolError.urlNotExist)
            return
        }
        
        var hrefSubStr = url.absoluteString.dropFirst(BookProvider.shared.currentBook.baseURL.absoluteString.count)
        if hrefSubStr.hasPrefix("/") {
            hrefSubStr = hrefSubStr.dropFirst()
        }
        let href = String(hrefSubStr)
        if let data = BookProvider.shared.currentBook.resources.findByHref(String(href))?.data {
            urlSchemeTask.didReceive(data)
        }
        urlSchemeTask.didFinish()
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // clean up
    }
    
    
}

enum BookProviderURLProtocolError: Error {
    case urlNotExist
}
