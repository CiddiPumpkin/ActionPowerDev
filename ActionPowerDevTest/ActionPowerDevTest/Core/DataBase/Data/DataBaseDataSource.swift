//
//  DataBaseLocalDataSource.swift
//  ActionPowerDevTest
//
//  Created by DavidChoi on 2/3/26.
//
import Foundation
import RealmSwift

protocol DataBaseDataSourceType {
    func create(_ post: PostObj)
    func create(_ posts: [PostObj])
    func update(
        localId: String,
        title: String?,
        body: String?,
        serverId: Int?,
        isDeleted: Bool?,
        pendingStatus: PendingStatus?,
        syncStatus: SyncStatus?,
        lastSyncError: String?,
        updatedDate: Date
    )
    func fetch(localId: String) -> PostObj?
    func fetchVisibleSortedByCreatedDesc() -> [PostObj]
    func fetchPendingPosts() -> [PostObj]
    func fetchRecentTop5() -> [PostObj]
    func delete(localId: String)
}

final class DataBaseDataSource: DataBaseDataSourceType {
    init() {}
    static func configureMigration() {
        let config = Realm.Configuration(
            schemaVersion: 1,
            migrationBlock: { migration, oldSchemaVersion in
                // 마이그레이션
                if oldSchemaVersion < 1 { }
            }
        )
        Realm.Configuration.defaultConfiguration = config
    }

    private func realm() throws -> Realm { try Realm() }
    
    func create(_ post: PostObj) {
        do {
            let realm = try realm()
            try realm.write {
                realm.add(post, update: .modified)
            }
        } catch {
            print("Realm Post create Error:", error)
        }
    }

    func create(_ posts: [PostObj]) {
        guard posts.isEmpty == false else { return }
        do {
            let realm = try realm()
            try realm.write {
                realm.add(posts, update: .modified)
            }
        } catch {
            print("Realm Post createMany Error:", error)
        }
    }

    func update(
        localId: String,
        title: String? = nil,
        body: String? = nil,
        serverId: Int? = nil,
        isDeleted: Bool? = nil,
        pendingStatus: PendingStatus? = nil,
        syncStatus: SyncStatus? = nil,
        lastSyncError: String? = nil,
        updatedDate: Date = Date()
    ) {
        do {
            let realm = try realm()
            guard let obj = realm.object(ofType: PostObj.self, forPrimaryKey: localId) else { return }

            try realm.write {
                if let title = title { obj.title = title }
                if let body = body { obj.body = body }
                if let serverId = serverId { obj.serverId = serverId }
                if let isDeleted = isDeleted { obj.isDeleted = isDeleted }
                if let pendingStatus = pendingStatus { obj.pendingStatus = pendingStatus }
                if let syncStatus = syncStatus { obj.syncStatus = syncStatus }
                obj.lastSyncError = lastSyncError
                obj.updatedDate = updatedDate
            }
        } catch {
            print("Realm Post update Error:", error)
        }
    }

    // MARK: - Read

    func fetch(localId: String) -> PostObj? {
        do {
            let realm = try realm()
            return realm.object(ofType: PostObj.self, forPrimaryKey: localId)
        } catch {
            print("Realm Post fetch Error:", error)
            return nil
        }
    }

    func fetchVisibleSortedByCreatedDesc() -> [PostObj] {
        do {
            let realm = try realm()
            let results = realm.objects(PostObj.self)
                .filter("isDeleted == false")
                .sorted(byKeyPath: "createdDate", ascending: false)
            return Array(results)
        } catch {
            print("Realm Post fetchVisibleSortedByCreatedDesc Error:", error)
            return []
        }
    }

    func fetchPendingPosts() -> [PostObj] {
        do {
            let realm = try realm()
            // pendingStatus가 none이 아니거나, syncStatus가 localOnly/needSync인 것들
            let results = realm.objects(PostObj.self)
                .filter("isDeleted == false AND ((pendingStatus != %@) OR (syncStatus == %@) OR (syncStatus == %@))",
                       PendingStatus.none.rawValue,
                       SyncStatus.localOnly.rawValue,
                       SyncStatus.needSync.rawValue)
                .sorted(byKeyPath: "updatedDate", ascending: true)
            return Array(results)
        } catch {
            print("Realm Post fetchPendingPosts Error:", error)
            return []
        }
    }

    func fetchRecentTop5() -> [PostObj] {
        do {
            let realm = try realm()
            let results = realm.objects(PostObj.self)
                .filter("isDeleted == false")
                .sorted(byKeyPath: "updatedDate", ascending: false)
            return Array(results.prefix(5))
        } catch {
            print("Realm Post fetchRecentTop5 Error:", error)
            return []
        }
    }

    // MARK: - Delete
    func delete(localId: String) {
        do {
            let realm = try realm()
            guard let obj = realm.object(ofType: PostObj.self, forPrimaryKey: localId) else { return }
            try realm.write {
                realm.delete(obj)
            }
        } catch {
            print("Realm Post deleteById Error:", error)
        }
    }
}
