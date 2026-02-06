//
//  PostsVC.swift
//  ActionPowerDevTest
//
//  Created by DavidChoi on 2/2/26.
//

import UIKit
import RxCocoa
import RxSwift
import SnapKit
import Then

final class PostsVC: UIViewController {
    // MARK: - UI Properties
    let titleLabel = UILabel().then {
        $0.font = .systemFont(ofSize: 14, weight: .bold)
        $0.textColor = .black
        $0.text = "📄 게시글 리스트"
    }
    let separatorView = UIView().then {
        $0.backgroundColor = .lightGray
    }
    let offlineBanner = UIView().then {
        $0.backgroundColor = .systemOrange
        $0.isHidden = true
    }
    let offlineLabel = UILabel().then {
        $0.font = .systemFont(ofSize: 11, weight: .medium)
        $0.textColor = .white
        $0.text = "🚫 오프라인"
        $0.textAlignment = .center
    }
    let tableView = UITableView().then {
        $0.register(PostsTableViewCell.self, forCellReuseIdentifier: "cell")
        $0.estimatedRowHeight = 40
        $0.rowHeight = UITableView.automaticDimension
        $0.backgroundColor = .clear
        $0.separatorStyle = .none
        $0.contentInsetAdjustmentBehavior = .never
    }
    let createButton = UIButton(type: .system).then {
        $0.setTitle("✍🏻 글쓰기", for: .normal)
        $0.titleLabel?.font = .systemFont(ofSize: 10, weight: .regular)
        $0.setTitleColor(.label, for: .normal)
        $0.backgroundColor = UIColor.systemGray6
        $0.layer.borderColor = UIColor.lightGray.cgColor
        $0.layer.borderWidth = 1
        $0.layer.cornerRadius = 10
        $0.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
    }
    let dashboardButton = UIButton(type: .system).then {
        $0.setTitle("📊 대시보드", for: .normal)
        $0.titleLabel?.font = .systemFont(ofSize: 10, weight: .regular)
        $0.setTitleColor(.label, for: .normal)
        $0.backgroundColor = UIColor.systemGray6
        $0.layer.borderColor = UIColor.lightGray.cgColor
        $0.layer.borderWidth = 1
        $0.layer.cornerRadius = 10
        $0.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
    }
    // MARK: - Properties
    var coordinator: PostsVCDelegate?
    let disposeBag = DisposeBag()
    var vm: PostVM?
    // VM-Input
    private let loadPageRelay = PublishRelay<Int>()
    private let refreshRelay = PublishRelay<Void>()
    // MARK: - LifeCycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bind()
    }
    // MARK: - Setup UI
    private func setupUI() {
        // self
        view.backgroundColor = .white
        // titleLabel
        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide.snp.top).inset(12)
            $0.left.equalToSuperview().inset(12)
            $0.right.equalToSuperview()
        }
        // separatorView
        view.addSubview(separatorView)
        separatorView.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(8)
            $0.left.right.equalToSuperview()
            $0.height.equalTo(1)
        }
        // offlineBanner
        view.addSubview(offlineBanner)
        offlineBanner.snp.makeConstraints {
            $0.top.equalTo(separatorView.snp.bottom)
            $0.left.right.equalToSuperview()
            $0.height.equalTo(0)
        }
        // offlineLabel
        offlineBanner.addSubview(offlineLabel)
        offlineLabel.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        // dashBoardButton
        view.addSubview(dashboardButton)
        dashboardButton.snp.makeConstraints {
            $0.centerY.equalTo(titleLabel)
            $0.right.equalToSuperview().inset(12)
        }
        // createButton
        view.addSubview(createButton)
        createButton.snp.makeConstraints {
            $0.centerY.equalTo(titleLabel)
            $0.right.equalTo(dashboardButton.snp.left).offset(-6)
        }
        // tableView
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(offlineBanner.snp.bottom).offset(4)
            $0.left.right.equalToSuperview().inset(12)
            $0.bottom.equalToSuperview()
        }
    }
    // MARK: - Bind
    private func bind() {
        bindView()
        bindNav()
        bindVM()
    }
    private func bindVM() {
        guard let vm = self.vm else { return }
        let input = PostVM.Input(
            loadPage: loadPageRelay.asObservable(),
            refresh: refreshRelay.asObservable()
        )
        let output = vm.transform(input: input)
        
        output.posts
            .drive(tableView.rx.items(cellIdentifier: "cell", cellType: PostsTableViewCell.self)) { index, post, cell in
                cell.configre(post)
            }
            .disposed(by: disposeBag)
        
        output.errorMessage
            .emit(with: self) { owner, message in
                let alert = UIAlertController(title: "에러", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "확인", style: .default))
                owner.present(alert, animated: true)
            }
            .disposed(by: disposeBag)
        
        // 네트워크 연결 상태 모니터링
        output.isConnected
            .drive(with: self) { owner, isConnected in
                UIView.animate(withDuration: 0.3) {
                    if isConnected {
                        owner.offlineBanner.isHidden = true
                        owner.offlineBanner.snp.updateConstraints {
                            $0.height.equalTo(0)
                        }
                    } else {
                        owner.offlineBanner.isHidden = false
                        owner.offlineBanner.snp.updateConstraints {
                            $0.height.equalTo(30)
                        }
                    }
                    owner.view.layoutIfNeeded()
                }
            }
            .disposed(by: disposeBag)
        
        loadPageRelay.accept(0)
    }
    private func bindView() {
        // 글쓰기 버튼 탭
        createButton.rx.tap
            .subscribe(with: self) { owner, _ in
                owner.coordinator?.moveToPostCreate()
            }
            .disposed(by: disposeBag)
        // 대시보드 버튼 탭
        dashboardButton.rx.tap
            .subscribe(with: self) { owner, _ in
                owner.coordinator?.moveToDashBoard()
            }
            .disposed(by: disposeBag)
        // 셀 선택 시 상세 화면으로 이동
        tableView.rx.modelSelected(Post.self)
            .subscribe(with: self) { owner, post in
                owner.coordinator?.moveToPostDetail(post: post)
            }
            .disposed(by: disposeBag)
    }
    private func bindNav() {
        
    }
    // MARK: - Fuctions
    /// 게시글 생성 후 호출되어 리스트를 새로고침
    func refreshPosts() {
        refreshRelay.accept(())
    }
}

protocol PostsVCDelegate {
    func moveToPostCreate()
    func moveToPostDetail(post: Post)
    func moveToDashBoard()
}
