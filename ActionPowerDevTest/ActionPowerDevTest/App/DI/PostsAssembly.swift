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
        container.register(PostCoordinator.self) { r in
            let nav = r ~> UINavigationController.self
            return PostCoordinator(nav: nav, resolver: r)
        }
        // MARK: - Repository
        container.register(PostRepoType.self) { r in
            PostRepo(postAPI: r ~> PostAPIDataSourceType.self)
        }
        // MARK: - VM
        container.register(PostVM.self) { r in
            PostVM(repo: r ~> PostRepoType.self)
        }
        // MARK: - VC
        container.register(PostsVC.self) { r in
            let vc = PostsVC()
            vc.coordinator = r ~> PostCoordinator.self
            vc.vm = r ~> PostVM.self
            return vc
        }
        // MARK: - Navigation
        container.register(UINavigationController.self) { _ in
            self.navController
        }
    }
}
