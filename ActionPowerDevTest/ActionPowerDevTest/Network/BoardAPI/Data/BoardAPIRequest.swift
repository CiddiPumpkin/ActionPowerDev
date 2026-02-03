//
//  BoardApiRequest.swift
//  ActionPowerDevTest
//
//  Created by DavidChoi on 2/3/26.
//

import Foundation

/// POST /posts/add
struct BoardCreatePostRequest: Encodable {
    let title: String
    let body: String
    let userId: Int

    init(title: String, body: String, userId: Int = 1) {
        self.title = title
        self.body = body
        self.userId = userId
    }
}
/// PUT /posts/{id}
struct BoardUpdatePostRequest: Encodable {
    let title: String?
    let body: String?

    init(title: String? = nil, body: String? = nil) {
        self.title = title
        self.body = body
    }
}
