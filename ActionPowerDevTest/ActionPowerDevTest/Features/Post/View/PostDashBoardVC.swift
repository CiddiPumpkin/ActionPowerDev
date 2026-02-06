//
//  PostDashBoardVC.swift
//  ActionPowerDevTest
//
//  Created by DavidChoi on 2/6/26.
//

import UIKit
import RxCocoa
import RxSwift
import RxRelay
import SnapKit
import Then

class PostDashBoardVC: UIViewController {
    // MARK: - UI Properties
    let titleLabel = UILabel().then {
        $0.font = .systemFont(ofSize: 14, weight: .bold)
        $0.textColor = .black
        $0.text = "📊 대시보드"
    }
    // MARK: - Properties
    var coordinator: PostDashBoardVCDelegate?
    let disposeBag = DisposeBag()
    var vm: PostVM?
    // MARK: - LifeCycle
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        setupUI()
        bind()
    }
    // MARK: - Setup UI
    private func setupUI() {
        // self
        view.backgroundColor = .white
    }
    // MARK: - Bind
    private func bind() {
        bindView()
        bindVM()
    }
    private func bindView() {
        
    }
    private func bindVM() {
        
    }
    // MARK: - Fuctions
    
}
protocol PostDashBoardVCDelegate {
    func moveToBack()
}
