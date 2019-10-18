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
            print(dbHandler?.errorMessage)
        }
    }
    
 
    func addHighlight(highlight: Highlight) {
        do {
            try dbHandler?.addHighlight(highlight)
        } catch {
            print("can't insert highlight")
        }
    }
    
    func updateHighlight(id: String, type: HighlightStyle) {
        dbHandler?.updateHighlight(id: id, type: type.rawValue)
    }
    
    func updateHighlight(id: String, note: String) {
        dbHandler?.updateHighLight(id: id, note: note)
    }
    
    func removeHighlight(byId id: String) {
        dbHandler?.removeHighlight(id: id)
    }
    
    func getHighlight(byId id: String) -> Highlight? {
        return dbHandler?.getHighlight(id: id)
    }
    
    func getAllHighlight(byBookId id: String, page: Int?) -> [Highlight] {
        return dbHandler?.getAllHighlights(byBookId: id, page: page) ?? []
    }
    
    func getAllHighlights() -> [Highlight] {
        return dbHandler?.getAllHighlights() ?? []
    }
}
