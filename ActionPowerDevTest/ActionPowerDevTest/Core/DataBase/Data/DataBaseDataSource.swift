//
//  DataBaseLocalDataSource.swift
//  ActionPowerDevTest
//
//  Created by DavidChoi on 2/3/26.
//


import Foundation
import RealmSwift

import Foundation
import RealmSwift

final class DataBaseDataSource {
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

    func fetchVisibleSortedByUpdatedDesc() -> [PostObj] {
        do {
            let realm = try realm()
            let results = realm.objects(PostObj.self)
                .filter("isDeleted == false")
                .sorted(byKeyPath: "updatedDate", ascending: false)
            return Array(results)
        } catch {
            print("Realm Post fetchVisibleSortedByUpdatedDesc Error:", error)
            return []
        }
    }

    func fetchPendingPosts() -> [PostObj] {
        do {
            let realm = try realm()
            let results = realm.objects(PostObj.self)
                .filter("pendingStatus != %@", PendingStatus.none.rawValue)
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
