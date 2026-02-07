//
//  Untitled.swift
//  ActionPowerDevTest
//
//  Created by DavidChoi on 2/3/26.
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
    case sync          // 서버와 동기화됨
    case localOnly     // 로컬에서만 존재(서버 ID 무효)
    case needSync      // 동기화 대기 중
    case fail          // 동기화 실패
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
extension PostObj {
    /// PostObj를 Post 모델로 변환 (PostsVC - TableView에서 사용)
    func toPost() -> Post {
        return Post(
            id: self.serverId ?? -1, // 오프라인 생성 게시글은 -1 사용
            title: self.title,
            body: self.body,
            userId: nil,
            localId: self.localId,
            syncStatus: self.syncStatus
        )
    }
}
