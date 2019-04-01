//
//  NoteCloudSynchronizer.swift
//  CloudKitExample
//
//  Created by Joe Ciou on 2019/3/27.
//  Copyright © 2019 Joe Ciou. All rights reserved.
//

import UIKit
import CloudKit

let notesRecordZone = CKRecordZone(zoneName: "NotesRecordZone")

private struct UserDefaultsKey {
    static let NotesServerChangeToken = "NotesServerChangeToken"
    static let NotesSubscriptionIsLocallyCached = "NotesSubscriptionIsLocallyCached"
}

@objc protocol NoteCloudSynchronizerDelegate {
    @objc optional func noteColudSynchronizer(_ synchronizer: NoteCloudSynchronizer, didSaveNote record: CKRecord)
    @objc optional func noteColudSynchronizer(_ synchronizer: NoteCloudSynchronizer, didUpdateNote record: CKRecord)
    @objc optional func noteCloudSynchronizer(_ synchronizer: NoteCloudSynchronizer, didFetchNoteChange record: CKRecord)
    @objc optional func noteCloudSynchronizer(_ synchronizer: NoteCloudSynchronizer, didFetchDelete recordID: CKRecord.ID)
    @objc optional func noteCloudSynchronizerDidCompleteFetch(_ synchronizer: NoteCloudSynchronizer)
    @objc optional func noteCloudSynchronizer(_ synchronizer: NoteCloudSynchronizer, didDeleteNote recordID: CKRecord.ID)
}

class NoteCloudSynchronizer: NSObject {
    
    weak var delegate: NoteCloudSynchronizerDelegate?

    private let container = CKContainer.default()
    private var privateDB: CKDatabase {
        return container.privateCloudDatabase
    }
    private var subscrptionIsLocallyCached: Bool {
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.NotesSubscriptionIsLocallyCached)
        }
        get {
            return UserDefaults.standard.bool(forKey: UserDefaultsKey.NotesSubscriptionIsLocallyCached)
        }
    }
    var serverChangeToken: CKServerChangeToken? {
        set {
            let data: Data? = (newValue != nil) ? try! NSKeyedArchiver.archivedData(withRootObject: newValue!, requiringSecureCoding: true): nil
            UserDefaults.standard.set(data, forKey: UserDefaultsKey.NotesServerChangeToken)
        }
        get {
            guard let data = UserDefaults.standard.value(forKey: UserDefaultsKey.NotesServerChangeToken) as? Data else {
                return nil
            }
            return try! NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as! CKServerChangeToken
        }
    }
    
    class func accountStatus(completionHandler: @escaping (CKAccountStatus, Error?) -> Void) {
        CKContainer.default().accountStatus(completionHandler: completionHandler)
    }
    
    override init() {
        super.init()
        checkScbscription()
        checkCustomZone()
    }
    
    private func checkScbscription() {
        if !subscrptionIsLocallyCached {
            let subscription = CKRecordZoneSubscription(zoneID: notesRecordZone.zoneID)
            
            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true
            subscription.notificationInfo = notificationInfo
            
            let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: [])
            operation.modifySubscriptionsCompletionBlock = { [weak self] subscriptions, subscriptionIDs, error in
                guard error == nil else {
                    let error = error as! CKError
                    NoteCloudSynchronizer.errorHandler(error, taskName: "Subscription creation", retryBlock: {
                        self?.checkScbscription()
                    })
                    return
                }
                
                self?.subscrptionIsLocallyCached = true
            }
            operation.qualityOfService = .utility
            privateDB.add(operation)
        }
    }
    
    private func checkCustomZone() {
        privateDB.fetch(withRecordZoneID: notesRecordZone.zoneID) { [weak self] (_, error) in
            guard let error = error as? CKError else {
                print("Zone created already")
                return
            }
            if error.code == .zoneNotFound {
                self?.privateDB.save(notesRecordZone) { (zone, error) in
                    guard let zone = zone, error == nil else {
                        let error = error as! CKError
                        NoteCloudSynchronizer.errorHandler(error, taskName: "Zone creation", retryBlock: {
                            self?.checkCustomZone()
                        })
                        return
                    }
                    print("Zone created: \(zone)")
                }
            } else {
                NoteCloudSynchronizer.errorHandler(error, taskName: "Zone fetch", retryBlock: {
                    self?.checkCustomZone()
                })
            }
        }
        
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
        let modifyOperation = CKModifyRecordsOperation(recordsToSave: [note.record])
        modifyOperation.savePolicy = .allKeys
        modifyOperation.qualityOfService = .userInitiated
        modifyOperation.modifyRecordsCompletionBlock = { [weak self] (records, _, error) in
            guard let record = records?.first, error == nil else {
                let error = error as! CKError
                NoteCloudSynchronizer.errorHandler(error, taskName: "Record modification", retryBlock: {
                    self?.updateNote(note)
                })
                
                return
            }
            print("Record modified")
            self?.delegate?.noteColudSynchronizer?(self!, didUpdateNote: record)
        }
        privateDB.add(modifyOperation)
    }
    
    private func saveNote(_ note: Note) {
        privateDB.save(note.record) { [weak self] (record, error) in
            guard let record = record, error == nil else {
                let error = error as! CKError
                NoteCloudSynchronizer.errorHandler(error, taskName: "Record save", retryBlock: {
                    self?.saveNote(note)
                })
                return
            }
            print("Record saved: \(record)")
            note.recordID = record.recordID
            self?.delegate?.noteColudSynchronizer?(self!, didSaveNote: record)
        }
    }
    
    func syncToCloud(note: Note) {
        if let _ = note.recordID {
            updateNote(note)
        } else {
            saveNote(note)
        }
    }
    
    func fetchNotes(_ callback: (() -> Void)? = nil) {
        let zoneConfiguration = CKFetchRecordZoneChangesOperation.ZoneConfiguration(previousServerChangeToken: serverChangeToken)
        let changesOperation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [notesRecordZone.zoneID],
                                                                 configurationsByRecordZoneID: [notesRecordZone.zoneID: zoneConfiguration])
        changesOperation.recordChangedBlock = { [weak self] record in
            print("recordChangedBlock - record: \(record)")
            self?.delegate?.noteCloudSynchronizer?(self!, didFetchNoteChange: record)
        }
        changesOperation.recordWithIDWasDeletedBlock = { [weak self] recordID, recordType in
            print("recordWithIDWasDeletedBlock - recordID: \(recordID), recordType: \(recordType)")
            self?.delegate?.noteCloudSynchronizer?(self!, didFetchDelete: recordID)
        }
        changesOperation.recordZoneChangeTokensUpdatedBlock = { [weak self] recordZoneID, token, data in
            print("recordZoneChangeTokensUpdatedBlock - recordZoneID: \(recordZoneID), token: \(token), data: \(data)")
            guard let token = token else {
                print("token is nil")
                return
            }
            
            self?.serverChangeToken = token
        }
        changesOperation.recordZoneFetchCompletionBlock = { [weak self] recordZoneID, token, data, more, error in
            print("recordZoneFetchCompletionBlock - recorZoneID: \(recordZoneID), token: \(token), data: \(data), more: \(more)")
            guard error == nil else {
                let error = error as! CKError
                NoteCloudSynchronizer.errorHandler(error, taskName: "Record zone fetch changes", retryBlock: {
                    self?.fetchNotes(callback)
                })
                return
            }
            guard let token = token else {
                print("token is nil")
                return
            }
            
            self?.serverChangeToken = token
            self?.delegate?.noteCloudSynchronizerDidCompleteFetch?(self!)
        }
        changesOperation.fetchRecordZoneChangesCompletionBlock = { [weak self] error in
            print("fetchRecordZoneChangesCompletionBlock")
            guard error == nil else {
                let error = error as! CKError
                NoteCloudSynchronizer.errorHandler(error, taskName: "Record zone fetch changes", retryBlock: {
                    self?.fetchNotes(callback)
                })
                return
            }
            
            callback?()
        }
        changesOperation.qualityOfService = .userInitiated
        privateDB.add(changesOperation)
    }
    
    func deleteNote(_ note: Note) {
        guard let recordID = note.recordID else {
            return
        }
        privateDB.delete(withRecordID: recordID) { [weak self] deletedRecordID, error in
            guard let deletedRecordID = deletedRecordID, error == nil else {
                let error = error as! CKError
                NoteCloudSynchronizer.errorHandler(error, taskName: "Record delete", retryBlock: {
                    self?.deleteNote(note)
                })
                return
            }
            
            self?.delegate?.noteCloudSynchronizer?(self!, didDeleteNote: deletedRecordID)
        }
    }
}
