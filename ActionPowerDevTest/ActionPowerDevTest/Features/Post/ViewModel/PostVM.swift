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
        /// 새로고침 트리거 (게시글 생성/수정/삭제 이후)
        let refresh: Observable<Void>
    }

    struct Output {
        let posts: Driver<[Post]>
        let isLoading: Driver<Bool>
        let errorMessage: Signal<String>
    }
    // MARK: - Properties
    private let repo: PostRepoType
    private let disposeBag = DisposeBag()
    
    // 현재 API에서 가져온 게시글들
    private let apiPostsRelay = BehaviorRelay<[Post]>(value: [])
    
    // MARK: - Initialize
    init(repo: PostRepoType) {
        self.repo = repo
    }
    // MARK: - Functions
    func transform(input: Input) -> Output {
        let loadingRelay = BehaviorRelay<Bool>(value: false)
        let errorRelay = PublishRelay<String>()
        let postsRelay = BehaviorRelay<[Post]>(value: [])

        // API에서 게시글 로드
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
            .subscribe(onNext: { [weak self] apiPosts in
                guard let self = self else { return }
                self.apiPostsRelay.accept(apiPosts)
                
                // API 게시글 + 로컬 게시글 병합
                let mergedPosts = self.mergeWithLocalPosts(apiPosts: apiPosts)
                postsRelay.accept(mergedPosts)
            })
            .disposed(by: disposeBag)
        
        // 새로고침 시 로컬 DB와 머지한 뒤 갱신
        input.refresh
            .subscribe(onNext: { [weak self] _ in
                guard let self = self else { return }
                let currentApiPosts = self.apiPostsRelay.value
                let mergedPosts = self.mergeWithLocalPosts(apiPosts: currentApiPosts)
                postsRelay.accept(mergedPosts)
            })
            .disposed(by: disposeBag)

        return Output(
            posts: postsRelay.asDriver(),
            isLoading: loadingRelay.asDriver(),
            errorMessage: errorRelay.asSignal()
        )
    }
    
    func createPost(title: String, body: String, userId: Int = 1) -> Single<Post> {
        return repo.createPost(title: title, body: body, userId: userId)
    }
    
    func updatePost(localId: String, title: String?, body: String?) -> Single<Post> {
        return repo.updatePost(localId: localId, title: title, body: body)
    }
    
    func deletePost(localId: String) -> Single<PostDeleteResponse> {
        return repo.deletePost(localId: localId)
    }
    /// API에서 가져온 게시글과 로컬 DB 게시글을 병합
    /// 로컬 DB 게시글이 최상단에 위치하도록 정렬
    func mergeWithLocalPosts(apiPosts: [Post]) -> [Post] {
        let localPostObjs = repo.getLocalPosts()
        let localPosts = localPostObjs.map { $0.toPost() }
        
        // 로컬 게시글의 serverId Set
        let localServerIds = Set(localPostObjs.compactMap { $0.serverId })
        // API 게시글 중 로컬에 없는 것만 필터링
        let filteredApiPosts = apiPosts.filter { !localServerIds.contains($0.id) }
        // 로컬 게시글(최신순) + API 게시글
        return localPosts + filteredApiPosts
    }
}
