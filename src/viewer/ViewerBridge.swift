//***************************************************************************
//* Written by Steve Chiu <steve.chiu@benq.com>
//* BenQ Corporation, All Rights Reserved.
//*
//* NOTICE: All information contained herein is, and remains the property
//* of BenQ Corporation and its suppliers, if any. Dissemination of this
//* information or reproduction of this material is strictly forbidden
//* unless prior written permission is obtained from BenQ Corporation.
//***************************************************************************

import UIKit

//---------------------------------------------------------------------------

class ViewerBridge {
    private unowned var scene: ViewerScene
    private var webView: UIWebView
    
    init(scene: ViewerScene) {
        self.scene = scene
        self.webView = scene.webView
    }
    
    private func eval(script: String) -> String? {
        return self.webView.stringByEvaluatingJavaScriptFromString(script)
    }

    func bindCallbacks() {
        do {
            let path = NSBundle.mainBundle().pathForResource("ViewerBridge", ofType: "js")!
            let script = try String(contentsOfFile: path)
            eval(script)
        } catch let error {
            fatalError("can not bind javascript bridge: \(error)")
        }
    }
    
    func dispatchCallback(request: NSURLRequest) -> Bool {
        guard let url = request.URL where url.scheme == "app" else {
            return false
        }
        
        do {
            let json = url.query?.stringByRemovingPercentEncoding
            let args = try JsonArray(string: json ?? "[]")
            
            switch url.host! {
            case "onChangeTitle":
                try onChangeTitle(try args.getString(0))
                
            case "onChangeTOC":
                try onChangeTOC(try args.getArray(0))
        
            case "onChangeView":
                try onChangeView(try args.getDouble(0), try args.getDouble(1), scale: try args.getDouble(2))

            case "onChangePage":
                try onChangePage(try args.getString(0), cfi: try args.getString(1), percentage: try args.getInt(2))
                
            case "onTrackAction":
                try onTrackAction(try args.getString(0), cfi: try args.getString(1))
                
            case "onToggleToolbar":
                try onToggleToolbar(try args.getBool(0))
                
            case "onRequestHighlights":
                try onRequestHighlights(try args.getString(0), callback: try args.getString(1))
                
            case "onAddHighlight":
                try onAddHighlight(try args.getString(0), highlight: try args.getObject(1), callback: try args.getString(2))
                
            case "onUpdateHighlight":
                try onUpdateBookmark(try args.getObject(0))
                
            case "onRemoveHighlight":
                try onRemoveHighlight(try args.getString(0))
                
            case "onShareHighlight":
                try onShareHighlight(try args.getString(0))

            case "onAnnotateHighlight":
                try onAnnotateHighlight(try args.getString(0))

            case "onRequestBookmarks":
                try onRequestBookmarks(try args.getString(0), callback: try args.getString(1))
                
            case "onAddBookmark":
                try onAddBookmark(try args.getString(0), bookmark: try args.getObject(1), callback: try args.getString(2))
                
            case "onUpdateBookmark":
                try onUpdateBookmark(try args.getObject(0))
                
            case "onRemoveBookmark":
                try onRemoveBookmark(try args.getString(0))
                
            case "onSearchResult":
                try onSearchResult(try args.getString(0), results: try args.getArray(1))
                
            case "log":
                NSLog("Log %@", args.optString(0) ?? "")

            default:
                NSLog("ViewerBridge: unknown method %@ = %@", url.host!, url)
            }
        } catch let error {
            NSLog("ViewerBridge: [%@] error=%@", url, error as NSError)
        }
        
        return true
    }
    
    enum LayoutMode : String {
        case Single = "single"
        case SideBySide = "side_by_side"
        case Continuous = "continuous"
    }
    
    ///
    /// Load ebook from server url
    /// App will act as transparent proxy, and provides offline content
    /// if available
    ///
    /// @url: string - base url of ebook
    ///
    func loadBook(url: String) {
        eval("Viewer.loadBook(\"\(url)\")")
    }

    ///
    /// Get current text font scale size
    ///
    /// @scale: double - 1.0 is original size
    ///
    func getFontScale() -> Double? {
        if let result = eval("Viewer.getFontScale()") {
            return Double(result)
        }
        return nil
    }

    ///
    /// Set text font scale size
    ///
    /// @scale: double - 1.0 is original size
    ///
    func setFontScale(scale: Double) {
        eval("Viewer.setFontScale(\(scale))")
    }

    ///
    /// Get page background color
    ///
    /// @[r, g, b] - page background color
    ///
    func getBackgroundColor() -> UIColor? {
        if let result = eval("JSON.stringify(Viewer.getBackgroundColor())") {
            do {
                let json = try JsonArray(string: result)
                let r = try json.getInt(0)
                let g = try json.getInt(1)
                let b = try json.getInt(2)
                return UIColor(r: r, g: g, b: b)
            } catch let error {
                NSLog("ViewerBridge: getBackgroundColor() error=%@", error as NSError)
            }
        }
        return nil
    }

    ///
    /// Set page background color
    ///
    /// @[r, g, b] - page background color
    ///
    func setBackgroundColor(color: UIColor) {
        let (r, g, b) = color.rgb
        eval("Viewer.setBackgroundColor([\(r), \(g), \(b)])")
    }

    ///
    /// Get an array of available page layout modes for this book
    ///
    /// @mode: string - either "single", "side_by_side" or "continuous"
    ///
    func getAvailableLayoutModes() -> [LayoutMode]? {
        if let result = eval("JSON.stringify(Viewer.getAvailableLayoutModes())") {
            var modes = [LayoutMode]()
            do {
                let json = try JsonArray(string: result)
                for i in 0 ..< json.count {
                    let value = try json.getString(i)
                    if let mode = LayoutMode(rawValue: value) {
                        modes.append(mode)
                    } else {
                        NSLog("ViewerBridge: getAvailableLayoutModes() unknown layout mode=%@", value)
                    }
                }
                return modes.isEmpty ? nil : modes
            } catch let error {
                NSLog("ViewerBridge: getAvailableLayoutModes() error=%@", error as NSError)
            }
        }
        return nil
    }

    ///
    /// Get current page layout mode
    ///
    /// @mode: string - either "single", "side_by_side" or "continuous"
    ///
    func getLayoutMode() -> LayoutMode? {
        if let result = eval("Viewer.getLayoutMode()") {
            if let mode = LayoutMode(rawValue: result) {
                return mode
            } else {
                NSLog("ViewerBridge: getLayoutMode() unknown layout mode=%@", result)
            }
        }
        return nil
    }

    ///
    /// Set page layout mode
    ///
    /// @mode: string - either "single", "side_by_side" or "continuous"
    ///
    func setLayoutMode(mode: LayoutMode) {
        eval("Viewer.setLayoutMode(\"\(mode.rawValue)\")")
    }

    ///
    /// Get current position in the ebook
    ///
    /// @chapter: string - an opaque to represent current chapter
    /// @cfi: string - epub cfi
    /// @current_page: int - page number of current page
    /// @total_pages: int - total number of pages
    ///
    func getCurrentPosition() -> (chapter: String, cfi: String, current: Int, total: Int)? {
        if let result = eval("JSON.stringify(Viewer.getCurrentPosition())") {
            do {
                let json = try JsonArray(string: result)
                let chapter = try json.getString(0)
                let cfi = try json.getString(1)
                let current = try json.getInt(2)
                let total = try json.getInt(3)
                return (chapter: chapter, cfi: cfi, current: current, total: total)
            } catch let error {
                NSLog("ViewerBridge: getCurrentPosition() error=%@", error as NSError)
            }
        }
        return nil
    }

    ///
    /// Goto the given link in this ebook
    ///
    /// @link: string - target file link (relative to base url)
    ///
    func gotoLink(link: String) {
        eval("Viewer.gotoLink(\"\(link)\")")
    }

    ///
    /// Goto the given position in this ebook
    ///
    /// @cfi: string - epub cfi
    ///
    func gotoPosition(cfi: String) {
        eval("Viewer.gotoPosition(\"\(cfi)\")")
    }

    ///
    /// Toggle the bookmark in the current page.
    ///
    /// If a valid [r, g, b] is specified, viewer should call App.onAddBookmark
    /// or App.onUpdateBookmark in response.
    ///
    /// If null is specified, viewer should call App.onRemoveBookmark in response,
    /// or do nothing if there is currently no bookmark
    ///
    /// @color: [r, g, b] or null
    ///     [r, g, b] - the bookmark indicator color,
    ///     null - to remove current bookmark
    ///
    func toggleBookmark(color: UIColor?) {
        if let color = color {
            let (r, g, b) = color.rgb
            eval("Viewer.toggleBookmark([\(r), \(g), \(b)])")
        } else {
            eval("Viewer.toggleBookmark(null)")
        }
    }

    ///
    /// Search text and mark the found text, the search is case-insensitive
    /// viewer should call App.onSearchFound in response
    ///
    /// @keyword: string or null - the keyword to be found,
    ///     or null to cancel search mode
    ///
    func searchText(keyword: String?) {
        if var keyword = keyword {
            keyword = keyword.stringByReplacingOccurrencesOfString("\"", withString: "\\\"")
            eval("Viewer.searchText(\"\(keyword)\")")
        } else {
            eval("Viewer.searchText(null)")
        }
    }

    ///
    /// Notify App current title is changed
    ///
    /// @title: string - title to be shown on toolbar
    ///
    private func onChangeTitle(title: String) throws {
        self.scene.barTitle.text = title
    }

    ///
    /// Notify App current table of content is changed
    ///
    /// @[toc_entry, ...]: array - an json array to the TOC entry
    ///
    private func onChangeTOC(toc: JsonArray) throws {
        self.scene.tableOfContent = toc
    }

    ///
    /// Notify App current view frame is changed
    /// This is needed for PDF annotation
    /// Content offset is the relative position (after scaling) to the top-left corner.
    /// Content offset (x: -10, y: -20) will make top edge 20 pixels off-screen,
    /// left edge 10 pixels off-screen
    ///
    /// @offset_x: number - content offset x
    /// @offset_y: number - content offset y
    /// @scale: number - scale of content view, 1.0 is original size
    ///
    private func onChangeView(offset_x: Double, _ offset_y: Double, scale: Double) throws {
        // do view synchronizing
    }

    ///
    /// Notify App current page is changed to different page
    ///
    /// @chapter: string - an opaque to represent current chapter
    /// @cfi: string - epub cfi
    /// @percentage: 0..100 - to represent reading progress
    ///
    private func onChangePage(chapter: String, cfi: String, percentage: Int) throws {
        debug("onChangePage",
            "chapter=\(chapter)\n"
            + "cfi=\(cfi)\n"
            + "percentage=\(percentage)",
            alert: false)
    }

    ///
    /// Notify App user action for tracking
    ///
    /// @action: string - tracking "action" as defined in doc
    /// @cfi: string - tracking "cfi" as defined in doc, may be empty for some action
    ///
    private func onTrackAction(action: String, cfi: String) throws {
        debug("onTrackAction",
            "action=\(action)\n"
            + "cfi=\(cfi)",
            alert: false)
    }

    ///
    /// Notify App to show or hide toolbar
    ///
    /// @visible: bool - set visibility of tool bar
    ///
    private func onToggleToolbar(visible: Bool) throws {
        self.scene.bar.hidden = !visible
    }

    // dummy database
    private var highlights = [String: (String, JsonObject)]()

    ///
    /// Request App to load highlights for the chapter, App will call callback in response
    /// The callback will receive an array of json object to represent highlights
    ///
    ///     function callback([highlight, ...])
    ///
    /// @chapter: string - an opaque to represent current chapter
    /// @callback: string - name of callback function (can be object member function)
    ///     do not pass function itself, only name (as string) is needed;
    ///     and the function must be accessable from global space
    ///
    private func onRequestHighlights(chapter: String, callback: String) throws {
        var json = JsonArray()
        for (_, (highlight_chapter, highlight)) in self.highlights {
            if highlight_chapter == chapter {
                json.append(highlight)
            }
        }

        eval("\(callback)(\(try json.toString()))")
    }

    ///
    /// Notify App the given highlight need to be added, App will call callback in response
    /// The callback will receive the UUID of new highlight just created
    ///
    ///     function callback(uuid)
    ///
    /// @chapter: string - an opaque to represent current chapter
    /// @highlight - an json object to represent highlight, uuid is absent in this case
    /// @callback: string - name of callback function (can be object member function);
    ///     do not pass function itself, only name (as string) is needed;
    ///     and the function must be accessable from global space
    ///
    private func onAddHighlight(chapter: String, highlight: JsonObject, callback: String) throws {
        var highlight = highlight
        let uuid = NSUUID().UUIDString
        highlight["uuid"] = uuid
        self.highlights[uuid] = (chapter, highlight)
        
        eval("\(callback)(\"\(uuid)\")")
    }

    ///
    /// Notify App the given highlight need to be updated
    ///
    /// @highlight - an json object to represent highlight
    ///
    private func onUpdateHighlight(highlight: JsonObject) throws {
        let uuid = try highlight.getString("uuid")
        if let (chapter, _) = self.highlights[uuid] {
            self.highlights[uuid] = (chapter, highlight)
        }
    }

    ///
    /// Notify App the given highlight need to be deleted
    ///
    /// @uuid - uuid of the highlight
    ///
    private func onRemoveHighlight(uuid: String) throws {
        self.highlights.removeValueForKey(uuid)
    }

    ///
    /// Notify App the given highlight need to be shared, App will popup sharing dialog
    ///
    /// @uuid - uuid of the highlight
    ///
    private func onShareHighlight(uuid: String) throws {
        debug("onShareHighlight",
                "uuid=|\(uuid)|")
    }

    ///
    /// Notify App the given highlight need to be annotated, App will popup edit window
    ///
    /// @uuid - uuid of the highlight
    ///
    private func onAnnotateHighlight(uuid: String) throws {
        debug("onAnnotateHighlight",
                "uuid=|\(uuid)|")
    }

    // dummy database
    private var bookmarks = [String: (String, JsonObject)]()

    ///
    /// Request App to load bookmark for the chapter, App will call callback in response
    /// The callback will receive an array of json object to represent bookmarks
    ///
    ///     function callback([bookmark, ...])
    ///
    /// @chapter: string - an opaque to represent current chapter
    /// @callback: string - name of callback function (can be object member function);
    ///     do not pass function itself, only name (as string) is needed;
    ///     and the function must be accessable from global space
    ///
    private func onRequestBookmarks(chapter: String, callback: String) throws {
        var json = JsonArray()
        for (_, (bookmark_chapter, bookmark)) in self.bookmarks {
            if bookmark_chapter == chapter {
                json.append(bookmark)
            }
        }

        eval("\(callback)(\(try json.toString()))")
    }

    ///
    /// Notify App the given bookmark need to be added, App will call callback in response
    /// The callback will receive the UUID of new bookmark just created
    ///
    ///     function callback(uuid)
    ///
    /// @chapter: string - an opaque to represent current chapter
    /// @bookmark - an json object to represent bookmark, uuid is absent in this case
    /// @callback: string - name of callback function (can be object member function);
    ///     do not pass function itself, only name (as string) is needed;
    ///     and the function must be accessable from global space
    ///
    private func onAddBookmark(chapter: String, bookmark: JsonObject, callback: String) throws {
        var bookmark = bookmark
        let uuid = NSUUID().UUIDString
        bookmark["uuid"] = uuid
        self.bookmarks[uuid] = (chapter, bookmark)
        
        eval("\(callback)(\"\(uuid)\")")
    }

    ///
    /// Notify App the given bookmark need to be updated
    ///
    /// @bookmark - an json object to represent bookmark
    ///
    private func onUpdateBookmark(bookmark: JsonObject) throws {
        let uuid = try bookmark.getString("uuid")
        if let (chapter, _) = self.bookmarks[uuid] {
            self.bookmarks[uuid] = (chapter, bookmark)
        }
    }

    ///
    /// Notify App the given bookmark need to be deleted
    ///
    /// @uuid - uuid of the bookmark
    ///
    private func onRemoveBookmark(uuid: String) throws {
        self.bookmarks.removeValueForKey(uuid)
    }

    ///
    /// Notify App the search result is found
    /// View can call this multiple times until App call Viewer.searchText(null)
    ///
    /// @keyword - the search keyword
    /// @result - an json object to represent search result
    ///
    private func onSearchResult(keyword: String, results: JsonArray) throws {
        debug("onSearchResult",
                "keyword=|\(keyword)|\n"
                + "results=|\(try results.toString())|")
    }
    
    /// for debugging only
    private func debug(title: String, _ message: String, alert: Bool = true) {
        if alert {
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
            alertController.addAction(UIAlertAction(title: "SEE!", style: .Cancel, handler: nil))
            self.scene.presentViewController(alertController, animated: true, completion: nil)
        }
        
        NSLog("Callback %@: %@", title, message)
    }
}
