//
//  MainVC.swift
//  ActionPowerDevTest
//
//  Created by DavidChoi on 2/2/26.
//

import UIKit
import RxCocoa
import RxSwift
import SnapKit

final class MainVC: UIViewController {
    // MARK: - UI Properties
    
    // MARK: - Properties
    var coordinator: MainCoordinator?
    let disposeBag = DisposeBag()
    // MARK: - LifeCycle
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        setupUI()
        bind()
    }
    // MARK: - Setup UI
    private func setupUI() {
        view.backgroundColor = .systemBackground

        let titleLabel = UILabel()
        titleLabel.text = "Main..."
        titleLabel.font = .boldSystemFont(ofSize: 22)
        titleLabel.textColor = .label
        view.addSubview(titleLabel)

        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
    // MARK: - Bind
    private func bind() {
        bindVM()
        bindView()
        bindNav()
    }
    private func bindVM() {
        
    }
    private func bindView() {
        
    }
    private func bindNav() {
        
    }
    // MARK: - Fuctions
    
}

protocol MainVCDelegate {
}
