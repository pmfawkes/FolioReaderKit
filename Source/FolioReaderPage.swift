//
//  FolioReaderPage.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 10/04/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit
import SafariServices
import MenuItemKit
import WebKit
import os.log

/// Protocol which is used from `FolioReaderPage`s.
@objc public protocol FolioReaderPageDelegate: class {

    /**
     Notify that the page will be loaded. Note: The webview content itself is already loaded at this moment. But some java script operations like the adding of class based on click listeners will happen right after this method. If you want to perform custom java script before this happens this method is the right choice. If you want to modify the html content (and not run java script) you have to use `htmlContentForPage()` from the `FolioReaderCenterDelegate`.

     - parameter page: The loaded page
     */
    @objc optional func pageWillLoad(_ page: FolioReaderPage)

    /**
     Notifies that page did load. A page load doesn't mean that this page is displayed right away, use `pageDidAppear` to get informed about the appearance of a page.

     - parameter page: The loaded page
     */
    @objc optional func pageDidLoad(_ page: FolioReaderPage)
    
    /**
     Notifies that page receive tap gesture.
     
     - parameter recognizer: The tap recognizer
     */
    @objc optional func pageTap(_ recognizer: UITapGestureRecognizer)
    
    /**
     The delegate assignee is responsible to provide the user CFI information.
     If not, folioReader uses its local location tracking data.
     
     */
    @objc optional func getUserCFI(completionHandler: @escaping (String?) -> Void )
    
    /**
     Notify the delegate assignee that user CFI has changed
     
     */
    @objc optional func userCFIChanged(cfi: String)
}

open class FolioReaderPage: UICollectionViewCell, WKNavigationDelegate, UIGestureRecognizerDelegate {
    weak var delegate: FolioReaderPageDelegate?
    weak var readerContainer: FolioReaderContainer?

    /// The index of the current page. Note: The index start at 1!
    open var pageNumber: Int!
    open var webView: FolioReaderWebView?

    fileprivate var colorView: UIView!

    fileprivate var readerConfig: FolioReaderConfig {
        guard let readerContainer = readerContainer else { return FolioReaderConfig() }
        return readerContainer.readerConfig
    }

    fileprivate var book: FRBook {
        return BookProvider.shared.currentBook
    }

    fileprivate var folioReader: FolioReader {
        guard let readerContainer = readerContainer else { return FolioReader() }
        return readerContainer.folioReader
    }

    // MARK: - View life cicle

    public override init(frame: CGRect) {
        // Init explicit attributes with a default value. The `setup` function MUST be called to configure the current object with valid attributes.
        self.readerContainer = FolioReaderContainer(withConfig: FolioReaderConfig(), folioReader: FolioReader(), epubPath: "")
        super.init(frame: frame)
        self.backgroundColor = UIColor.clear

        NotificationCenter.default.addObserver(self, selector: #selector(refreshPageMode), name: NSNotification.Name(rawValue: "needRefreshPageMode"), object: nil)
    }

    public func setup(withReaderContainer readerContainer: FolioReaderContainer) {
        self.readerContainer = readerContainer
        guard let readerContainer = self.readerContainer else { return }

        if webView == nil {
            webView = FolioReaderWebView(frame: webViewFrame(), readerContainer: readerContainer)
            webView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            webView?.scrollView.showsVerticalScrollIndicator = false
            webView?.scrollView.showsHorizontalScrollIndicator = false
            webView?.backgroundColor = .clear
            webView?.isOpaque = false
            
            self.contentView.addSubview(webView!)
        }
        webView?.navigationDelegate = self
        
        if colorView == nil {
            colorView = UIView()
            colorView.backgroundColor = self.readerConfig.nightModeBackground
            webView?.scrollView.addSubview(colorView)
        }

        // Remove all gestures before adding new one
        webView?.gestureRecognizers?.forEach({ gesture in
            webView?.removeGestureRecognizer(gesture)
        })
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        tapGestureRecognizer.numberOfTapsRequired = 1
        tapGestureRecognizer.delegate = self
        webView?.addGestureRecognizer(tapGestureRecognizer)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("storyboards are incompatible with truth and beauty")
    }

    deinit {
        webView?.scrollView.delegate = nil
        webView?.navigationDelegate = nil
        NotificationCenter.default.removeObserver(self)
    }

    override open func layoutSubviews() {
        super.layoutSubviews()

        webView?.setupScrollDirection()
        webView?.frame = webViewFrame()
    }
    
    func webViewFrame() -> CGRect {
        guard (self.readerConfig.hideBars == false) else {
            return bounds
        }

        let statusbarHeight = UIApplication.shared.statusBarFrame.size.height
        let navBarHeight = self.folioReader.readerCenter?.navigationController?.navigationBar.frame.size.height ?? CGFloat(0)
        let navTotal = self.readerConfig.shouldHideNavigationOnTap ? 0 : statusbarHeight + navBarHeight
        let paddingTop: CGFloat = 20
        let paddingBottom: CGFloat = 30

        return CGRect(
            x: bounds.origin.x,
            y: self.readerConfig.isDirection(bounds.origin.y + navTotal, bounds.origin.y + navTotal + paddingTop, bounds.origin.y + navTotal),
            width: bounds.width,
            height: self.readerConfig.isDirection(bounds.height - navTotal, bounds.height - navTotal - paddingTop - paddingBottom, bounds.height - navTotal)
        )
    }

    func loadHTMLString(_ htmlContent: String!, baseURL: URL!) {
        // Load the html into the webview
        webView?.alpha = 0
        let headerString = "<meta name=\"viewport\" content=\"initial-scale=1.0\" />"
        webView?.loadHTMLString(headerString + htmlContent, baseURL: baseURL)
    }
    
    // MARK: - Highlights
    fileprivate func insertHighlights() {
        // Restore highlights
        guard let bookId = (self.book.name as NSString?)?.deletingPathExtension else {
            return
        }
        
        let highlights = DBAPIManager.shared.getAllHighlight(byBookId: bookId, page: pageNumber)
        
        guard highlights.count > 0 else { return }
        for highlight in highlights {
            let style = HighlightStyle.classForStyle(highlight.type)
            
            let onClickAction = highlight.noteForHighlight == nil ? "callHighlightURL(this);" : "callHighlightWithNoteURL(this);"
            webView?.js("recreateHighlight('\(highlight.id)','\(style)','\(onClickAction)','\(highlight.startLocation)','\(highlight.endLocation)')")
        }
    }
    
    // MARK: - WKWebView Delegate
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if #available(iOS 14.0, *) {
            os_log("\(#function) start")
        }
        guard let webView = webView as? FolioReaderWebView else {
            return
        }

        delegate?.pageWillLoad?(self)
        insertHighlights()

        // Add the custom class based onClick listener
        self.setupClassBasedOnClickListeners()

        refreshPageMode()

        if self.readerConfig.enableTTS && !self.book.hasAudio {
            webView.js("wrappingSentencesWithinPTags()")

            if let audioPlayer = self.folioReader.readerAudioPlayer, (audioPlayer.isPlaying() == true) {
                audioPlayer.readCurrentSentence()
            }
        }

        let direction: ScrollDirection = self.folioReader.needsRTLChange ? .positive(withConfiguration: self.readerConfig) : .negative(withConfiguration: self.readerConfig)

//        webView.js("document.readyState") { _, _ in
//            webView.js("document.documentElement.scrollWidth") { [weak self] width, error in
//                guard let self = self else { return }
                if (self.folioReader.readerCenter?.pageScrollDirection == direction &&
                    self.folioReader.readerCenter?.isScrolling == true &&
                    self.readerConfig.scrollDirection != .horizontalWithVerticalContent) {
                    self.scrollPageToBottom()
                }

                UIView.animate(withDuration: 0.2, animations: {webView.alpha = 1}, completion: { finished in
                    webView.isColors = false
                    self.webView?.createMenu(options: false)
                })

        if #available(iOS 14.0, *) {
            os_log("document.readyState - start")
        }
                webView.js("document.readyState") { [weak self] (_, _) in
                    guard let self = self else { return }
                    if #available(iOS 14.0, *) {
                        os_log("\(#function) delegate.pageDidLoad")
                    }
                    self.delegate?.pageDidLoad?(self)
                }
//            }
//        }
        
    }

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if #available(iOS 14.0, *) {
            os_log("\(#function) start")
        }
        let request = navigationAction.request
        let navigationType = navigationAction.navigationType
        
        guard let webView = webView as? FolioReaderWebView,
            let scheme = request.url?.scheme else {
            if #available(iOS 14.0, *) {
                os_log("\(#function) .allow")
            }
                decisionHandler(.allow)
                return
        }

        guard let url = request.url else {
            if #available(iOS 14.0, *) {
                os_log("\(#function) request.url .cancel")
            }
            decisionHandler(.cancel)
            return
        }
        
        if scheme == "highlight" || scheme == "highlight-with-note" {
            guard let decoded = url.absoluteString.removingPercentEncoding else { decisionHandler(.cancel); return }
            let index = decoded.index(decoded.startIndex, offsetBy: 12)
            let rect = NSCoder.cgRect(for: String(decoded[index...]))

            webView.createMenu(options: true)
            webView.setMenuVisible(true, andRect: rect)
            if #available(iOS 14.0, *) {
                os_log("\(#function) highlight .cancel")
            }
            decisionHandler(.cancel)
            return
        } else if scheme == "play-audio" {
            guard let decoded = url.absoluteString.removingPercentEncoding else { decisionHandler(.cancel); return }
            let index = decoded.index(decoded.startIndex, offsetBy: 13)
            let playID = String(decoded[index...])
            let chapter = self.folioReader.readerCenter?.getCurrentChapter()
            let href = chapter?.href ?? ""
            self.folioReader.readerAudioPlayer?.playAudio(href, fragmentID: playID)
            decisionHandler(.cancel)
            return
        } else if scheme == "file" || scheme == "bookprovider" {

            let anchorFromURL = url.fragment

            // Handle internal url
            if !url.pathExtension.isEmpty {
                let pathComponent = (self.book.opfResource.href as NSString?)?.deletingLastPathComponent
                guard let base = ((pathComponent == nil || pathComponent?.isEmpty == true) ? self.book.name : pathComponent) else {
                    decisionHandler(.allow)
                    return
                }

                let path = url.path
                let splitedPath = path.components(separatedBy: base)

                // Return to avoid crash
                if (splitedPath.count <= 1 || splitedPath[1].isEmpty) {
                    decisionHandler(.allow)
                    if #available(iOS 14.0, *) {
                        os_log("\(#function) avoid crash .allow")
                    }
                    return
                }

                let href = splitedPath[1].trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                let hrefPage = (self.folioReader.readerCenter?.findPageByHref(href) ?? 0) + 1

                if (hrefPage == pageNumber) {
                    // Handle internal #anchor
                    if anchorFromURL != nil {
                        handleAnchor(anchorFromURL!, avoidBeginningAnchors: false, animated: true)
                        decisionHandler(.cancel)
                        return
                    }
                } else {
                    self.folioReader.readerCenter?.changePageWith(href: href, animated: true)
                }
                decisionHandler(.cancel)
                return
            }

            // Handle internal #anchor
            if anchorFromURL != nil {
                handleAnchor(anchorFromURL!, avoidBeginningAnchors: false, animated: true)
                decisionHandler(.cancel)
                return
            }
            if #available(iOS 14.0, *) {
                os_log("\(#function) bookprovider .allow")
            }
            decisionHandler(.allow)
            return
        } else if scheme == "mailto" {
            print("Email")
            decisionHandler(.allow)
            return
        } else if url.absoluteString != "about:blank" && scheme.contains("http") && navigationType == .linkActivated {
            let safariVC = SFSafariViewController(url: request.url!)
            safariVC.view.tintColor = self.readerConfig.tintColor
            self.folioReader.readerCenter?.present(safariVC, animated: true, completion: nil)
            decisionHandler(.cancel)
            return
        } else {
            // Check if the url is a custom class based onClick listerner
            var isClassBasedOnClickListenerScheme = false
            for listener in self.readerConfig.classBasedOnClickListeners {

                if scheme == listener.schemeName,
                    let absoluteURLString = request.url?.absoluteString,
                    let range = absoluteURLString.range(of: "/clientX=") {
                    let baseURL = String(absoluteURLString[..<range.lowerBound])
                    let positionString = String(absoluteURLString[range.lowerBound...])
                    if let point = getEventTouchPoint(fromPositionParameterString: positionString) {
                        let attributeContentString = (baseURL.replacingOccurrences(of: "\(scheme)://", with: "").removingPercentEncoding)
                        // Call the on click action block
                        listener.onClickAction(attributeContentString, point)
                        // Mark the scheme as class based click listener scheme
                        isClassBasedOnClickListenerScheme = true
                    }
                }
            }

            if isClassBasedOnClickListenerScheme == false {
                // Try to open the url with the system if it wasn't a custom class based click listener
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }
            } else {
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
        return
    }

    fileprivate func getEventTouchPoint(fromPositionParameterString positionParameterString: String) -> CGPoint? {
        // Remove the parameter names: "/clientX=188&clientY=292" -> "188&292"
        var positionParameterString = positionParameterString.replacingOccurrences(of: "/clientX=", with: "")
        positionParameterString = positionParameterString.replacingOccurrences(of: "clientY=", with: "")
        // Separate both position values into an array: "188&292" -> [188],[292]
        let positionStringValues = positionParameterString.components(separatedBy: "&")
        // Multiply the raw positions with the screen scale and return them as CGPoint
        if
            positionStringValues.count == 2,
            let xPos = Int(positionStringValues[0]),
            let yPos = Int(positionStringValues[1]) {
            return CGPoint(x: xPos, y: yPos)
        }
        return nil
    }

    // MARK: Gesture recognizer

    open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer.view is FolioReaderWebView else { return false }
        guard otherGestureRecognizer is UILongPressGestureRecognizer else { return true }
        if UIMenuController.shared.isMenuVisible {
            webView?.setMenuVisible(false)
        } else if let webView = webView, !webView.isShare && !webView.isColors {
            webView.js("getSelectedText()") { (callback, error) in
                guard error == nil, let result = callback as? String, result.components(separatedBy: " ").count == 1 else {
                    webView.isOneWord = false
                    return
                }
                webView.isOneWord = true
                webView.createMenu(options: false)
            }
        }
        return false
    }

    @objc open func handleTapGesture(_ recognizer: UITapGestureRecognizer) {
        self.delegate?.pageTap?(recognizer)
        
        if let _navigationController = folioReader.readerCenter?.navigationController, _navigationController.isNavigationBarHidden {
            
            webView?.js("getSelectedText()", completionHandler: { (selected, error) in
                guard error == nil, (selected as? String)?.isEmpty ?? true else { return }
                let delay = 0.4
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.folioReader.readerCenter?.toggleBars()
                }
            })
        } else if readerConfig.shouldHideNavigationOnTap {
            folioReader.readerCenter?.hideBars()
        }
    }

    // MARK: - Public scroll postion setter

    /**
     Scrolls the page to a given offset

     - parameter offset:   The offset to scroll
     - parameter animated: Enable or not scrolling animation
     */
    open func scrollPageToOffset(_ offset: CGFloat, animated: Bool) {
        let pageOffsetPoint = self.readerConfig.isDirection(CGPoint(x: 0, y: offset), CGPoint(x: offset, y: 0), CGPoint(x: 0, y: offset))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if #available(iOS 14.0, *) {
                os_log("\(#function) setContentOffset \(pageOffsetPoint)")
            }
            self.webView?.scrollView.setContentOffset(pageOffsetPoint, animated: animated)
        }
    }

    /**
     Scrolls the page to bottom
     */
    open func scrollPageToBottom() {
        guard let webView = webView else { return }
        let bottomOffset = readerConfig.isDirection(
            CGPoint(x: 0, y: webView.scrollView.contentSize.height - webView.scrollView.bounds.height),
            CGPoint(x: webView.scrollView.contentSize.width - webView.scrollView.bounds.width, y: 0),
            CGPoint(x: webView.scrollView.contentSize.width - webView.scrollView.bounds.width, y: 0)
        )
        if #available(iOS 14.0, *) {
            os_log("\(#function) - bottomOffset: \(bottomOffset)")
            os_log("\(#function) - webView.scrollView: \(webView.scrollView)")
        }
        
        guard bottomOffset.forDirection(withConfiguration: readerConfig) >= 0 else { return }
        webView.scrollView.layoutIfNeeded()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            webView.scrollView.setContentOffset(bottomOffset, animated: false)
            if #available(iOS 14.0, *) {
                os_log("\(#function) content offset: \(webView.scrollView.contentOffset)")
            }
        }
        
    }

    /**
     Handdle #anchors in html, get the offset and scroll to it

     - parameter anchor:                The #anchor
     - parameter avoidBeginningAnchors: Sometimes the anchor is on the beggining of the text, there is not need to scroll
     - parameter animated:              Enable or not scrolling animation
     */
    open func handleAnchor(_ anchor: String,  avoidBeginningAnchors: Bool, animated: Bool) {
        guard !anchor.isEmpty else { return }
        getAnchorOffset(anchor) { [weak self] (callback) in
            guard let offset = callback, let strongSelf = self else { return }
            
            switch strongSelf.readerConfig.scrollDirection {
            case .vertical, .defaultVertical:
                let isBeginning = (offset < strongSelf.frame.forDirection(withConfiguration: strongSelf.readerConfig) * 0.5)

                if !avoidBeginningAnchors {
                    strongSelf.scrollPageToOffset(offset, animated: animated)
                } else if avoidBeginningAnchors && !isBeginning {
                    strongSelf.scrollPageToOffset(offset, animated: animated)
                }
            case .horizontal, .horizontalWithVerticalContent:
                strongSelf.scrollPageToOffset(offset, animated: animated)
            }
        }
    }

    // MARK: Helper

    /**
     Get the #anchor offset in the page

     - parameter anchor: The #anchor id
     - returns: The element offset ready to scroll
     */
    func getAnchorOffset(_ anchor: String, completion: @escaping ((CGFloat?) -> Void)) {
        let horizontal = self.readerConfig.scrollDirection == .horizontal
        webView?.js("getAnchorOffset('\(anchor)', \(horizontal.description))", completionHandler: { (callback, error) in
            guard error == nil, let offset = callback as? NSString else {
                completion(CGFloat(0))
                return
            }
            completion(CGFloat(offset.floatValue))
        })
    }
    
    /// Get reading position offset
    ///
    /// - Parameters:
    ///   - value: The DOM element array String
    /// - Returns: Offset position to scroll to
    func getReadingPositionOffset(value: String, completion: @escaping ((CGFloat?) -> Void)) {
        let horizontal = readerConfig.scrollDirection == .horizontal
        
        webView?.js("getReadingPositionOffset(\(horizontal.description), \(value))", completionHandler: { (callback, error) in
            guard error == nil,
                let offset = callback as? Int else {
                    completion(nil)
                    return
            }
            
            completion(CGFloat(offset))
        })
    }
    
    // MARK: Mark ID

    /**
     Audio Mark ID - marks an element with an ID with the given class and scrolls to it

     - parameter identifier: The identifier
     */
    func audioMarkID(_ identifier: String) {
        guard let currentPage = self.folioReader.readerCenter?.currentPage else {
            return
        }

        let playbackActiveClass = self.book.playbackActiveClass
        currentPage.webView?.js("audioMarkID('\(playbackActiveClass)','\(identifier)')")
    }

    // MARK: UIMenu visibility

    override open func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        guard let webView = webView else { return false }
        
        if UIMenuController.shared.menuItems?.count == 0 {
            webView.isColors = false
            webView.createMenu(options: false)
        }

        return super.canPerformAction(action, withSender: sender)
    }

    // MARK: ColorView fix for horizontal layout
    @objc func refreshPageMode() {
        guard let webView = webView else { return }

        if folioReader.nightMode == true {
            // omit create webView and colorView
            let script = "document.documentElement.offsetHeight"
            webView.js(script) { [weak self] (callback, error) in
                guard error == nil, let contentHeight = callback as? Int else {
                    self?.colorView.frame = .zero
                    return
                }
                let frameHeight = webView.frame.height
                let lastPageHeight = frameHeight * CGFloat(1) - CGFloat(Double(contentHeight))
                self?.colorView.frame = CGRect(x: webView.frame.width * CGFloat(0), y: webView.frame.height - lastPageHeight, width: webView.frame.width, height: lastPageHeight)
            }
        } else {
            colorView.frame = .zero
        }
    }
    
    // MARK: - Class based click listener
    
    fileprivate func setupClassBasedOnClickListeners() {
        for listener in self.readerConfig.classBasedOnClickListeners {
            self.webView?.js("addClassBasedOnClickListener(\"\(listener.schemeName)\", \"\(listener.querySelector)\", \"\(listener.attributeName)\", \"\(listener.selectAll)\")");
        }
    }
}

extension CGPoint: CustomStringConvertible {
    public var description: String {
        return "x:\(x) y\(y)"
    }
}
