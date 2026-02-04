//
//  PostsCoordinator.swift
//  ActionPowerDevTest
//
//  Created by DavidChoi on 2/3/26.
//

import Swinject
import SwinjectAutoregistration
import UIKit

class PostsCoordinator {
    var nav: UINavigationController
    var resolver: Resolver
    
    required init(nav: UINavigationController, resolver: Resolver) {
        self.nav = nav
        self.resolver = resolver
    }
    
    func start(animated: Bool) {
        if let vc = resolver.resolve(PostsVC.self) {
            nav.isNavigationBarHidden = true
            nav.setViewControllers([vc], animated: animated)
        }
    }
}
extension PostsCoordinator: PostsVCDelegate {
    
}
