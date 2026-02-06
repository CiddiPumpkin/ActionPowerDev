//
//  PostAPIResponse.swift
//  ActionPowerDevTest
//
//  Created by DavidChoi on 2/3/26.
//

import Foundation

/// GET /posts (list)
struct PostsResponse: Decodable {
    let posts: [Post]
    let total: Int
    let skip: Int
    let limit: Int
}
/// GET/POST/PUT 공통으로 디코딩 가능한 Post 모델
struct Post: Decodable {
    let id: Int
    let title: String
    let body: String
    let userId: Int?
    let localId: String?  // 로컬 식별자(API 응답엔 없으나 API Post / Local Post 병합 시 사용)
    let syncStatus: SyncStatus?  // 동기화 상태 (로컬 Post만 해당)
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case userId
    }
    
    init(id: Int, title: String, body: String, userId: Int?, localId: String? = nil, syncStatus: SyncStatus? = nil) {
        self.id = id
        self.title = title
        self.body = body
        self.userId = userId
        self.localId = localId
        self.syncStatus = syncStatus
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.body = try container.decode(String.self, forKey: .body)
        self.userId = try container.decodeIfPresent(Int.self, forKey: .userId)
        self.localId = nil
        self.syncStatus = nil
    }
}
/// DELETE /posts/{id}
struct PostDeleteResponse: Decodable {
    let id: Int
    let isDeleted: Bool?
    let deletedOn: String?
}
