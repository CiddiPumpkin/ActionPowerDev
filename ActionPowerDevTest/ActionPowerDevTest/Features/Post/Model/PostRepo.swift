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
}

final class PostRepo: PostRepoType {
    private let postAPI: PostAPIDataSourceType
    
    init(postAPI: PostAPIDataSourceType) {
        self.postAPI = postAPI
    }
    
    func getPosts(page: Int, size: Int = 10) -> Single<PostsResponse> {
        let page = max(0, page)
        let skip = page * size
        return postAPI.getPosts(limit: size, skip: skip)
    }
    
    func createPost(title: String, body: String, userId: Int = 1) -> Single<Post> {
        let request = PostCreateRequest(title: title, body: body, userId: userId)
        return postAPI.createPost(req: request)
    }
    
    func updatePost(id: Int, title: String? = nil, body: String? = nil) -> Single<Post> {
        let request = PostUpdateRequest(title: title, body: body)
        return postAPI.updatePost(id: id, req: request)
    }
    
    func deletePost(id: Int) -> Single<PostDeleteResponse> {
        return postAPI.deletePost(id: id)
    }
}
