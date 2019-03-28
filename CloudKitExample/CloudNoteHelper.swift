//
//  CloudKitHelper.swift
//  CloudKitExample
//
//  Created by Joe Ciou on 2019/3/27.
//  Copyright © 2019 Joe Ciou. All rights reserved.
//

import UIKit
import CloudKit

class CloudNoteHelper {
    
    static let shared = CloudNoteHelper()

    let container = CKContainer.default()
    var privateDB: CKDatabase {
        return container.privateCloudDatabase
    }
    let notesRecordZone = CKRecordZone(zoneName: "NotesRecordZone")
    var subscrptionIsLocallyCached = false
    
    init() {
        if !subscrptionIsLocallyCached {
            let subscription = CKDatabaseSubscription(subscriptionID: "NoteInfo")
            
            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true
            subscription.notificationInfo = notificationInfo
            
            let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: [])
            operation.modifySubscriptionsCompletionBlock = { subscriptions, subscriptionIds, error in
                guard error == nil else {
                    print("Subscription operation error: \(error!.localizedDescription)")
                    return
                }
                
                self.subscrptionIsLocallyCached = true
            }
            operation.qualityOfService = .utility
            privateDB.add(operation)
        }
        
        privateDB.save(notesRecordZone) { (zone, error) in
            guard let zone = zone, error == nil else {
                print("Zone creation error: \(error!.localizedDescription)")
                return
            }
            print("Zone created: \(zone)")
        }
    }
    
    func accountStatus(completionHandler: @escaping (CKAccountStatus, Error?) -> Void) {
        container.accountStatus(completionHandler: completionHandler)
    }
    
    private class func errorHandler(_ error: CKError, taskName: String, retryBlock: @escaping () -> Void) {
        switch error.code {
        case .internalError, .serverRejectedRequest, .invalidArguments, .permissionFailure:
            print("\(taskName) fatal error: \(error.localizedDescription)")
        case .zoneBusy, .serviceUnavailable, .requestRateLimited:
            print("\(taskName) retryable error: \(error.localizedDescription)")
            DispatchQueue.main.asyncAfter(deadline: .now() + error.retryAfterSeconds!, execute: {
                retryBlock()
            })
        case .networkUnavailable, .networkFailure:
            print("\(taskName) network error: \(error.localizedDescription)")
        default:
            print("\(taskName) other error: \(error.localizedDescription)")
        }
    }
    
    private func updateNote(_ note: Note) {
        privateDB.fetch(withRecordID: note.recordID!) { [weak self] (record, error) in
            guard let record = record, error == nil else {
                let error = error as! CKError
                CloudNoteHelper.errorHandler(error, taskName: "Record fetch", retryBlock: {
                    self?.updateNote(note)
                })
                return
            }
            
            record.setValue(note.title, forKey: "title")
            record.setValue(note.content, forKey: "content")
            
            let modifyOperation = CKModifyRecordsOperation(recordsToSave: [record])
            modifyOperation.savePolicy = .allKeys
            modifyOperation.qualityOfService = .userInitiated
            modifyOperation.modifyRecordsCompletionBlock = { (_, _, error) in
                guard error == nil else {
                    let error = error as! CKError
                    CloudNoteHelper.errorHandler(error, taskName: "Record modification", retryBlock: {
                        self?.updateNote(note)
                    })
                    
                    return
                }
                print("Record modified")
            }
            self?.privateDB.add(modifyOperation)
        }
    }
    
    private func saveNote(_ note: Note) {
        let recordID = CKRecord.ID(zoneID: notesRecordZone.zoneID)
        let noteRecord = CKRecord(recordType: "Note", recordID: recordID)
        noteRecord.setValue(note.title, forKey: "title")
        noteRecord.setValue(note.content, forKey: "content")
        
        privateDB.save(noteRecord) { [weak self] (record, error) in
            guard let record = record, error == nil else {
                let error = error as! CKError
                CloudNoteHelper.errorHandler(error, taskName: "Record save", retryBlock: {
                    self?.saveNote(note)
                })
                return
            }
            print("Record saved: \(record)")
            
            note.recordID = record.recordID
        }
    }
    
    func syncToCloud(note: Note) {
        if let _ = note.recordID {
            updateNote(note)
        } else {
            saveNote(note)
        }
    }
    
    func fetchNoteInfo(_ callback: @escaping () -> Void) {
        // CKFetchRecordZoneChangesOperation
        let changesOperation = CKFetchDatabaseChangesOperation(previousServerChangeToken: nil)
        changesOperation.fetchAllChanges = true
        
        changesOperation.recordZoneWithIDChangedBlock = { recordZoneID in
            print("recordZoneWithIDChangedBlock: \(recordZoneID)")
        }
        changesOperation.recordZoneWithIDWasDeletedBlock = { recordZoneID in
            print("recordZoneWithIDWasDeletedBlock: \(recordZoneID)")
        }
        changesOperation.recordZoneWithIDWasPurgedBlock = { recordZoneID in
            print("recordZoneWithIDWasPurgedBlock: \(recordZoneID)")
        }
        changesOperation.changeTokenUpdatedBlock = { token in
            UserDefaults.standard.set(token, forKey: "server_change_token")
        }
        changesOperation.fetchDatabaseChangesCompletionBlock = { (token, more, error) in
            guard error == nil else {
                print("Fetch note info operation error: \(error!.localizedDescription)")
                return
            }
            UserDefaults.standard.set(token, forKey: "server_change_token")
            
            if more {
                print("more")
            } else {
                callback()
            }
        }
    }
}
