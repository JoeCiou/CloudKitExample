//
//  Note.swift
//  CloudKitExample
//
//  Created by Joe Ciou on 2019/3/27.
//  Copyright © 2019 Joe Ciou. All rights reserved.
//

import UIKit
import CloudKit

class Note {
    
    let title: String
    var content: String?
    var recordID: CKRecord.ID?
    
    init(title: String) {
        self.title = title
    }
}
