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
    let tableView = UITableView().then {
        $0.register(PostsTableViewCell.self, forCellReuseIdentifier: "cell")
        $0.estimatedRowHeight = 52
        $0.backgroundColor = .clear
        $0.separatorStyle = .none
    }
    // MARK: - Properties
    var coordinator: PostsVCDelegate?
    let disposeBag = DisposeBag()
    var vm: PostsVM?
    // VM-Input
    private let loadPageRelay = PublishRelay<Int>()
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
        // tableView
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.left.top.right.bottom.equalToSuperview()
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
        let input = PostsVM.Input(loadPage: loadPageRelay.asObservable())
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
        
        loadPageRelay.accept(0)
    }
    private func bindView() {
        
    }
    private func bindNav() {
        
    }
    // MARK: - Fuctions
    
}

protocol PostsVCDelegate {
}
