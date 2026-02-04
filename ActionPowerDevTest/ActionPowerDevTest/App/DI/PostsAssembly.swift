//
//  PostsAssembly.swift
//  ActionPowerDevTest
//
//  Created by DavidChoi on 2/3/26.
//
import UIKit
import Swinject
import SwinjectAutoregistration

class PostsAssembly: Assembly {
    private let navController: UINavigationController
    
    init(navController: UINavigationController) {
        self.navController = navController
    }
    func assemble(container: Container) {
        // MARK: - Coordinator
        container.register(PostsCoordinator.self) { r in
            let nav = r ~> UINavigationController.self
            return PostsCoordinator(nav: nav, resolver: r)
        }
        // MARK: - Repository
        container.register(PostsRepoType.self) { r in
            PostsRepo(postAPI: r ~> PostAPIDataSourceType.self)
        }
        // MARK: - VM
        container.register(PostsVM.self) { r in
            PostsVM(repo: r ~> PostsRepoType.self)
        }
        // MARK: - VC
        container.register(PostsVC.self) { r in
            let vc = PostsVC()
            vc.coordinator = r ~> PostsCoordinator.self
            vc.vm = r ~> PostsVM.self
            return vc
        }
        // MARK: - Navigation
        container.register(UINavigationController.self) { _ in
            self.navController
        }
    }
}
