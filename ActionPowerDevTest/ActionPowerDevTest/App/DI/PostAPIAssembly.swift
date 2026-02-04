//
//  PostAPIAssembly.swift
//  ActionPowerDevTest
//
//  Created by DavidChoi on 2/4/26.
//
import UIKit
import Swinject
import SwinjectAutoregistration
import Moya

class PostAPIAssembly: Assembly {
    func assemble(container: Container) {
        // MARK: - Provider
        container.register(MoyaProvider<PostAPIController>.self) { _ in
            MoyaProvider<PostAPIController>()
        }.inObjectScope(.container)
        
        // MARK: - DataSource
        container.register(PostAPIDataSourceType.self) { r in
            PostAPIDataSource(provider: r.resolve(MoyaProvider<PostAPIController>.self)!)
        }.inObjectScope(.container)
    }
}

