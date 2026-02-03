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
        container.register(MainCoordinator.self) { r in
            let nav = r ~> (UINavigationController.self)
            return MainCoordinator(nav: nav, resolver: r)
        }
        // MARK: - VC
        container.register(MainVC.self) { r in
            let vc = MainVC()
            return vc
        }
        // MARK: - Navigation
        container.register(UINavigationController.self) { _ in
            self.navController
        }
    }
}
