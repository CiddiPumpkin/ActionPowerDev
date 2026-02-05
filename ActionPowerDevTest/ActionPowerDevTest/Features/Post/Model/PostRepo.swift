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
    func updatePost(id: Int, title: String?, body: String?) -> Single<Post>
    func deletePost(id: Int) -> Single<PostDeleteResponse>
    func getLocalPosts() -> [PostObj]
    func savePostToLocal(_ post: Post)
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
    }
    
    func updatePost(id: Int, title: String? = nil, body: String? = nil) -> Single<Post> {
        let request = PostUpdateRequest(title: title, body: body)
        return postAPI.updatePost(id: id, req: request)
    }
    
    func deletePost(id: Int) -> Single<PostDeleteResponse> {
        return postAPI.deletePost(id: id)
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
}
