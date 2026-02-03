//
//  MainAssembly.swift
//  ActionPowerDevTest
//
//  Created by DavidChoi on 2/3/26.
//
import UIKit
import Swinject
import SwinjectAutoregistration

class MainAssembly: Assembly {
    private let navController: UINavigationController
    
    init(navController: UINavigationController) {
        self.navController = navController
    }
    func assemble(container: Container) {
        // MARK: - Coordinator
        container.register(PostsCoordinator.self) { r in
            let nav = r ~> (UINavigationController.self)
            return PostsCoordinator(nav: nav, resolver: r)
        }
        // MARK: - VC
        container.register(PostsVC.self) { r in
            let vc = PostsVC()
            return vc
        }
        // MARK: - Navigation
        container.register(UINavigationController.self) { _ in
            self.navController
        }
    }
}
