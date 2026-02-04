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
}
