//
//  PostAPIRepo.swift
//  ActionPowerDevTest
//
//  Created by DavidChoi on 2/3/26.
//

import RxSwift
import Moya
import RxMoya

protocol PostAPIDataSourceType {
    /// GET /posts?limit={limit}&skip={skip}
    func getPosts(limit: Int, skip: Int) -> Single<PostsResponse>
    /// GET /posts/{id}
    func getPost(id: Int) -> Single<Post>
    /// POST /posts/add
    func createPost(req: PostCreateRequest) -> Single<Post>
    /// PUT /posts/{id}
    func updatePost(id: Int, req: PostUpdateRequest) -> Single<Post>
    /// DELETE /posts/{id}
    func deletePost(id: Int) -> Single<PostDeleteResponse>
}
final class PostAPIDataSource: PostAPIDataSourceType {
    private let provider: MoyaProvider<PostAPIController>

    init(provider: MoyaProvider<PostAPIController>) {
        self.provider = provider
    }

    func getPosts(limit: Int = 10, skip: Int = 0) -> Single<PostsResponse> {
        return provider.rx
            .request(.getPosts(limit: limit, skip: skip))
            .filterSuccessfulStatusCodes()
            .map(PostsResponse.self)
    }
    func getPost(id: Int) -> Single<Post> {
        return provider.rx
            .request(.getPost(id: id))
            .filterSuccessfulStatusCodes()
            .map(Post.self)
    }
    func createPost(req: PostCreateRequest) -> Single<Post> {
        return provider.rx
            .request(.createPost(req: req))
            .filterSuccessfulStatusCodes()
            .map(Post.self)
    }
    func updatePost(id: Int, req: PostUpdateRequest) -> Single<Post> {
        return provider.rx
            .request(.updatePost(id: id, req: req))
            .filterSuccessfulStatusCodes()
            .map(Post.self)
    }
    func deletePost(id: Int) -> Single<PostDeleteResponse> {
        return provider.rx
            .request(.deletePost(id: id))
            .filterSuccessfulStatusCodes()
            .map(PostDeleteResponse.self)
    }
}

