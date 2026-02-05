//
//  PostVM.swift
//  ActionPowerDevTest
//
//  Created by DavidChoi on 2/3/26.
//

import Foundation
import RxSwift
import RxCocoa

final class PostVM {
    // MARK: - Input/Output
    struct Input {
        /// page: 0부터
        let loadPage: Observable<Int>
    }

    struct Output {
        let posts: Driver<[Post]>
        let isLoading: Driver<Bool>
        let errorMessage: Signal<String>
    }
    // MARK: - Properties
    private let repo: PostRepoType
    private let disposeBag = DisposeBag()
    // MARK: - Initialize
    init(repo: PostRepoType) {
        self.repo = repo
    }
    // MARK: - Functions
    func transform(input: Input) -> Output {
        let loadingRelay = BehaviorRelay<Bool>(value: false)
        let errorRelay = PublishRelay<String>()
        let postsRelay = PublishRelay<[Post]>()

        input.loadPage
            .do(onNext: { _ in loadingRelay.accept(true) })
            .flatMapLatest { [weak self] page -> Observable<[Post]> in
                guard let self else { return .empty() }

                return self.repo.getPosts(page: page, size: 10)
                    .map { $0.posts }
                    .asObservable()
                    .catch { error in
                        errorRelay.accept(error.localizedDescription)
                        return .empty()
                    }
            }
            .do(onNext: { _ in loadingRelay.accept(false) },
                onError: { _ in loadingRelay.accept(false) },
                onCompleted: { loadingRelay.accept(false) })
            .bind(to: postsRelay)
            .disposed(by: disposeBag)

        return Output(
            posts: postsRelay.asDriver(onErrorDriveWith: .empty()),
            isLoading: loadingRelay.asDriver(),
            errorMessage: errorRelay.asSignal()
        )
    }
    func createPost(title: String, body: String, userId: Int = 1) -> Single<Post> {
        return repo.createPost(title: title, body: body, userId: userId)
    }
}
