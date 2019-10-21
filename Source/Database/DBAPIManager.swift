//
//  DBAPIManager.swift
//  FolioReaderKit
//
//  Created by David Pei on 10/16/19.
//

import Foundation

class DBAPIManager: NSObject {
    
    static let shared = DBAPIManager()
    
    private var dbHandler: SQLiteDatabase?
    private let databasePath: String = {
        guard let dbURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return "" }
        var isDir : ObjCBool = false
        let dbPath = dbURL.appendingPathComponent("db.sqlite").relativePath
        guard !FileManager.default.fileExists(atPath: dbURL.path, isDirectory: &isDir) else { return dbPath }
        do {
            try FileManager.default.createDirectory(at: dbURL, withIntermediateDirectories: false, attributes: nil)
        } catch (let error) {
            print(error)
        }
        return dbPath
    }()
    
    override init() {
        super.init()
        self.connectLocalDatabase()
        self.createTablesIfNeeded()
    }
    
    private func connectLocalDatabase() {
        do {
            dbHandler = try SQLiteDatabase.open(path: databasePath)
            print("Successfully opened connection to database.")
        } catch {
            print("Unable to open database. Verify that you created the directory described in the Getting Started section.")
        }
    }
    
    private func createTablesIfNeeded() {
        do {
            try dbHandler?.createTable(table: Highlight.self)
        } catch {
            print(dbHandler?.errorMessage ?? "")
        }
    }
    
    /// Save a Highlight with completion block
    ///
    /// - Parameters:
    ///   - completion: Completion block.
    func addHighlight(highlight: Highlight, completion: ((_ error: Error?) -> ())? = nil) {
        do {
            try dbHandler?.addHighlight(highlight)
        } catch {
            print("can't insert highlight")
        }
    }
    
    /// Update a Highlight by ID with type
    ///
    /// - Parameters:
    ///   - highlightId: The ID to be removed
    ///   - type: The `HighlightStyle`
    func updateHighlight(id: String, type: HighlightStyle) {
        do {
            try dbHandler?.updateHighlight(id: id, type: type.rawValue)
        } catch {
            print(dbHandler?.errorMessage ?? "")
        }
    }
    
    /// Update a Highlight by ID with note
    ///
    /// - Parameters:
    ///   - highlightId: The ID to be removed
    ///   - note: The note text string
    func updateHighlight(id: String, note: String) {
        do {
            try dbHandler?.updateHighLight(id: id, note: note)
        } catch {
            print(dbHandler?.errorMessage ?? "")
        }
    }
    
    /// Remove a Highlight by ID
    ///
    /// - Parameters:
    ///   - highlightId: The ID to be removed
    func removeHighlight(byId id: String) {
        do {
            try dbHandler?.removeHighlight(id: id)
        } catch {
            print(dbHandler?.errorMessage ?? "")
        }
    }
    
    /// Return a Highlight by ID
    ///
    /// - Parameter:
    ///   - highlightId: The ID to be removed
    ///   - page: Page number
    /// - Returns: Return a Highlight
    func getHighlight(byId id: String) -> Highlight? {
        do {
            return try dbHandler?.getHighlight(id: id)
        } catch {
            print(dbHandler?.errorMessage ?? "")
            return nil
        }
    }
    
    /// Return a list of Highlights with a given ID
    ///
    /// - Parameters:
    ///   - bookId: Book ID
    ///   - page: Page number
    /// - Returns: Return a list of Highlights
    func getAllHighlight(byBookId id: String, page: Int? = nil) -> [Highlight] {
        do {
            return try dbHandler?.getAllHighlights(byBookId: id, page: page) ?? []
        } catch {
            print(dbHandler?.errorMessage ?? "")
            return []
        }
        
    }
    
    /// Return all Highlights
    ///
    /// - Returns: Return all Highlights
    func getAllHighlights() -> [Highlight] {
        do {
            return try dbHandler?.getAllHighlights() ?? []
        } catch {
            print(dbHandler?.errorMessage ?? "")
            return []
        }
    }
}
