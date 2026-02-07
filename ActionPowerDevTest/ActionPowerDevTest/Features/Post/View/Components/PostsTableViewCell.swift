//
//  PostsTableViewCell.swift
//  ActionPowerDevTest
//
//  Created by DavidChoi on 2/4/26.
//


import UIKit
import RxSwift
import RxCocoa
import Then
import SnapKit

class PostsTableViewCell: UITableViewCell {
    // MARK: - UI Properties
    let containerView = UIView().then {
        $0.layer.cornerRadius = 12
        $0.layer.borderWidth = 1
        $0.layer.borderColor = UIColor.lightGray.withAlphaComponent(0.7).cgColor
    }
    let titleLabel = UILabel().then {
        $0.font = .systemFont(ofSize: 12, weight: .semibold)
        $0.textColor = .black
        $0.numberOfLines = 0
    }
    let bodyLabel = UILabel().then {
        $0.font = .systemFont(ofSize: 10, weight: .regular)
        $0.textColor = .black
        $0.numberOfLines = 0
    }
    let syncStatusLabel = UILabel().then {
        $0.font = .systemFont(ofSize: 9, weight: .medium)
        $0.textColor = .white
        $0.backgroundColor = .systemOrange
        $0.textAlignment = .center
        $0.layer.cornerRadius = 8
        $0.layer.masksToBounds = true
        $0.text = "연동 필요"
        $0.isHidden = true
    }
    // MARK: - Properties
    var cellDisposeBag = DisposeBag()
    // MARK: - Initialize
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func prepareForReuse() {
        super.prepareForReuse()
        cellDisposeBag = DisposeBag()
    }
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        // Configure the view for the selected state
    }
    // MARK: - Setup UI
    private func setupUI() {
        // self
        selectionStyle = .none
        // containerView
        contentView.addSubview(containerView)
        containerView.snp.makeConstraints {
            $0.left.top.right.equalToSuperview()
            $0.bottom.equalToSuperview().inset(8)
        }
        // syncStatusLabel
        containerView.addSubview(syncStatusLabel)
        syncStatusLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(8)
            $0.right.equalToSuperview().inset(8)
            $0.height.equalTo(20)
            $0.width.equalTo(60)
        }
        // titleLabel
        containerView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().inset(8)
            $0.left.equalToSuperview().inset(12)
            $0.right.equalTo(syncStatusLabel.snp.left).offset(-8)
        }
        // bodyLabel
        containerView.addSubview(bodyLabel)
        bodyLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(4)
            $0.left.right.equalToSuperview().inset(12)
            $0.bottom.equalToSuperview().inset(8)
        }
    }
    // MARK: - Configure
    func configre(_ post: Post) {
        titleLabel.text = post.title
        bodyLabel.text = post.body
        
        if let syncStatus = post.syncStatus {
            switch syncStatus {
            case .needSync:
                syncStatusLabel.isHidden = false
                syncStatusLabel.backgroundColor = .systemOrange
                syncStatusLabel.text = "연동 필요"
            case .localOnly:
                syncStatusLabel.isHidden = false
                syncStatusLabel.backgroundColor = .systemGray
                syncStatusLabel.text = "오프라인 생성"
            case .fail:
                syncStatusLabel.isHidden = false
                syncStatusLabel.backgroundColor = .systemRed
                syncStatusLabel.text = "동기화 실패"
            case .sync:
                syncStatusLabel.isHidden = true
            }
        } else {
            syncStatusLabel.isHidden = true
        }
    }
}
