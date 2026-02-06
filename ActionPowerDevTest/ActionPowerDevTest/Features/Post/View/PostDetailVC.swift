//
//  PostDetailVC.swift
//  ActionPowerDevTest
//
//  Created by DavidChoi on 2/4/26.
//

import UIKit
import RxCocoa
import RxSwift
import RxRelay
import SnapKit
import Then

class PostDetailVC: UIViewController {
    // MARK: - UI Properties
    let containerView = UIView().then {
        $0.backgroundColor = .white
        $0.layer.cornerRadius = 8
    }
    let titleTitleLabel = UILabel().then {
        $0.text = "제목"
        $0.font = .systemFont(ofSize: 14, weight: .semibold)
        $0.textColor = .label
    }
    let closeButton = UIButton(type: .system).then {
        $0.setImage(UIImage(systemName: "xmark"), for: .normal)
        $0.tintColor = .black
        $0.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    }
    let textFieldContainerView = UIView().then {
        $0.backgroundColor = .white
        $0.layer.borderColor = UIColor.systemGray4.cgColor
        $0.layer.borderWidth = 1
        $0.layer.cornerRadius = 8
    }
    let titleTextField = UITextField().then {
        $0.placeholder = "제목을 입력하세요"
        $0.borderStyle = .none
        $0.font = .systemFont(ofSize: 12)
        $0.backgroundColor = .clear
    }
    let contentTitleLabel = UILabel().then {
        $0.text = "내용"
        $0.font = .systemFont(ofSize: 14, weight: .semibold)
        $0.textColor = .label
    }
    let contentTextView = UITextView().then {
        $0.font = .systemFont(ofSize: 12)
        $0.layer.borderColor = UIColor.systemGray4.cgColor
        $0.layer.borderWidth = 1
        $0.layer.cornerRadius = 8
        $0.backgroundColor = .white
        $0.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
    }
    let placeholderLabel = UILabel().then {
        $0.text = "내용을 입력하세요"
        $0.font = .systemFont(ofSize: 12)
        $0.textColor = .systemGray3
    }
    let buttonStackView = UIStackView().then {
        $0.axis = .horizontal
        $0.distribution = .fillEqually
        $0.spacing = 12
    }
    let editButton = UIButton(type: .system).then {
        $0.setTitle("수정", for: .normal)
        $0.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        $0.setTitleColor(.systemBlue, for: .normal)
        $0.setTitleColor(.systemBlue.withAlphaComponent(0.5), for: .disabled)
        $0.backgroundColor = .systemGray6
        $0.layer.cornerRadius = 10
        $0.layer.borderWidth = 1
        $0.layer.borderColor = UIColor.systemGray4.cgColor
        $0.isEnabled = false
    }
    let deleteButton = UIButton(type: .system).then {
        $0.setTitle("삭제", for: .normal)
        $0.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
        $0.setTitleColor(.white, for: .normal)
        $0.backgroundColor = .systemRed
        $0.layer.cornerRadius = 10
    }
    
    // MARK: - Properties
    var coordinator: PostDetailVCDelegate?
    let disposeBag = DisposeBag()
    var vm: PostVM?
    
    // 전달받을 데이터
    var localId: String = ""
    var postTitle: String = ""
    var postBody: String = ""
    
    // MARK: - LifeCycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupInitialData()
        bind()
    }
    
    // MARK: - Setup UI
    private func setupUI() {
        // self
        view.backgroundColor = .white
        // containerView
        view.addSubview(containerView)
        containerView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        // titleTitleLabel
        containerView.addSubview(titleTitleLabel)
        titleTitleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(20)
            $0.left.right.equalToSuperview().inset(16)
            $0.height.equalTo(16)
        }
        // closeButton
        containerView.addSubview(closeButton)
        closeButton.snp.makeConstraints {
            $0.centerY.equalTo(titleTitleLabel.snp.centerY).offset(-8)
            $0.right.equalToSuperview().inset(12)
            $0.width.height.equalTo(28)
        }
        // textFieldContainerView
        containerView.addSubview(textFieldContainerView)
        textFieldContainerView.snp.makeConstraints {
            $0.top.equalTo(titleTitleLabel.snp.bottom).offset(8)
            $0.left.right.equalToSuperview().inset(16)
            $0.height.equalTo(44)
        }
        // titleTextField
        textFieldContainerView.addSubview(titleTextField)
        titleTextField.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8))
        }
        // contentTitleLabel
        containerView.addSubview(contentTitleLabel)
        contentTitleLabel.snp.makeConstraints {
            $0.top.equalTo(textFieldContainerView.snp.bottom).offset(16)
            $0.left.right.equalToSuperview().inset(16)
            $0.height.equalTo(16)
        }
        // contentTextView
        containerView.addSubview(contentTextView)
        contentTextView.snp.makeConstraints {
            $0.top.equalTo(contentTitleLabel.snp.bottom).offset(8)
            $0.left.right.equalToSuperview().inset(16)
        }
        // placeholderLabel
        contentTextView.addSubview(placeholderLabel)
        placeholderLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(8)
            $0.left.equalToSuperview().offset(8)
        }
        // buttonStackView
        buttonStackView.addArrangedSubview(editButton)
        buttonStackView.addArrangedSubview(deleteButton)
        containerView.addSubview(buttonStackView)
        buttonStackView.snp.makeConstraints {
            $0.top.equalTo(contentTextView.snp.bottom).offset(20)
            $0.left.right.equalToSuperview().inset(16)
            $0.height.equalTo(44)
            $0.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).inset(20)
        }
        
        // 키보드 높이만큼 bottom 조정
        NotificationCenter.default.rx.notification(UIResponder.keyboardWillShowNotification)
            .compactMap { $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect }
            .subscribe(onNext: { [weak self] keyboardFrame in
                self?.buttonStackView.snp.updateConstraints {
                    $0.bottom.equalTo(self!.view.safeAreaLayoutGuide.snp.bottom).inset(keyboardFrame.height + 20)
                }
                UIView.animate(withDuration: 0.3) { self?.view.layoutIfNeeded() }
            })
            .disposed(by: disposeBag)
        
        NotificationCenter.default.rx.notification(UIResponder.keyboardWillHideNotification)
            .subscribe(onNext: { [weak self] _ in
                self?.buttonStackView.snp.updateConstraints {
                    $0.bottom.equalTo(self!.view.safeAreaLayoutGuide.snp.bottom).inset(20)
                }
                UIView.animate(withDuration: 0.3) { self?.view.layoutIfNeeded() }
            })
            .disposed(by: disposeBag)
    }
    
    // MARK: - Setup Initial Data
    private func setupInitialData() {
        titleTextField.text = postTitle
        contentTextView.text = postBody
        placeholderLabel.isHidden = !postBody.isEmpty
    }
    
    // MARK: - Bind
    private func bind() {
        bindView()
        bindVM()
    }
    
    private func bindVM() {
        
    }
    
    private func bindView() {
        // 현재 입력값 비교하여 수정 버튼 활성화
        let isContentChanged = Observable.combineLatest(
            titleTextField.rx.text.orEmpty,
            contentTextView.rx.text.orEmpty
        )
        .map { [weak self] currentTitle, currentBody in
            guard let self = self else { return false }
            let titleChanged = currentTitle != self.postTitle
            let bodyChanged = currentBody != self.postBody
            let isNotEmpty = !currentTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                            !currentBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            
            return (titleChanged || bodyChanged) && isNotEmpty
        }
        .share(replay: 1)
        
        // 수정 버튼 상태 업데이트
        isContentChanged
            .subscribe(with: self) { owner, isChanged in
                owner.editButton.isEnabled = isChanged
                owner.editButton.backgroundColor = isChanged ? UIColor.systemBlue.withAlphaComponent(0.1) : UIColor.systemGray6
                owner.editButton.layer.borderColor = isChanged ? UIColor.systemBlue.cgColor : UIColor.systemGray4.cgColor
            }
            .disposed(by: disposeBag)
        
        // placeholder 처리
        contentTextView.rx.text.orEmpty
            .map { !$0.isEmpty }
            .bind(to: placeholderLabel.rx.isHidden)
            .disposed(by: disposeBag)
        
        // 닫기 버튼 탭
        closeButton.rx.tap
            .subscribe(with: self) { owner, _ in
                owner.dismiss(animated: true)
            }
            .disposed(by: disposeBag)
        
        // 수정 버튼 탭
        editButton.rx.tap
            .withLatestFrom(
                Observable.combineLatest(
                    titleTextField.rx.text.orEmpty,
                    contentTextView.rx.text.orEmpty
                )
            )
            .flatMapLatest { [weak self] data -> Observable<Post> in
                guard let self = self, let vm = self.vm else {
                    return .empty()
                }
                let (title, body) = data
                
                // 로딩 표시
                self.editButton.isEnabled = false
                
                return vm.updatePost(localId: self.localId, title: title, body: body)
                    .asObservable()
                    .catch { error in
                        // 에러 처리
                        self.showErrorAlert(message: error.localizedDescription)
                        return .empty()
                    }
            }
            .subscribe(with: self) { owner, post in
                print("게시글 수정 성공: \(post)")
                owner.coordinator?.didUpdatePost()
                owner.showSuccessAlert(message: "게시글이 수정되었습니다.") {
                    owner.dismiss(animated: true)
                }
            }
            .disposed(by: disposeBag)
        
        // 삭제 버튼 탭
        deleteButton.rx.tap
            .subscribe(with: self) { owner, _ in
                // 삭제 확인 알림
                let alert = UIAlertController(
                    title: "게시물 삭제",
                    message: "정말 이 게시물을 삭제하시겠습니까?",
                    preferredStyle: .alert
                )
                
                alert.addAction(UIAlertAction(title: "취소", style: .cancel))
                alert.addAction(UIAlertAction(title: "삭제", style: .destructive) { [weak owner] _ in
                    guard let owner = owner, let vm = owner.vm else { return }
                    
                    // 로딩 표시
                    owner.deleteButton.isEnabled = false
                    
                    vm.deletePost(localId: owner.localId)
                        .asObservable()
                        .catch { error in
                            // 에러 처리
                            owner.showDeleteErrorAlert(message: error.localizedDescription)
                            return .empty()
                        }
                        .subscribe(onNext: { response in
                            print("게시글 삭제 성공: \(response)")
                            owner.coordinator?.didDeletePost()
                            owner.showSuccessAlert(message: "게시글이 삭제되었습니다.") {
                                owner.dismiss(animated: true)
                            }
                        })
                        .disposed(by: owner.disposeBag)
                })
                
                owner.present(alert, animated: true)
            }
            .disposed(by: disposeBag)
    }
    
    // MARK: - Functions
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "오류", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default) { [weak self] _ in
            self?.editButton.isEnabled = true
            self?.editButton.setTitle("수정", for: .normal)
        })
        present(alert, animated: true)
    }
    
    private func showDeleteErrorAlert(message: String) {
        let alert = UIAlertController(title: "오류", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default) { [weak self] _ in
            self?.deleteButton.isEnabled = true
        })
        present(alert, animated: true)
    }
    
    private func showSuccessAlert(message: String, completion: @escaping () -> Void) {
        let alert = UIAlertController(title: "성공", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in
            completion()
        })
        present(alert, animated: true)
    }
}

protocol PostDetailVCDelegate {
    func didUpdatePost() // 게시글 수정 완료
    func didDeletePost() // 게시글 삭제 완료
}

