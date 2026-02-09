//
//  PostRepo.swift
//  ActionPowerDevTest
//
//  Created by DavidChoi on 2/3/26.
//

import Foundation
import RxSwift

protocol PostRepoType {
    func getPosts(page: Int, size: Int) -> Single<PostsResponse>
    func createPost(title: String, body: String, userId: Int) -> Single<Post>
    func updatePost(localId: String, title: String?, body: String?) -> Single<Post>
    func deletePost(localId: String) -> Single<PostDeleteResponse>
    func getLocalPosts() -> [PostObj]
    func savePostToLocal(_ post: Post, createdLocally: Bool)
    func ensurePostInLocal(_ post: Post) -> Post  // API 게시글을 로컬 DB에 저장하고 localId 포함한 Post 반환
    func syncPendingPosts() -> Single<SyncResult>  // 대기 중인 게시글 동기화
    func getDashboardStats() -> DashboardStats  // 대시보드 통계 정보
    func isDeleted(serverId: Int) -> Bool  // 해당 serverId가 삭제되었는지 확인
}

final class PostRepo: PostRepoType {
    private let postAPI: PostAPIDataSourceType
    private let db: DataBaseDataSourceType
    private var deletedServerIds = Set<Int>()
    
    init(postAPI: PostAPIDataSourceType, db: DataBaseDataSourceType) {
        self.postAPI = postAPI
        self.db = db
    }
    // MARK: - Post
    func getPosts(page: Int, size: Int = 10) -> Single<PostsResponse> {
        let page = max(0, page)
        let skip = page * size
        return postAPI.getPosts(limit: size, skip: skip)
            .map { [weak self] response in
                // 앱 런타임 중 삭제된 게시글 필터링
                guard let self = self else { return response }
                
                let filteredPosts = response.posts.filter { post in
                    let isDeleted = self.deletedServerIds.contains(post.id)
                    if isDeleted {
                    }
                    return !isDeleted
                }
                
                return PostsResponse(
                    posts: filteredPosts,
                    total: response.total,
                    skip: response.skip,
                    limit: response.limit
                )
            }
    }
    
    func createPost(title: String, body: String, userId: Int = 1) -> Single<Post> {
        let request = PostCreateRequest(title: title, body: body, userId: userId)
        return postAPI.createPost(req: request)
            .do(onSuccess: { [weak self] post in
                // API 성공 시 로컬 DB에 저장 (createdLocally = true 플래그)
                self?.savePostToLocal(post, createdLocally: true)
            })
            .catch { [weak self] error in
                // API 실패 시 오프라인 생성으로 생성
                guard let self = self else { return .error(error) }
                
                let localPost = self.createLocalOnlyPost(title: title, body: body, userId: userId)
                return .just(localPost)
            }
    }
    
    func updatePost(localId: String, title: String? = nil, body: String? = nil) -> Single<Post> {
        // localId로 로컬 DB에서 찾기
        guard let postObj = db.fetch(localId: localId) else {
            return .error(NSError(domain: "PostRepo", code: 404, userInfo: [NSLocalizedDescriptionKey: "Post not found"]))
        }
        
        // serverId가 유효하고 syncStatus가 .sync인 경우 서버 API 호출
        if let serverId = postObj.serverId, serverId > 0, postObj.syncStatus == .sync {
            let request = PostUpdateRequest(title: title, body: body)
            return postAPI.updatePost(id: serverId, req: request)
                .do(onSuccess: { [weak self] updatedPost in
                    // API 성공 시 로컬 DB 업데이트
                    self?.db.update(
                        localId: localId,
                        title: updatedPost.title,
                        body: updatedPost.body,
                        serverId: nil,
                        isDeleted: nil,
                        pendingStatus: nil,
                        syncStatus: .sync,
                        lastSyncError: nil,
                        updatedDate: Date()
                    )
                })
                .catch { [weak self] error in
                    // API 실패 시에도 로컬만 업데이트 (needSync 상태로)
                    self?.db.update(
                        localId: localId,
                        title: title,
                        body: body,
                        serverId: nil,
                        isDeleted: nil,
                        pendingStatus: .update,
                        syncStatus: .needSync,
                        lastSyncError: error.localizedDescription,
                        updatedDate: Date()
                    )
                    
                    // 로컬 업데이트된 데이터 반환
                    if let updatedPostObj = self?.db.fetch(localId: localId) {
                        return .just(updatedPostObj.toPost())
                    }
                    return .error(error)
                }
        } else {
            db.update(
                localId: localId,
                title: title,
                body: body,
                serverId: nil,
                isDeleted: nil,
                pendingStatus: .update,
                syncStatus: .needSync,
                lastSyncError: nil,
                updatedDate: Date()
            )
            
            // 업데이트된 PostObj를 Post로 변환하여 반환
            guard let updatedPostObj = db.fetch(localId: localId) else {
                return .error(NSError(domain: "PostRepo", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch updated post"]))
            }
            return .just(updatedPostObj.toPost())
        }
    }
    
    func deletePost(localId: String) -> Single<PostDeleteResponse> {
        guard let postObj = db.fetch(localId: localId) else {
            return .error(NSError(domain: "PostRepo", code: 404, userInfo: [NSLocalizedDescriptionKey: "Post not found"]))
        }
        if postObj.syncStatus == .localOnly {
            db.update(
                localId: localId,
                title: nil,
                body: nil,
                serverId: nil,
                isDeleted: true,
                pendingStatus: .delete,
                syncStatus: .needSync,
                lastSyncError: nil,
                updatedDate: Date()
            )
            return .just(PostDeleteResponse(id: -1, isDeleted: true, deletedOn: nil))
        }
        
        guard let serverId = postObj.serverId, serverId > 0 else {
            return .error(NSError(domain: "PostRepo", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid serverId"]))
        }
        
        return postAPI.deletePost(id: serverId)
            .do(onSuccess: { [weak self] _ in
                // API 성공 시 로컬 DB에서 완전히 삭제
                self?.db.delete(localId: localId)
                self?.deletedServerIds.insert(serverId)
            })
            .catch { [weak self] error in
                // 오프라인이면 삭제 대기 상태로 변경
                self?.db.update(
                    localId: localId,
                    title: nil,
                    body: nil,
                    serverId: nil,
                    isDeleted: true,
                    pendingStatus: .delete,
                    syncStatus: .needSync,
                    lastSyncError: error.localizedDescription,
                    updatedDate: Date()
                )
                // 삭제 대기 상태로 처리되었음을 응답
                return .just(PostDeleteResponse(id: serverId, isDeleted: true, deletedOn: nil))
            }
    }
    
    // MARK: - Local DB
    
    /// 로컬 DB에서 게시글 목록 가져오기 (삭제되지 않은 것만, 생성일 기준 최신순)
    func getLocalPosts() -> [PostObj] {
        return db.fetchVisibleSortedByCreatedDesc()
    }
    
    /// API로 생성된 게시글을 로컬 DB에 저장
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
    
    /// 오프라인 또는 API 실패 시 오프라인 생성 게시글 생성
    private func createLocalOnlyPost(title: String, body: String, userId: Int) -> Post {
        let postObj = PostObj()
        postObj.serverId = nil  // 서버 ID 없음
        postObj.title = title
        postObj.body = body
        postObj.createdDate = Date()
        postObj.updatedDate = Date()
        postObj.isDeleted = false
        postObj.pendingStatus = .create  // 생성 대기 상태
        postObj.syncStatus = .localOnly  // 오프라인 생성
        postObj.createdLocally = true  // 앱에서 생성
        
        db.create(postObj)
        
        return postObj.toPost()
    }
    
    /// API 게시글을 로컬 DB에 저장하고 localId를 포함한 Post 반환
    /// 이미 로컬에 있으면 기존 것 반환, 없으면 새로 저장
    func ensurePostInLocal(_ post: Post) -> Post {
        // localId가 이미 있으면 그대로 반환
        if let localId = post.localId, !localId.isEmpty {
            return post
        }
        
        // serverId로 로컬 DB에서 찾기
        if let existingPost = db.fetchVisibleSortedByCreatedDesc().first(where: { $0.serverId == post.id }) {
            // 이미 로컬에 있으면 localId 포함한 Post 반환
            return existingPost.toPost()
        }
        
        // 로컬에 없으면 새로 저장 (서버에서 가져온 것이므로 createdLocally = false)
        savePostToLocal(post, createdLocally: false)
        
        // 저장 후 다시 찾아서 반환 (localId 포함)
        if let savedPost = db.fetchVisibleSortedByCreatedDesc().first(where: { $0.serverId == post.id }) {
            return savedPost.toPost()
        }
        
        // 실패 시 원본 반환 (fallback)
        return post
    }
    
    // MARK: - Sync
    
    /// 대기 중인 게시글들을 서버와 동기화
    func syncPendingPosts() -> Single<SyncResult> {
        let pendingPosts = db.fetchPendingPosts()
        
        guard !pendingPosts.isEmpty else {
            return .just(SyncResult(success: 0, failed: 0, errors: []))
        }
        
        // Realm 객체에서 필요한 데이터만 추출하여 구조체로 변환
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
        
        var syncObservables: [Single<SyncItemResult>] = []
        
        for postData in pendingPostsData {
            let syncItem: Single<SyncItemResult>
            
            switch postData.pendingStatus {
            case .create:
                // 생성 대기 중인 게시글
                syncItem = syncCreatePost(postData)
                
            case .update:
                // 수정 대기 중인 게시글
                syncItem = syncUpdatePost(postData)
                
            case .delete:
                // 삭제 대기 중인 게시글
                syncItem = syncDeletePost(postData)
                
            case .none:
                syncItem = .just(SyncItemResult(localId: postData.localId, success: true, error: nil))
            }
            
            syncObservables.append(syncItem)
        }
        
        // 모든 동기화 작업을 병렬로 실행
        return Single.zip(syncObservables)
            .map { results in
                let successCount = results.filter { $0.success }.count
                let failedCount = results.filter { !$0.success }.count
                let errors = results.compactMap { $0.error }
                
                return SyncResult(success: successCount, failed: failedCount, errors: errors)
            }
    }
    
    private func syncCreatePost(_ postData: PendingPostData) -> Single<SyncItemResult> {
        let request = PostCreateRequest(title: postData.title, body: postData.body, userId: 1)
        
        return postAPI.createPost(req: request)
            .do(onSuccess: { [weak self] post in
                print("생성 동기화 성공 - localId: \(postData.localId)")
                self?.db.update(localId: postData.localId, title: nil, body: nil, serverId: post.id, 
                               isDeleted: nil, pendingStatus: .none, syncStatus: .sync, 
                               lastSyncError: nil, updatedDate: Date())
            })
            .map { _ in SyncItemResult(localId: postData.localId, success: true, error: nil) }
            .catch { error in
                print("생성 동기화 실패 - localId: \(postData.localId)")
                self.db.update(localId: postData.localId, title: nil, body: nil, serverId: nil,
                              isDeleted: nil, pendingStatus: .create, syncStatus: .fail,
                              lastSyncError: error.localizedDescription, updatedDate: Date())
                return .just(SyncItemResult(localId: postData.localId, success: false, error: error.localizedDescription))
            }
    }
    
    private func syncUpdatePost(_ postData: PendingPostData) -> Single<SyncItemResult> {
        guard let serverId = postData.serverId else {
            print("수정 동기화 - localId: \(postData.localId) (localOnly, API 호출 없이 즉시 처리)")
            // pendingStatus와 syncStatus를 제거하여 일반 게시글처럼 만듦
            self.db.update(
                localId: postData.localId,
                title: nil,
                body: nil,
                serverId: nil,
                isDeleted: nil,
                pendingStatus: .none,
                syncStatus: .localOnly,
                lastSyncError: nil,
                updatedDate: Date()
            )
            return .just(SyncItemResult(localId: postData.localId, success: true, error: nil))
        }
        
        return postAPI.updatePost(id: serverId, req: PostUpdateRequest(title: postData.title, body: postData.body))
            .do(onSuccess: { [weak self] _ in
                print("수정 동기화 성공 - localId: \(postData.localId)")
                self?.db.update(localId: postData.localId, title: nil, body: nil, serverId: nil,
                               isDeleted: nil, pendingStatus: .none, syncStatus: .sync,
                               lastSyncError: nil, updatedDate: Date())
            })
            .map { _ in SyncItemResult(localId: postData.localId, success: true, error: nil) }
            .catch { error in
                print("수정 동기화 실패 - localId: \(postData.localId)")
                self.db.update(localId: postData.localId, title: nil, body: nil, serverId: nil,
                              isDeleted: nil, pendingStatus: .update, syncStatus: .fail,
                              lastSyncError: error.localizedDescription, updatedDate: Date())
                return .just(SyncItemResult(localId: postData.localId, success: false, error: error.localizedDescription))
            }
    }
    
    private func syncDeletePost(_ postData: PendingPostData) -> Single<SyncItemResult> {
        // createdLocally == true인 게시글은 앱에서 생성한 것이므로 삭제 API 호출 없이 즉시 로컬에서만 삭제
        if postData.createdLocally {
            print("삭제 동기화 - localId: \(postData.localId) (앱에서 생성한 게시글, API 호출 없이 즉시 삭제)")
            self.db.delete(localId: postData.localId)
            return .just(SyncItemResult(localId: postData.localId, success: true, error: nil))
        }
        
        // serverId가 없으면 한 번도 서버에 동기화되지 않은 게시글이므로 API 호출 없이 즉시 삭제
        guard let serverId = postData.serverId else {
            print("삭제 동기화 - localId: \(postData.localId) (localOnly, API 호출 없이 즉시 삭제)")
            self.db.delete(localId: postData.localId)
            return .just(SyncItemResult(localId: postData.localId, success: true, error: nil))
        }
        
        // serverId가 있고 createdLocally == false인 게시글은 서버 삭제 API 호출
        return postAPI.deletePost(id: serverId)
            .do(onSuccess: { [weak self] _ in
                print("삭제 동기화 성공 - localId: \(postData.localId)")
                self?.db.delete(localId: postData.localId)
                self?.deletedServerIds.insert(serverId)
            })
            .map { _ in SyncItemResult(localId: postData.localId, success: true, error: nil) }
            .catch { error in
                print("삭제 동기화 실패 - localId: \(postData.localId)")
                self.db.update(localId: postData.localId, title: nil, body: nil, serverId: nil,
                              isDeleted: nil, pendingStatus: .delete, syncStatus: .fail,
                              lastSyncError: error.localizedDescription, updatedDate: Date())
                return .just(SyncItemResult(localId: postData.localId, success: false, error: error.localizedDescription))
            }
    }
    
    // MARK: - Utility
    
    /// 해당 serverId가 삭제되었는지 확인
    func isDeleted(serverId: Int) -> Bool {
        return deletedServerIds.contains(serverId)
    }
    
    // MARK: - Dashboard
    /// 대시보드 통계 정보 조회
    func getDashboardStats() -> DashboardStats {
        let allPosts = db.fetchVisibleSortedByCreatedDesc()
        
        // 삭제 대기 중이지 않은 게시글만 카운팅
        let activePosts = allPosts.filter { $0.isDeleted == false }
        let localOnlyPosts = activePosts.filter { $0.syncStatus == .localOnly }
        let needSyncPosts = allPosts.filter { $0.syncStatus == .needSync || $0.pendingStatus != .none }
        let recentPosts = db.fetchRecentTop5().map { $0.toPost() }
        
        return DashboardStats(
            totalCount: activePosts.count,
            localOnlyCount: localOnlyPosts.count,
            needSyncCount: needSyncPosts.count,
            recentPosts: recentPosts
        )
    }
}
// MARK: - Sync Models
/// 대기 중인 게시글 데이터 (Realm 스레드 안전성을 위한 구조체)
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
// MARK: - Dashboard Models
struct DashboardStats {
    let totalCount: Int
    let localOnlyCount: Int
    let needSyncCount: Int
    let recentPosts: [Post]
}

