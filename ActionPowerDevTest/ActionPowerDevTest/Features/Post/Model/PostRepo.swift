//
//  PostRepo.swift
//  ActionPowerDevTest
//
//  Created by DavidChoi on 2/3/26.
//

import Foundation
import RxSwift
import RxRelay

protocol PostRepoType {
    func getPosts(page: Int, size: Int) -> Single<PostsResponse>
    func createPost(title: String, body: String, userId: Int) -> Single<Post>
    func updatePost(localId: String, title: String?, body: String?) -> Single<Post>
    func deletePost(localId: String) -> Single<PostDeleteResponse>
    func getLocalPosts() -> [PostObj]
    func savePostToLocal(_ post: Post, createdLocally: Bool)
    func ensurePostInLocal(_ post: Post) -> Post
    func syncPendingPosts() -> Single<SyncResult>
    func getDashboardStats() -> DashboardStats
    func isDeleted(serverId: Int) -> Bool
}

final class PostRepo: PostRepoType {
    private let postAPI: PostAPIDataSourceType
    private let db: DataBaseDataSourceType
    private let networkMonitor: NetworkMonitor
    
    // 삭제된 서버 ID를 추적하여 중복 표시 방지
    private var deletedServerIds = Set<Int>()
    
    init(postAPI: PostAPIDataSourceType, db: DataBaseDataSourceType, networkMonitor: NetworkMonitor) {
        self.postAPI = postAPI
        self.db = db
        self.networkMonitor = networkMonitor
    }
    
    // MARK: - Read
    func getPosts(page: Int, size: Int = 10) -> Single<PostsResponse> {
        let skip = max(0, page) * size
        return postAPI.getPosts(limit: size, skip: skip)
            .map { [weak self] response in
                guard let self = self else { return response }
                let filteredPosts = response.posts.filter { !self.deletedServerIds.contains($0.id) }
                return PostsResponse(posts: filteredPosts, total: response.total, skip: response.skip, limit: response.limit)
            }
    }
    
    // MARK: - Create
    func createPost(title: String, body: String, userId: Int = 1) -> Single<Post> {
        let request = PostCreateRequest(title: title, body: body, userId: userId)
        return postAPI.createPost(req: request)
            .do(onSuccess: { [weak self] post in
                self?.savePostToLocal(post, createdLocally: true)
            })
            .catch { [weak self] error in
                guard let self = self else { return .error(error) }
                return .just(self.createLocalOnlyPost(title: title, body: body, userId: userId))
            }
    }
    
    // MARK: - Update
    func updatePost(localId: String, title: String? = nil, body: String? = nil) -> Single<Post> {
        guard let postObj = db.fetch(localId: localId) else {
            return .error(NSError(domain: "PostRepo", code: 404, userInfo: [NSLocalizedDescriptionKey: "Post not found"]))
        }
        
        // 앱에서 생성해서 서버 동기화까지 성공한 포스트
        let isAppCreatedSuccessPost = postObj.createdLocally && postObj.syncStatus == .sync && postObj.pendingStatus == .none
        
        if isAppCreatedSuccessPost {
            return updateAppCreatedPost(localId: localId, title: title, body: body, isOnline: networkMonitor.isConnected.value)
        }
        
        // 서버에 존재하며 동기화된 포스트
        if let serverId = postObj.serverId, serverId > 0, postObj.syncStatus == .sync {
            return updateServerPost(localId: localId, serverId: serverId, title: title, body: body)
        }
        
        // 로컬 전용 포스트
        return updateLocalPost(localId: localId, title: title, body: body)
    }
    
    private func updateAppCreatedPost(localId: String, title: String?, body: String?, isOnline: Bool) -> Single<Post> {
        if isOnline {
            db.update(localId: localId, title: title, body: body, serverId: nil, isDeleted: nil,
                     pendingStatus: .none, syncStatus: .sync, lastSyncError: nil, updatedDate: Date())
        } else {
            db.update(localId: localId, title: title, body: body, serverId: nil, isDeleted: nil,
                     pendingStatus: .update, syncStatus: .needSync, lastSyncError: "네트워크 연결 끊김", updatedDate: Date())
        }
        
        guard let updatedPostObj = db.fetch(localId: localId) else {
            return .error(NSError(domain: "PostRepo", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch updated post"]))
        }
        return .just(updatedPostObj.toPost())
    }
    
    private func updateServerPost(localId: String, serverId: Int, title: String?, body: String?) -> Single<Post> {
        let request = PostUpdateRequest(title: title, body: body)
        return postAPI.updatePost(id: serverId, req: request)
            .do(onSuccess: { [weak self] updatedPost in
                self?.db.update(localId: localId, title: updatedPost.title, body: updatedPost.body, serverId: nil,
                               isDeleted: nil, pendingStatus: nil, syncStatus: .sync, lastSyncError: nil, updatedDate: Date())
            })
            .catch { [weak self] error in
                self?.db.update(localId: localId, title: title, body: body, serverId: nil, isDeleted: nil,
                               pendingStatus: .update, syncStatus: .needSync, lastSyncError: error.localizedDescription, updatedDate: Date())
                
                if let updatedPostObj = self?.db.fetch(localId: localId) {
                    return .just(updatedPostObj.toPost())
                }
                return .error(error)
            }
    }
    
    private func updateLocalPost(localId: String, title: String?, body: String?) -> Single<Post> {
        db.update(localId: localId, title: title, body: body, serverId: nil, isDeleted: nil,
                 pendingStatus: .update, syncStatus: .needSync, lastSyncError: nil, updatedDate: Date())
        
        guard let updatedPostObj = db.fetch(localId: localId) else {
            return .error(NSError(domain: "PostRepo", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch updated post"]))
        }
        return .just(updatedPostObj.toPost())
    }
    
    // MARK: - Delete
    
    func deletePost(localId: String) -> Single<PostDeleteResponse> {
        guard let postObj = db.fetch(localId: localId) else {
            return .error(NSError(domain: "PostRepo", code: 404, userInfo: [NSLocalizedDescriptionKey: "Post not found"]))
        }
        
        // 앱에서 생성해서 서버 동기화까지 성공한 포스트
        let isAppCreatedSuccessPost = postObj.createdLocally && postObj.syncStatus == .sync && postObj.pendingStatus == .none
        
        if isAppCreatedSuccessPost {
            return deleteAppCreatedPost(postObj: postObj, isOnline: networkMonitor.isConnected.value)
        }
        
        // 로컬 전용 포스트는 삭제 마크만
        if postObj.syncStatus == .localOnly {
            return markAsDeleted(localId: localId, serverId: -1)
        }
        
        guard let serverId = postObj.serverId, serverId > 0 else {
            return .error(NSError(domain: "PostRepo", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid serverId"]))
        }
        
        return postAPI.deletePost(id: serverId)
            .do(onSuccess: { [weak self] _ in
                self?.db.delete(localId: localId)
                self?.deletedServerIds.insert(serverId)
            })
            .catch { [weak self] error in
                self?.markAsDeletedWithError(localId: localId, error: error.localizedDescription)
                return .just(PostDeleteResponse(id: serverId, isDeleted: true, deletedOn: nil))
            }
    }
    
    private func deleteAppCreatedPost(postObj: PostObj, isOnline: Bool) -> Single<PostDeleteResponse> {
        if isOnline {
            db.delete(localId: postObj.localId)
            if let serverId = postObj.serverId {
                deletedServerIds.insert(serverId)
            }
            return .just(PostDeleteResponse(id: postObj.serverId ?? -1, isDeleted: true, deletedOn: nil))
        } else {
            return markAsDeletedWithError(localId: postObj.localId, error: "네트워크 연결 끊김")
        }
    }
    
    private func markAsDeleted(localId: String, serverId: Int) -> Single<PostDeleteResponse> {
        db.update(localId: localId, title: nil, body: nil, serverId: nil, isDeleted: true,
                 pendingStatus: .delete, syncStatus: .needSync, lastSyncError: nil, updatedDate: Date())
        return .just(PostDeleteResponse(id: serverId, isDeleted: true, deletedOn: nil))
    }
    
    private func markAsDeletedWithError(localId: String, error: String) -> Single<PostDeleteResponse> {
        db.update(localId: localId, title: nil, body: nil, serverId: nil, isDeleted: true,
                 pendingStatus: .delete, syncStatus: .needSync, lastSyncError: error, updatedDate: Date())
        
        let serverId = db.fetch(localId: localId)?.serverId ?? -1
        return .just(PostDeleteResponse(id: serverId, isDeleted: true, deletedOn: nil))
    }
    
    // MARK: - Local Storage
    func getLocalPosts() -> [PostObj] {
        return db.fetchVisibleSortedByCreatedDesc()
    }
    
    func savePostToLocal(_ post: Post, createdLocally: Bool = false) {
        let postObj = PostObj()
        postObj.serverId = post.id
        postObj.title = post.title
        postObj.body = post.body
        postObj.createdDate = Date()
        postObj.updatedDate = Date()
        postObj.isDeleted = false
        postObj.pendingStatus = .none
        postObj.syncStatus = .sync
        postObj.createdLocally = createdLocally
        
        db.create(postObj)
    }
    
    private func createLocalOnlyPost(title: String, body: String, userId: Int) -> Post {
        let postObj = PostObj()
        postObj.serverId = nil
        postObj.title = title
        postObj.body = body
        postObj.createdDate = Date()
        postObj.updatedDate = Date()
        postObj.isDeleted = false
        postObj.pendingStatus = .create
        postObj.syncStatus = .localOnly
        postObj.createdLocally = true
        
        db.create(postObj)
        return postObj.toPost()
    }
    
    func ensurePostInLocal(_ post: Post) -> Post {
        if let localId = post.localId, !localId.isEmpty {
            return post
        }
        
        if let existingPost = db.fetchVisibleSortedByCreatedDesc().first(where: { $0.serverId == post.id }) {
            return existingPost.toPost()
        }
        
        savePostToLocal(post, createdLocally: false)
        
        if let savedPost = db.fetchVisibleSortedByCreatedDesc().first(where: { $0.serverId == post.id }) {
            return savedPost.toPost()
        }
        
        return post
    }
    
    // MARK: - Sync
    func syncPendingPosts() -> Single<SyncResult> {
        let pendingPosts = db.fetchPendingPosts()
        
        guard !pendingPosts.isEmpty else {
            return .just(SyncResult(success: 0, failed: 0, errors: []))
        }
        
        let pendingPostsData = pendingPosts.map { postObj in
            PendingPostData(
                localId: postObj.localId,
                serverId: postObj.serverId,
                title: postObj.title,
                body: postObj.body,
                pendingStatus: postObj.pendingStatus,
                createdLocally: postObj.createdLocally
            )
        }
        
        let syncObservables = pendingPostsData.map { postData -> Single<SyncItemResult> in
            switch postData.pendingStatus {
            case .create: return syncCreatePost(postData)
            case .update: return syncUpdatePost(postData)
            case .delete: return syncDeletePost(postData)
            case .none: return .just(SyncItemResult(localId: postData.localId, success: true, error: nil))
            }
        }
        
        return Single.zip(syncObservables)
            .map { results in
                SyncResult(
                    success: results.filter { $0.success }.count,
                    failed: results.filter { !$0.success }.count,
                    errors: results.compactMap { $0.error }
                )
            }
    }
    
    // 대기 중인 생성 요청 동기화
    private func syncCreatePost(_ postData: PendingPostData) -> Single<SyncItemResult> {
        let request = PostCreateRequest(title: postData.title, body: postData.body, userId: 1)
        
        return postAPI.createPost(req: request)
            .do(onSuccess: { [weak self] post in
                self?.db.delete(localId: postData.localId)
                self?.savePostToLocal(post, createdLocally: true)
            })
            .map { _ in SyncItemResult(localId: postData.localId, success: true, error: nil) }
            .catch { error in
                self.db.update(localId: postData.localId, title: nil, body: nil, serverId: nil,
                              isDeleted: nil, pendingStatus: .create, syncStatus: .fail,
                              lastSyncError: error.localizedDescription, updatedDate: Date())
                return .just(SyncItemResult(localId: postData.localId, success: false, error: error.localizedDescription))
            }
    }
    
    // 대기 중인 수정 요청 동기화
    private func syncUpdatePost(_ postData: PendingPostData) -> Single<SyncItemResult> {
        // 앱에서 생성한 포스트는 서버 업데이트 불필요
        if postData.createdLocally {
            db.update(localId: postData.localId, title: nil, body: nil, serverId: nil, isDeleted: nil,
                     pendingStatus: .none, syncStatus: postData.serverId == nil ? .localOnly : .sync,
                     lastSyncError: nil, updatedDate: Date())
            return .just(SyncItemResult(localId: postData.localId, success: true, error: nil))
        }
        
        guard let serverId = postData.serverId else {
            db.update(localId: postData.localId, title: nil, body: nil, serverId: nil, isDeleted: nil,
                     pendingStatus: .none, syncStatus: .localOnly, lastSyncError: nil, updatedDate: Date())
            return .just(SyncItemResult(localId: postData.localId, success: true, error: nil))
        }
        
        return postAPI.updatePost(id: serverId, req: PostUpdateRequest(title: postData.title, body: postData.body))
            .do(onSuccess: { [weak self] _ in
                self?.db.update(localId: postData.localId, title: nil, body: nil, serverId: nil,
                               isDeleted: nil, pendingStatus: .none, syncStatus: .sync,
                               lastSyncError: nil, updatedDate: Date())
            })
            .map { _ in SyncItemResult(localId: postData.localId, success: true, error: nil) }
            .catch { error in
                self.db.update(localId: postData.localId, title: nil, body: nil, serverId: nil,
                              isDeleted: nil, pendingStatus: .update, syncStatus: .fail,
                              lastSyncError: error.localizedDescription, updatedDate: Date())
                return .just(SyncItemResult(localId: postData.localId, success: false, error: error.localizedDescription))
            }
    }
    
    // 대기 중인 삭제 요청 동기화
    private func syncDeletePost(_ postData: PendingPostData) -> Single<SyncItemResult> {
        if postData.createdLocally {
            db.delete(localId: postData.localId)
            return .just(SyncItemResult(localId: postData.localId, success: true, error: nil))
        }
        
        guard let serverId = postData.serverId else {
            db.delete(localId: postData.localId)
            return .just(SyncItemResult(localId: postData.localId, success: true, error: nil))
        }
        
        return postAPI.deletePost(id: serverId)
            .do(onSuccess: { [weak self] _ in
                self?.db.delete(localId: postData.localId)
                self?.deletedServerIds.insert(serverId)
            })
            .map { _ in SyncItemResult(localId: postData.localId, success: true, error: nil) }
            .catch { error in
                self.db.update(localId: postData.localId, title: nil, body: nil, serverId: nil,
                              isDeleted: nil, pendingStatus: .delete, syncStatus: .fail,
                              lastSyncError: error.localizedDescription, updatedDate: Date())
                return .just(SyncItemResult(localId: postData.localId, success: false, error: error.localizedDescription))
            }
    }
    
    // MARK: - Utilities
    func isDeleted(serverId: Int) -> Bool {
        return deletedServerIds.contains(serverId)
    }
    
    func getDashboardStats() -> DashboardStats {
        let allPosts = db.fetchVisibleSortedByCreatedDesc()
        let activePosts = allPosts.filter { $0.isDeleted == false }
        
        return DashboardStats(
            totalCount: activePosts.count,
            localOnlyCount: activePosts.filter { $0.syncStatus == .localOnly }.count,
            needSyncCount: allPosts.filter { $0.syncStatus == .needSync || $0.pendingStatus != .none }.count,
            recentPosts: db.fetchRecentTop5().map { $0.toPost() }
        )
    }
}

// MARK: - Supporting Types
private struct PendingPostData {
    let localId: String
    let serverId: Int?
    let title: String
    let body: String
    let pendingStatus: PendingStatus
    let createdLocally: Bool
}

struct SyncResult {
    let success: Int
    let failed: Int
    let errors: [String]
}

struct SyncItemResult {
    let localId: String
    let success: Bool
    let error: String?
}

struct DashboardStats {
    let totalCount: Int
    let localOnlyCount: Int
    let needSyncCount: Int
    let recentPosts: [Post]
}

