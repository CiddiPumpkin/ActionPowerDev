//
//  NetworkMonitor.swift
//  ActionPowerDevTest
//
//  Created by DavidChoi on 2/6/26.
//

import Foundation
import Network
import RxSwift
import RxRelay

final class NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    let isConnected = BehaviorRelay<Bool>(value: true)
    
    init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            self?.isConnected.accept(connected)
            
            if connected {
                print("✅ 네트워크 연결됨")
            } else {
                print("⚠️ 네트워크 연결 끊김")
            }
        }
        
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
    
    deinit {
        stopMonitoring()
    }
}
