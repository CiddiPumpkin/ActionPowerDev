//
//  BoardAPIResponse.swift
//  ActionPowerDevTest
//
//  Created by DavidChoi on 2/3/26.
//

import Foundation

/// GET /posts (list)
struct BoardPostsResponse: Decodable {
    let posts: [BoardPost]
    let total: Int
    let skip: Int
    let limit: Int
}
/// GET/POST/PUT 공통으로 디코딩 가능한 Post 모델
struct BoardPost: Decodable {
    let id: Int
    let title: String
    let body: String
    let userId: Int?
}
/// DELETE /posts/{id}
struct BoardDeletePostResponse: Decodable {
    let id: Int
    let isDeleted: Bool?
    let deletedOn: String?
}
