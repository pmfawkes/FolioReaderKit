//
//  SQLiteDatabase.swift
//  FolioReaderKit
//
//  Created by David Pei on 10/16/19.
//

import Foundation
import SQLite3

enum SQLiteError: Error {
    case OpenDatabase(message: String)
    case Prepare(message: String)
    case Step(message: String)
    case Bind(message: String)
}

protocol SQLTable {
    static var createStatement: String { get }
}

class SQLiteDatabase {
    private let dbPointer: OpaquePointer?
    var currentSchemaVersion = 1
    
    var errorMessage: String {
        if let errorPointer = sqlite3_errmsg(dbPointer) {
            let errorMessage = String(cString: errorPointer)
            return errorMessage
        } else {
            return "No error message provided from sqlite."
        }
    }
        
    private init(dbPointer: OpaquePointer?) {
        self.dbPointer = dbPointer
        
        guard let userVersion = try? queryUserVersion(), userVersion != currentSchemaVersion else { return }
        migrateToSchema(fromVersion: userVersion, toVersion: currentSchemaVersion)
        try? setUserVersion()
    }
    
    deinit {
        sqlite3_close(dbPointer)
    }
    
    static func open(path: String) throws -> SQLiteDatabase {
        var db: OpaquePointer? = nil
        
        guard sqlite3_open(path, &db) != SQLITE_OK else {
            return SQLiteDatabase(dbPointer: db)
        }
        
        defer {
            if db != nil {
                sqlite3_close(db)
            }
        }
        
        if let errorPointer = sqlite3_errmsg(db) {
            let message = String.init(cString: errorPointer)
            throw SQLiteError.OpenDatabase(message: message)
        } else {
            throw SQLiteError.OpenDatabase(message: "No error message provided from sqlite.")
        }
    }
}

extension SQLiteDatabase {
    func queryUserVersion() throws -> Int? {
        let querySQL = "PRAGMA user_version;"
        let queryStatement = try prepareStatement(sql: querySQL)
        defer {
            sqlite3_finalize(queryStatement)
        }
        guard sqlite3_step(queryStatement) == SQLITE_ROW else {
            return nil
        }
        let userVersion = Int(sqlite3_column_int(queryStatement, 0))
        return userVersion
    }
    
    func setUserVersion() throws {
        let setSQL = "PRAGMA user_version=\(currentSchemaVersion);"
        let setStatement = try prepareStatement(sql: setSQL)
        defer {
            sqlite3_finalize(setStatement)
        }
        guard sqlite3_step(setStatement) == SQLITE_DONE else {
            throw SQLiteError.Step(message: errorMessage)
        }
        
        print("Successfully set schema version to \(currentSchemaVersion).")
    }
    
    func migrateToSchema(fromVersion: Int, toVersion: Int) {
        switch fromVersion + 1 {
        case 1:
            sqlite3_exec(dbPointer, "ALTER TABLE highlights ADD COLUMN startLocation TEXT;", nil, nil, nil);
            sqlite3_exec(dbPointer, "ALTER TABLE highlights ADD COLUMN endLocation INTEGER;", nil, nil, nil);
        default:
            break;
        }
    }
}

extension SQLiteDatabase {
    func prepareStatement(sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer? = nil
        guard sqlite3_prepare_v2(dbPointer, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.Prepare(message: errorMessage)
        }
        return statement
    }
    
    func createTable(table: SQLTable.Type) throws {
        let createTableStatement = try prepareStatement(sql: table.createStatement)
        defer {
            sqlite3_finalize(createTableStatement)
        }
        guard sqlite3_step(createTableStatement) == SQLITE_DONE else {
            throw SQLiteError.Step(message: errorMessage)
        }
        print("\(table) table created.")
    }
    
    func addHighlight(_ highlight: Highlight) throws {
        let insertSql = "INSERT INTO highlights (id, bookId, content, contentPost, contentPre, date, page, type, startOffset, endOffset, noteForHighlight, startLocation, endLocation) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?);"
        let insertStatement = try prepareStatement(sql: insertSql)
        defer {
            sqlite3_finalize(insertStatement)
        }
        
        guard sqlite3_bind_text(insertStatement, 1, (highlight.id as NSString).utf8String, -1, nil) == SQLITE_OK,
            sqlite3_bind_text(insertStatement, 2, (highlight.bookId as NSString).utf8String, -1, nil) == SQLITE_OK,
            sqlite3_bind_text(insertStatement, 3, (highlight.content as NSString).utf8String, -1, nil) == SQLITE_OK,
            sqlite3_bind_text(insertStatement, 4, (highlight.contentPost as NSString).utf8String, -1, nil) == SQLITE_OK,
            sqlite3_bind_text(insertStatement, 5, (highlight.contentPre as NSString).utf8String, -1, nil) == SQLITE_OK,
            sqlite3_bind_double(insertStatement, 6, highlight.date.timeIntervalSinceReferenceDate) == SQLITE_OK,
            sqlite3_bind_int(insertStatement, 7, Int32(highlight.page)) == SQLITE_OK,
            sqlite3_bind_int(insertStatement, 8, Int32(highlight.type)) == SQLITE_OK,
            sqlite3_bind_int(insertStatement, 9, Int32(highlight.startOffset)) == SQLITE_OK,
            sqlite3_bind_int(insertStatement, 10, Int32(highlight.endOffset)) == SQLITE_OK,
            sqlite3_bind_text(insertStatement, 11, ((highlight.noteForHighlight ?? "") as NSString).utf8String, -1, nil) == SQLITE_OK,
            sqlite3_bind_text(insertStatement, 12, ((highlight.startLocation) as NSString).utf8String, -1, nil) == SQLITE_OK,
            sqlite3_bind_text(insertStatement, 13, ((highlight.endLocation) as NSString).utf8String, -1, nil) == SQLITE_OK else {
                throw SQLiteError.Bind(message: errorMessage)
        }
        
        guard sqlite3_step(insertStatement) == SQLITE_DONE else {
            throw SQLiteError.Step(message: errorMessage)
        }
        
        print("Successfully inserted row.")
    }
    
    func updateHighlight(id: String, type: Int) throws {
        let updateSql = "UPDATE highlights SET type = ? WHERE id = ?;"
        guard let updateStatement = try prepareStatement(sql: updateSql) else { return }
        
        defer {
            sqlite3_finalize(updateStatement)
        }
        
        guard sqlite3_bind_int(updateStatement, 1, Int32(type)) == SQLITE_OK,
            sqlite3_bind_text(updateStatement, 2, (id as NSString).utf8String, -1, nil) == SQLITE_OK,
            sqlite3_step(updateStatement) == SQLITE_DONE else { return }
        print("update Highlight Succeeded")
    }
    
    func updateHighLight(id: String, note: String) throws {
        let updateSql = "UPDATE highlights SET noteForHighlight = ? WHERE id = ?;"
        guard let updateStatement = try prepareStatement(sql: updateSql) else { return }
        
        defer {
            sqlite3_finalize(updateStatement)
        }
        
        guard sqlite3_bind_text(updateStatement, 1, (note as NSString).utf8String, -1, nil) == SQLITE_OK,
            sqlite3_bind_text(updateStatement, 2, (id as NSString).utf8String, -1, nil) == SQLITE_OK,
            sqlite3_step(updateStatement) == SQLITE_DONE else { return }
        print("update Highlight Succeeded")
    }
    
    func getHighlight(id: String) throws -> Highlight? {
        let querySql = "SELECT * FROM highlights WHERE id = ? ;"
        guard let queryStatement = try prepareStatement(sql: querySql) else {
            return nil
        }
        
        defer {
            sqlite3_finalize(queryStatement)
        }
        guard sqlite3_bind_text(queryStatement, 1, (id as NSString).utf8String, -1, nil) == SQLITE_OK,
            sqlite3_step(queryStatement) == SQLITE_ROW else {
            return nil
        }
        
        return Highlight(
            id: String(cString: sqlite3_column_text(queryStatement, 0)),
            bookId: String(cString: sqlite3_column_text(queryStatement, 1)),
            content: String(cString: sqlite3_column_text(queryStatement, 2)),
            contentPost: String(cString: sqlite3_column_text(queryStatement, 3)),
            contentPre: String(cString: sqlite3_column_text(queryStatement, 4)),
            date: Date(timeIntervalSinceReferenceDate: sqlite3_column_double(queryStatement, 5)),
            page: Int(sqlite3_column_int(queryStatement, 6)),
            type: Int(sqlite3_column_int(queryStatement, 7)),
            startOffset: Int(sqlite3_column_int(queryStatement, 8)),
            endOffset: Int(sqlite3_column_int(queryStatement, 9)),
            noteForHighlight: String(cString: sqlite3_column_text(queryStatement, 10)),
            startLocation: String(cString: sqlite3_column_text(queryStatement, 11)),
            endLocation: String(cString: sqlite3_column_text(queryStatement, 12)))
    }
    
    func getAllHighlights(byBookId bookId: String, page: Int?) throws -> [Highlight]? {
        let querySql: String
        if let page = page {
            querySql = "SELECT * FROM highlights WHERE bookId = ? AND page = ?;"
        } else {
            querySql = "SELECT * FROM highlights WHERE bookId = ?;"
        }
        guard let queryStatement = try prepareStatement(sql: querySql) else {
            return nil
        }
        
        defer {
            sqlite3_finalize(queryStatement)
        }
        
        guard sqlite3_bind_text(queryStatement, 1, (bookId as NSString).utf8String, -1, nil) == SQLITE_OK else { return nil }
        if let pageId = page {
            guard sqlite3_bind_int(queryStatement, 2, Int32(pageId)) == SQLITE_OK else { return nil }
        }
        
        var result = [Highlight]()
        while sqlite3_step(queryStatement) == SQLITE_ROW {
            let highlight = Highlight(
                id: String(cString: sqlite3_column_text(queryStatement, 0)),
                bookId: String(cString: sqlite3_column_text(queryStatement, 1)),
                content: String(cString: sqlite3_column_text(queryStatement, 2)),
                contentPost: String(cString: sqlite3_column_text(queryStatement, 3)),
                contentPre: String(cString: sqlite3_column_text(queryStatement, 4)),
                date: Date(timeIntervalSinceReferenceDate: sqlite3_column_double(queryStatement, 5)),
                page: Int(sqlite3_column_int(queryStatement, 6)),
                type: Int(sqlite3_column_int(queryStatement, 7)),
                startOffset: Int(sqlite3_column_int(queryStatement, 8)),
                endOffset: Int(sqlite3_column_int(queryStatement, 9)),
                noteForHighlight: String(cString: sqlite3_column_text(queryStatement, 10)),
                startLocation: String(cString: sqlite3_column_text(queryStatement, 11)),
                endLocation: String(cString: sqlite3_column_text(queryStatement, 12)))
            result.append(highlight)
        }
        
        return result
    }
    
    func getAllHighlights() throws -> [Highlight]? {
        let querySql = "SELECT * FROM highlights;"
        guard let queryStatement = try prepareStatement(sql: querySql) else {
            return nil
        }
        
        defer {
            sqlite3_finalize(queryStatement)
        }
        
        var result = [Highlight]()
        while sqlite3_step(queryStatement) == SQLITE_ROW {
            let highlight = Highlight(
                id: String(cString: sqlite3_column_text(queryStatement, 0)),
                bookId: String(cString: sqlite3_column_text(queryStatement, 1)),
                content: String(cString: sqlite3_column_text(queryStatement, 2)),
                contentPost: String(cString: sqlite3_column_text(queryStatement, 3)),
                contentPre: String(cString: sqlite3_column_text(queryStatement, 4)),
                date: Date(timeIntervalSinceReferenceDate: sqlite3_column_double(queryStatement, 5)),
                page: Int(sqlite3_column_int(queryStatement, 6)),
                type: Int(sqlite3_column_int(queryStatement, 7)),
                startOffset: Int(sqlite3_column_int(queryStatement, 8)),
                endOffset: Int(sqlite3_column_int(queryStatement, 9)),
                noteForHighlight: String(cString: sqlite3_column_text(queryStatement, 10)),
                startLocation: String(cString: sqlite3_column_text(queryStatement, 11)),
                endLocation: String(cString: sqlite3_column_text(queryStatement, 12)))
            result.append(highlight)
        }
        
        return result
    }
    
    func removeHighlight(id: String) throws {
        let deleteSql = "DELETE FROM highlights WHERE id = ?"
        guard let deleteStatement = try prepareStatement(sql: deleteSql) else { return }
        
        defer {
            sqlite3_finalize(deleteStatement)
        }
        guard sqlite3_bind_text(deleteStatement, 1, (id as NSString).utf8String, -1, nil) == SQLITE_OK,
            sqlite3_step(deleteStatement) == SQLITE_DONE else { return }
        print("delete \(id) successfully")
    }
}
