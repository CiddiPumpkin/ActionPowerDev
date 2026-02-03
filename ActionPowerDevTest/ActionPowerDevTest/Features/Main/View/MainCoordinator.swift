//
//  MainCoordinator.swift
//  ActionPowerDevTest
//
//  Created by infit on 2/3/26.
//

import Swinject
import SwinjectAutoregistration
import UIKit

class MainCoordinator {
    var nav: UINavigationController
    var resolver: Resolver
    
    required init(nav: UINavigationController, resolver: Resolver) {
        self.nav = nav
        self.resolver = resolver
    }
    
    func start(animated: Bool) {
        if let vc = resolver.resolve(MainVC.self) {
            nav.isNavigationBarHidden = true
            nav.setViewControllers([vc], animated: animated)
        }
    }
}
