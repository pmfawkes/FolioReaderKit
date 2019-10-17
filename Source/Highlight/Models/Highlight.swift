//
//  Highlight.swift
//  FolioReaderKit
//
//  Created by David Pei on 10/16/19.
//

import Foundation

final class Highlight {
    var id: Int = 0
    var bookId: String = ""
    var content: String = ""
    var contentPost: String = ""
    var contentPre: String = ""
    var date: Date = Date()
    var page: Int = 0
    var type: Int = 0
    var startOffset: Int = -1
    var endOffset: Int = -1
    var noteForHighlight: String?
    
    init(id: Int = 0, bookId: String = "", content: String = "", contentPost: String = "", contentPre: String = "", date: Date = Date(), page: Int = 0, type: Int = 0, startOffset: Int = -1, endOffset: Int = -1, noteForHighlight: String? = nil) {
        self.id = id
        self.bookId = bookId
        self.content = content
        self.contentPost = contentPost
        self.contentPre = contentPre
        self.date = date
        self.page = page
        self.type = type
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.noteForHighlight = noteForHighlight
    }
}

extension Highlight: SQLTable {
    static var createStatement: String {
        return """
        CREATE TABLE "highlights" (
        "id" INTEGER PRIMARY KEY NOT NULL,
        "bookId" TEXT
        "content" TEXT
        "contentPost" TEXT
        "contentPre" TEXT
        "date" REAL
        "page" INTEGER
        "type" INTEGER
        "startOffset" INTEGER
        "endOffset" INTEGER
        "noteForHighlight" TEXT
        );
        """
    }
}

//extension Results {
//    func toArray<T>(_ ofType: T.Type) -> [T] {
//        return compactMap { $0 as? T }
//    }
//}
