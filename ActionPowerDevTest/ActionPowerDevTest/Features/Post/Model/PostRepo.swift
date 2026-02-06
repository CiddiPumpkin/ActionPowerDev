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
    func savePostToLocal(_ post: Post)
    func ensurePostInLocal(_ post: Post) -> Post  // API 게시글을 로컬 DB에 저장하고 localId 포함한 Post 반환
}

final class PostRepo: PostRepoType {
    private let postAPI: PostAPIDataSourceType
    private let db: DataBaseDataSourceType
    
    init(postAPI: PostAPIDataSourceType, db: DataBaseDataSourceType) {
        self.postAPI = postAPI
        self.db = db
    }
    
    func getPosts(page: Int, size: Int = 10) -> Single<PostsResponse> {
        let page = max(0, page)
        let skip = page * size
        return postAPI.getPosts(limit: size, skip: skip)
    }
    
    func createPost(title: String, body: String, userId: Int = 1) -> Single<Post> {
        let request = PostCreateRequest(title: title, body: body, userId: userId)
        return postAPI.createPost(req: request)
            .do(onSuccess: { [weak self] post in
                // API 성공 시 로컬 DB에 저장
                self?.savePostToLocal(post)
            })
            .catch { [weak self] error in
                // API 실패 시 로컬 전용으로 생성
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
        
        // serverId가 유효하고 syncStatus가 .sync인 경우 → 서버 API 호출
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
                        syncStatus: nil,
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
            // 로컬 전용 게시글 또는 needSync 상태 -> 로컬만 업데이트
            db.update(
                localId: localId,
                title: title,
                body: body,
                serverId: nil,
                isDeleted: nil,
                pendingStatus: postObj.syncStatus == .localOnly ? nil : .update,
                syncStatus: postObj.syncStatus == .localOnly ? .localOnly : .needSync,
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
        // localId로 로컬 DB에서 찾기
        guard let postObj = db.fetch(localId: localId) else {
            return .error(NSError(domain: "PostRepo", code: 404, userInfo: [NSLocalizedDescriptionKey: "Post not found"]))
        }
        
        // serverId가 유효하고 syncStatus가 .sync인 경우 -> 서버 API 호출
        if let serverId = postObj.serverId, serverId > 0, postObj.syncStatus == .sync {
            return postAPI.deletePost(id: serverId)
                .do(onSuccess: { [weak self] response in
                    // API 성공 시 로컬 DB에서 삭제
                    self?.db.delete(localId: localId)
                })
                .catch { [weak self] error in
                    // API 실패 시에도 로컬에서는 삭제 처리 (needSync 상태로)
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
                    
                    // 삭제 응답 반환 (로컬 기준)
                    let response = PostDeleteResponse(id: serverId, isDeleted: true, deletedOn: nil)
                    return .just(response)
                }
        } else {
            // 로컬 전용 게시글 -> 로컬에서만 삭제
            db.delete(localId: localId)
            
            // 삭제 응답 반환 (serverId가 없으면 -1)
            let response = PostDeleteResponse(id: postObj.serverId ?? -1, isDeleted: true, deletedOn: nil)
            return .just(response)
        }
    }
    
    // MARK: - Local DB
    
    /// 로컬 DB에서 게시글 목록 가져오기 (삭제되지 않은 것만, 최신순)
    func getLocalPosts() -> [PostObj] {
        return db.fetchVisibleSortedByUpdatedDesc()
    }
    
    /// API로 생성된 게시글을 로컬 DB에 저장
    func savePostToLocal(_ post: Post) {
        let postObj = PostObj()
        postObj.serverId = post.id
        postObj.title = post.title
        postObj.body = post.body
        postObj.createdDate = Date()
        postObj.updatedDate = Date()
        postObj.isDeleted = false
        postObj.pendingStatus = .none
        postObj.syncStatus = .sync
        
        db.create(postObj)
    }
    
    /// 오프라인 또는 API 실패 시 로컬 전용 게시글 생성
    private func createLocalOnlyPost(title: String, body: String, userId: Int) -> Post {
        let postObj = PostObj()
        postObj.serverId = nil  // 서버 ID 없음
        postObj.title = title
        postObj.body = body
        postObj.createdDate = Date()
        postObj.updatedDate = Date()
        postObj.isDeleted = false
        postObj.pendingStatus = .create  // 생성 대기 상태
        postObj.syncStatus = .localOnly  // 로컬 전용
        
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
        if let existingPost = db.fetchVisibleSortedByUpdatedDesc().first(where: { $0.serverId == post.id }) {
            // 이미 로컬에 있음 → localId 포함한 Post 반환
            return existingPost.toPost()
        }
        
        // 로컬에 없음 → 새로 저장
        savePostToLocal(post)
        
        // 저장 후 다시 찾아서 반환 (localId 포함)
        if let savedPost = db.fetchVisibleSortedByUpdatedDesc().first(where: { $0.serverId == post.id }) {
            return savedPost.toPost()
        }
        
        // 실패 시 원본 반환 (fallback)
        return post
    }
}
