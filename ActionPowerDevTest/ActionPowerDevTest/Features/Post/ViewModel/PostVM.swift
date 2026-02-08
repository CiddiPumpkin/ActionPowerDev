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
        /// 페이지네이션 트리거
        let loadNextPage: Observable<Void>
    }
    struct Output {
        let posts: Driver<[Post]>
        let isLoading: Driver<Bool>
        let errorMessage: Signal<String>
        let isConnected: Driver<Bool>
        let syncCompleted: Signal<SyncResult>
    }
    // MARK: - Properties
    private let repo: PostRepoType
    private let networkMonitor: NetworkMonitor
    private let disposeBag = DisposeBag()
    
    // 현재 API에서 가져온 게시글들
    private let apiPostsRelay = BehaviorRelay<[Post]>(value: [])
    
    // 페이지네이션
    private var currentPage = 0
    private var canLoadMore = true
    private let pageSize = 10
    
    // 동기화 결과
    private let syncResultRelay = PublishRelay<SyncResult>()
    
    // MARK: - Initialize
    init(repo: PostRepoType, networkMonitor: NetworkMonitor) {
        self.repo = repo
        self.networkMonitor = networkMonitor
        
        setupNetworkMonitoring()
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        networkMonitor.isConnected
            .distinctUntilChanged()
            .filter { $0 }
            .skip(1)
            .flatMapLatest { [weak self] _ -> Observable<SyncResult> in
                guard let self = self else { return .empty() }
                
                print("네트워크 연결됨 - 대기 중인 게시글 동기화 시작")
                
                return self.repo.syncPendingPosts()
                    .asObservable()
                    .catch { error in
                        print("동기화 실패:", error)
                        return .empty()
                    }
            }
            .subscribe(onNext: { [weak self] result in
                print("동기화 완료 - 성공: \(result.success), 실패: \(result.failed)")
                self?.syncResultRelay.accept(result)
            })
            .disposed(by: disposeBag)
    }
    // MARK: - Functions
    func transform(input: Input) -> Output {
        let loadingRelay = BehaviorRelay<Bool>(value: false)
        let errorRelay = PublishRelay<String>()
        let postsRelay = BehaviorRelay<[Post]>(value: [])

        input.loadPage
            .do(onNext: { _ in 
                loadingRelay.accept(true)
            })
            .flatMapLatest { [weak self] page -> Observable<[Post]> in
                guard let self else { return .empty() }
                
                self.currentPage = 0
                self.canLoadMore = true

                return self.repo.getPosts(page: page, size: self.pageSize)
                    .map { $0.posts }
                    .asObservable()
                    .catch { error in
                        errorRelay.accept(error.localizedDescription)
                        return .empty()
                    }
            }
            .do(onNext: { _ in loadingRelay.accept(false) })
            .subscribe(onNext: { [weak self] apiPosts in
                guard let self = self else { return }
                self.canLoadMore = apiPosts.count >= self.pageSize
                self.apiPostsRelay.accept(apiPosts)
                
                // API 게시글 + 로컬 게시글 병합
                let mergedPosts = self.mergeWithLocalPosts(apiPosts: apiPosts)
                postsRelay.accept(mergedPosts)
            })
            .disposed(by: disposeBag)
        
        // 페이지네이션
        input.loadNextPage
            .withLatestFrom(networkMonitor.isConnected)
            .filter { [weak self] isConnected in
                guard let self = self else { return false }
                return isConnected && self.canLoadMore && !loadingRelay.value
            }
            .do(onNext: { [weak self] _ in
                loadingRelay.accept(true)
                self?.currentPage += 1
            })
            .flatMapLatest { [weak self] _ -> Observable<[Post]> in
                guard let self = self else { return .empty() }
                
                return self.repo.getPosts(page: self.currentPage, size: self.pageSize)
                    .map { $0.posts }
                    .asObservable()
                    .catch { error in
                        errorRelay.accept(error.localizedDescription)
                        return .empty()
                    }
            }
            .do(onNext: { _ in loadingRelay.accept(false) })
            .subscribe(onNext: { [weak self] newPosts in
                guard let self = self else { return }
                
                // 더 이상 로드할 게시글이 없으면 플래그 변경
                self.canLoadMore = newPosts.count >= self.pageSize
                
                // 기존 API 게시글에 새 게시글 추가
                let currentApiPosts = self.apiPostsRelay.value
                let updatedApiPosts = currentApiPosts + newPosts
                self.apiPostsRelay.accept(updatedApiPosts)
                
                // API 게시글 + 로컬 게시글 병합
                let mergedPosts = self.mergeWithLocalPosts(apiPosts: updatedApiPosts)
                postsRelay.accept(mergedPosts)
                
                print("페이지 \(self.currentPage) 로드 완료 - 새로 \(newPosts.count)개, 총 \(updatedApiPosts.count)개")
            })
            .disposed(by: disposeBag)
        
        // 새로고침 시 로컬 DB와 머지한 뒤 갱신
        input.refresh
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                guard let self = self else { return }
                print("refresh 호출됨")
                let currentApiPosts = self.apiPostsRelay.value
                let mergedPosts = self.mergeWithLocalPosts(apiPosts: currentApiPosts)
                print("병합 완료 - 총 \(mergedPosts.count)개")
                postsRelay.accept(mergedPosts)
            })
            .disposed(by: disposeBag)

        return Output(
            posts: postsRelay.asDriver(),
            isLoading: loadingRelay.asDriver(),
            errorMessage: errorRelay.asSignal(),
            isConnected: networkMonitor.isConnected.asDriver(onErrorJustReturn: true),
            syncCompleted: syncResultRelay.asSignal()
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
    
    func getDashboardStats() -> DashboardStats {
        let localPosts = repo.getLocalPosts()
        let apiPosts = apiPostsRelay.value
        
        print("getDashboardStats - 로컬: \(localPosts.count)개, API: \(apiPosts.count)개")
        
        // 전체 게시글 = 로컬 + API (중복 제거)
        let mergedPosts = mergeWithLocalPosts(apiPosts: apiPosts)
        
        // 오프라인 생성 게시글 (오프라인 생성)
        let localOnlyPosts = localPosts.filter { $0.syncStatus == .localOnly }
        
        // 동기화 필요 게시글
        let needSyncPosts = localPosts.filter { $0.syncStatus == .needSync }
        
        // 최근 수정/추가된 게시글 (로컬에서 생성/수정한 것만 최신 5개)
        // API에서 가져온 것(serverId만 있고 로컬 수정 없음)은 제외
        let recentPosts = localPosts
            .map { $0.toPost() }
            .prefix(5)
        
        print("통계 - 전체: \(mergedPosts.count), 로컬전용: \(localOnlyPosts.count), 동기화필요: \(needSyncPosts.count), 최근: \(recentPosts.count)")
        
        return DashboardStats(
            totalCount: mergedPosts.count,
            localOnlyCount: localOnlyPosts.count,
            needSyncCount: needSyncPosts.count,
            recentPosts: Array(recentPosts)
        )
    }
    
    /// API에서 가져온 게시글과 로컬 DB 게시글을 병합
    /// 로컬 DB 게시글이 최상단에 위치하도록 정렬
    func mergeWithLocalPosts(apiPosts: [Post]) -> [Post] {
        let localPostObjs = repo.getLocalPosts()
        let localPosts = localPostObjs.map { $0.toPost() }
        
        print("mergeWithLocalPosts - 로컬: \(localPosts.count)개, API: \(apiPosts.count)개")
        
        // 로컬 게시글의 상태 로그
        for (index, post) in localPosts.enumerated() {
            print("  [\(index)] localId: \(post.localId ?? "nil"), serverId: \(post.id), syncStatus: \(post.syncStatus?.rawValue ?? "nil"), title: \(post.title)")
        }
        
        // 로컬 게시글의 serverId Set
        let localServerIds = Set(localPostObjs.compactMap { $0.serverId })
        
        // API 게시글 필터링
        let filteredApiPosts = apiPosts.filter { post in
            let notInLocal = !localServerIds.contains(post.id)
            let notDeleted = !repo.isDeleted(serverId: post.id)
            
            if !notDeleted {
                print("삭제된 게시글 필터링 - serverId: \(post.id), title: \(post.title)")
            }
            
            return notInLocal && notDeleted
        }
        
        // 로컬 게시글(최신순) + API 게시글
        return localPosts + filteredApiPosts
    }
}
