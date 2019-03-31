//
//  Note.swift
//  CloudKitExample
//
//  Created by Joe Ciou on 2019/3/27.
//  Copyright © 2019 Joe Ciou. All rights reserved.
//

import UIKit
import CloudKit

class Note: NSObject {
    
    var title: String
    var content: String?
    var recordID: CKRecord.ID?
    
    init(title: String) {
        self.title = title
        super.init()
    }
    
    init(record: CKRecord) {
        self.title = record.value(forKey: "title") as! String
        self.content = record.value(forKey: "content") as? String
        self.recordID = record.recordID
        super.init()
    }
    
    var record: CKRecord {
        let recordID = self.recordID ?? CKRecord.ID(zoneID: notesRecordZone.zoneID)
        let record = CKRecord(recordType: "Note", recordID: recordID)
        record.setValue(title, forKey: "title")
        record.setValue(content, forKey: "content")
        
        return record
    }
}
