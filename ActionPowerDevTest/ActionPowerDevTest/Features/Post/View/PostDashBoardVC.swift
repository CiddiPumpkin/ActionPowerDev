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
    let statsStackView = UIStackView().then {
        $0.axis = .vertical
        $0.spacing = 12
        $0.distribution = .fillEqually
    }
    let totalCountCard = StatCardView(title: "전체 게시글", icon: "doc.text.fill", color: .systemBlue)
    let localOnlyCard = StatCardView(title: "오프라인 생성", icon: "icloud.slash.fill", color: .systemOrange)
    let needSyncCard = StatCardView(title: "동기화 필요", icon: "arrow.triangle.2.circlepath", color: .systemRed)
    
    // 최근 게시글
    let recentTitleLabel = UILabel().then {
        $0.font = .systemFont(ofSize: 14, weight: .semibold)
        $0.textColor = .black
        $0.text = "📝 최근 수정/추가된 게시글"
    }
    let recentTableView = UITableView().then {
        $0.register(PostsTableViewCell.self, forCellReuseIdentifier: "cell")
        $0.rowHeight = UITableView.automaticDimension
        $0.estimatedRowHeight = 40
        $0.separatorStyle = .none
    }
    // MARK: - Properties
    var coordinator: PostDashBoardVCDelegate?
    let disposeBag = DisposeBag()
    var vm: PostVM?
    
    private let statsRelay = BehaviorRelay<DashboardStats?>(value: nil)
    private let loadPageRelay = PublishRelay<Int>()
    private let refreshRelay = PublishRelay<Void>()
    // MARK: - LifeCycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bind()
        // loadStats()는 API 로드 후 자동 호출됨
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshRelay.accept(()) // API 새로고침
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
        // statsStackView
        statsStackView.addArrangedSubview(totalCountCard)
        statsStackView.addArrangedSubview(localOnlyCard)
        statsStackView.addArrangedSubview(needSyncCard)
        view.addSubview(statsStackView)
        statsStackView.snp.makeConstraints {
            $0.top.equalTo(separatorView.snp.bottom).offset(12)
            $0.left.right.equalToSuperview().inset(16)
        }
        totalCountCard.snp.makeConstraints {
            $0.height.equalTo(60)
        }
        // recentTitleLabel
        view.addSubview(recentTitleLabel)
        recentTitleLabel.snp.makeConstraints {
            $0.top.equalTo(statsStackView.snp.bottom).offset(24)
            $0.left.right.equalToSuperview().inset(16)
        }
        // recentTableView
        view.addSubview(recentTableView)
        recentTableView.snp.makeConstraints {
            $0.top.equalTo(recentTitleLabel.snp.bottom).offset(8)
            $0.left.right.equalToSuperview().inset(16)
            $0.bottom.equalToSuperview().inset(20)
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
        guard let vm = vm else { return }
        
        // API 데이터 먼저 로드
        let input = PostVM.Input(
            loadPage: loadPageRelay.asObservable(),
            refresh: refreshRelay.asObservable()
        )
        let output = vm.transform(input: input)
        
        // API 로드 완료 후 통계 업데이트
        output.posts
            .drive(onNext: { [weak self] posts in
                print("API 로드 완료 - \(posts.count)개")
                self?.loadStats()
            })
            .disposed(by: disposeBag)
        
        // 통계 데이터 바인딩
        statsRelay
            .compactMap { $0 }
            .subscribe(onNext: { [weak self] stats in
                self?.totalCountCard.updateCount(stats.totalCount)
                self?.localOnlyCard.updateCount(stats.localOnlyCount)
                self?.needSyncCard.updateCount(stats.needSyncCount)
            })
            .disposed(by: disposeBag)
        
        // 최근 게시글 테이블뷰 바인딩
        statsRelay
            .compactMap { $0?.recentPosts }
            .bind(to: recentTableView.rx.items(cellIdentifier: "cell", cellType: PostsTableViewCell.self)) { index, post, cell in
                cell.configre(post)
            }
            .disposed(by: disposeBag)
        
        // 초기 API 로드 실행
        loadPageRelay.accept(0)
    }
    
    // MARK: - Functions
    
    private func loadStats() {
        guard let vm = vm else { return }
        let stats = vm.getDashboardStats()
        statsRelay.accept(stats)
    }
}

protocol PostDashBoardVCDelegate {
    func moveToBack()
}
// MARK: - StatCardView
class StatCardView: UIView {
    private let iconImageView = UIImageView().then {
        $0.contentMode = .scaleAspectFit
        $0.tintColor = .white
    }
    private let titleLabel = UILabel().then {
        $0.font = .systemFont(ofSize: 18, weight: .regular)
        $0.textColor = .white
    }
    private let countLabel = UILabel().then {
        $0.font = .systemFont(ofSize: 18, weight: .semibold)
        $0.textColor = .white
        $0.text = "0"
    }
    
    init(title: String, icon: String, color: UIColor) {
        super.init(frame: .zero)
        
        backgroundColor = color
        layer.cornerRadius = 12
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.1
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        
        titleLabel.text = title
        iconImageView.image = UIImage(systemName: icon)
        
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private func setupUI() {
        addSubview(iconImageView)
        iconImageView.snp.makeConstraints {
            $0.left.equalToSuperview().inset(16)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(24)
        }
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.left.equalTo(iconImageView.snp.right).offset(12)
            $0.centerY.equalToSuperview()
        }
        addSubview(countLabel)
        countLabel.snp.makeConstraints {
            $0.right.equalToSuperview().inset(16)
            $0.centerY.equalToSuperview()
        }
    }
    func updateCount(_ count: Int) {
        countLabel.text = "\(count)"
    }
}

