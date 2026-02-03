//
//  Untitled.swift
//  ActionPowerDevTest
//
//  Created by infit on 2/3/26.
//

import Foundation
import RealmSwift


enum PendingStatus: String, PersistableEnum {
    case none
    case create
    case update
    case delete
}
enum SyncStatus: String, PersistableEnum {
    case sync
    case needSync
    case fail
}
class PostObj: Object {
    @Persisted(primaryKey: true) var localId: String = UUID().uuidString
    @Persisted var serverId: Int?
    @Persisted var title: String = ""
    @Persisted var body: String = ""
    @Persisted var createdDate: Date = Date()
    @Persisted var updatedDate: Date = Date()
    @Persisted var isDeleted: Bool = false
    @Persisted var pendingStatus: PendingStatus = .none
    @Persisted var syncStatus: SyncStatus = .sync
    @Persisted var lastSyncError: String?
}
