//
//  PostCreateVC.swift
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

class PostCreateVC: UIViewController {
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
    let cancelButton = UIButton(type: .system).then {
        $0.setTitle("취소", for: .normal)
        $0.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        $0.setTitleColor(.systemRed, for: .normal)
        $0.backgroundColor = .systemGray6
        $0.layer.cornerRadius = 10
        $0.layer.borderWidth = 1
        $0.layer.borderColor = UIColor.systemGray4.cgColor
    }
    let saveButton = UIButton(type: .system).then {
        $0.setTitle("저장", for: .normal)
        $0.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
        $0.setTitleColor(.white, for: .normal)
        $0.setTitleColor(.white.withAlphaComponent(0.5), for: .disabled)
        $0.backgroundColor = .systemBlue
        $0.layer.cornerRadius = 10
        $0.isEnabled = false
    }
    // MARK: - Properties
    var coordinator: PostCreateVCDelegate?
    let disposeBag = DisposeBag()
    var vm: PostVM?
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
        buttonStackView.addArrangedSubview(cancelButton)
        buttonStackView.addArrangedSubview(saveButton)
        containerView.addSubview(buttonStackView)
        buttonStackView.snp.makeConstraints {
            $0.top.equalTo(contentTextView.snp.bottom).offset(20)
            $0.left.right.equalToSuperview().inset(16)
            $0.height.equalTo(30)
            $0.bottom.equalToSuperview().inset(20)
        }
    }
    
    // MARK: - Bind
    private func bind() {
        bindView()
        bindVM()
    }
    
    private func bindVM() {
        
    }
    
    private func bindView() {
        // 제목과 내용이 모두 입력되었을 때만 저장 버튼 활성화
        let isFormValid = Observable.combineLatest(
            titleTextField.rx.text.orEmpty,
            contentTextView.rx.text.orEmpty
        )
        .map { title, content in
            return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        .share(replay: 1)
        
        isFormValid
            .bind(to: saveButton.rx.isEnabled)
            .disposed(by: disposeBag)
        
        // 저장 버튼 활성화 상태에 따라 배경색 변경
        isFormValid
            .map { $0 ? UIColor.systemBlue : UIColor.systemGray4 }
            .bind(to: saveButton.rx.backgroundColor)
            .disposed(by: disposeBag)
        
        // placeholder 처리
        contentTextView.rx.text.orEmpty
            .map { !$0.isEmpty }
            .bind(to: placeholderLabel.rx.isHidden)
            .disposed(by: disposeBag)
        
        // 취소 버튼 탭
        cancelButton.rx.tap
            .subscribe(with: self) { owner, _ in
                owner.dismiss(animated: true)
            }
            .disposed(by: disposeBag)
        closeButton.rx.tap
            .subscribe(with: self) { owner, _ in
                owner.dismiss(animated: true)
            }
            .disposed(by: disposeBag)
        
        // 저장 버튼 탭
        saveButton.rx.tap
            .withLatestFrom(
                Observable.combineLatest(
                    titleTextField.rx.text.orEmpty,
                    contentTextView.rx.text.orEmpty
                )
            )
            .subscribe(with: self) { owner, data in
                let (title, content) = data
                
                owner.dismiss(animated: true)
            }
            .disposed(by: disposeBag)
    }
    // MARK: - Functions
    
}

protocol PostCreateVCDelegate {
}
