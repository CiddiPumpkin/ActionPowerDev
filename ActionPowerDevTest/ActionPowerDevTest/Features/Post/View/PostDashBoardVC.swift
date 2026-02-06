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
    let backButton = UIButton(type: .system).then {
        $0.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        $0.tintColor = .black
        $0.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    }
    let titleLabel = UILabel().then {
        $0.font = .systemFont(ofSize: 14, weight: .bold)
        $0.textColor = .black
        $0.text = "📊 대시보드"
    }
    let separatorView = UIView().then {
        $0.backgroundColor = .lightGray
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
        // backButton
        view.addSubview(backButton)
        backButton.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide.snp.top).inset(12)
            $0.left.equalToSuperview().inset(8)
            $0.width.height.equalTo(28)
        }
        // titleLabel
        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.centerY.equalTo(backButton)
            $0.left.equalTo(backButton.snp.right).offset(4)
            $0.right.equalToSuperview().inset(12)
        }
        // separatorView
        view.addSubview(separatorView)
        separatorView.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(8)
            $0.left.right.equalToSuperview()
            $0.height.equalTo(1)
        }
    }
    // MARK: - Bind
    private func bind() {
        bindView()
        bindVM()
    }
    private func bindView() {
        // 뒤로가기 버튼 탭
        backButton.rx.tap
            .subscribe(with: self) { owner, _ in
                owner.coordinator?.moveToBack()
            }
            .disposed(by: disposeBag)
    }
    private func bindVM() {
        
    }
    // MARK: - Fuctions
    
}
protocol PostDashBoardVCDelegate {
    func moveToBack()
}
