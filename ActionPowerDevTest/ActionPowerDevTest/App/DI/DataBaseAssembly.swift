//
//  DataBaseAssembly.swift
//  ActionPowerDevTest
//
//  Created by DavidChoi on 2/3/26.
//

import UIKit
import Swinject
import SwinjectAutoregistration

class DataBaseAssembly: Assembly {
    func assemble(container: Container) {
        // MARK: - DataSource
        container.register(DataBaseDataSourceType.self) { r in
            DataBaseDataSource()
        }.inObjectScope(.container)
    }
}
