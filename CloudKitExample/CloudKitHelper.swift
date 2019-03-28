//
//  CloudKitHelper.swift
//  CloudKitExample
//
//  Created by Joe Ciou on 2019/3/27.
//  Copyright © 2019 Joe Ciou. All rights reserved.
//

import UIKit
import CloudKit

class CloudKitHelper {
    
    static let shared = CloudKitHelper()

    let privateDB = CKContainer.default().privateCloudDatabase
    let recordZone = CKRecordZone(zoneName: "NotesZone")
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
    }
    
    func fetchNoteInfo(_ callback: @escaping () -> Void) {
        let changesOperation = CKFetchDatabaseChangesOperation(previousServerChangeToken: nil)
//        changesOperation.fetchAllChanges = true
        
        changesOperation.recordZoneWithIDChangedBlock = { recordZoneID in
            
        }
        changesOperation.recordZoneWithIDWasDeletedBlock = { recordZoneID in
            
        }
        changesOperation.recordZoneWithIDChangedBlock = { recordZoneID in
            
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
