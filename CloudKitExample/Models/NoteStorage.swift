//
//  NoteStorage.swift
//  CloudKitExample
//
//  Created by Joe Ciou on 2019/3/31.
//  Copyright © 2019 Joe Ciou. All rights reserved.
//

import UIKit
import CloudKit

class NoteStorage: NSObject {

    static let NoteChangedNotificationName = NSNotification.Name("NoteStorageNoteChanged")
    
    private(set) var notes: [Note] = []
    private let cloudSynchronizer = NoteCloudSynchronizer()
    
    override init() {
        super.init()
        
        cloudSynchronizer.delegate = self
        // Re-fetch cloud data because this app haven't local storage
        cloudSynchronizer.serverChangeToken = nil
        cloudSynchronizer.fetchNotes()
    }
    
    func createNote(title: String) {
        let note = Note(title: title)
        notes.append(note)
        cloudSynchronizer.syncToCloud(note: note)
        NotificationCenter.default.post(name: NoteStorage.NoteChangedNotificationName, object: nil)
    }
    
    func updateNote(_ note: Note, title: String? = nil, content: String? = nil) {
        if let title = title { note.title = title }
        if let content = content { note.content = content }
        cloudSynchronizer.syncToCloud(note: note)
        NotificationCenter.default.post(name: NoteStorage.NoteChangedNotificationName, object: nil)
    }
    
    func fetchNotes(callback: (() -> Void)?) {
        cloudSynchronizer.fetchNotes(callback)
    }
}

extension NoteStorage: NoteCloudSynchronizerDelegate {
    func noteColudSynchronizer(_ synchronizer: NoteCloudSynchronizer, didSaveNote record: CKRecord) {
        
    }
    
    func noteColudSynchronizer(_ synchronizer: NoteCloudSynchronizer, didUpdateNote record: CKRecord) {
        
    }
    
    func noteCloudSynchronizer(_ synchronizer: NoteCloudSynchronizer, didFetchNoteChange record: CKRecord) {
        if let note = notes.first(where: { $0.recordID == record.recordID }) {
            // Update note
            let updatedNote = Note(record: record)
            note.title = updatedNote.title
            note.content = updatedNote.content
        } else {
            // Add note
            let savedNote = Note(record: record)
            notes.append(savedNote)
        }
    }
    
    func noteCloudSynchronizer(_ synchronizer: NoteCloudSynchronizer, didFetchDelete recordID: CKRecord.ID) {
        if let index = notes.firstIndex(where: { $0.recordID == recordID }) {
            notes.remove(at: index)
        }
    }
    
    func noteCloudSynchronizerDidCompleteFetch(_ synchronizer: NoteCloudSynchronizer) {
        NotificationCenter.default.post(name: NoteStorage.NoteChangedNotificationName, object: nil)
    }
}
