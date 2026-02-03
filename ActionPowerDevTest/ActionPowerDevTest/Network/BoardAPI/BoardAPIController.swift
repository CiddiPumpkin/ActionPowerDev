//
//  BoardAPIController.swift
//  ActionPowerDevTest
//
//  Created by DavidChoi on 2/3/26.
//
import Foundation
import Alamofire
import Moya

enum BoardAPIController {
    case getPosts(limit: Int = 10, skip: Int = 0)
    case getPost(id: Int)
    case createPost(req: BoardCreatePostRequest)
    case updatePost(id: Int, req: BoardUpdatePostRequest)
    case deletePost(id: Int)
}
extension BoardAPIController: TargetType {
    var baseURL: URL { URL(string: "https://dummyjson.com")! }

    var path: String {
        switch self {
        case .getPosts:
            return "/posts"
        case .getPost(let id):
            return "/posts/\(id)"
        case .createPost:
            return "/posts/add"
        case .updatePost(let id, _):
            return "/posts/\(id)"
        case .deletePost(let id):
            return "/posts/\(id)"
        }
    }
    var method: Moya.Method {
        switch self {
        case .getPosts, .getPost:
            return .get
        case .createPost:
            return .post
        case .updatePost:
            return .put
        case .deletePost:
            return .delete
        }
    }
    var task: Task {
        switch self {
        case .getPosts(let limit, let skip):
            return .requestParameters(parameters: ["limit": limit, "skip": skip], encoding: URLEncoding.queryString)
        case .getPost:
            return .requestPlain
        case .createPost(let req):
            return .requestJSONEncodable(req)
        case .updatePost(_, let req):
            return .requestJSONEncodable(req)
        case .deletePost:
            return .requestPlain
        }
    }
    var headers: [String: String]? {
        return ["Content-Type": "application/json"]
    }
}
