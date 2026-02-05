//
//  PostCoordinator.swift
//  ActionPowerDevTest
//
//  Created by DavidChoi on 2/3/26.
//

import Swinject
import SwinjectAutoregistration
import UIKit

class PostCoordinator {
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
extension PostCoordinator: PostsVCDelegate {
    func moveToPostCreate() {
        guard let vc = resolver.resolve(PostCreateVC.self) else { return }

        vc.modalPresentationStyle = .pageSheet

        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.preferredCornerRadius = 16
            sheet.prefersGrabberVisible = true
        }

        nav.present(vc, animated: true)
    }
    func moveToPostDetail(post: Post) {}
}
extension PostCoordinator: PostCreateVCDelegate {
}

