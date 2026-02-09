# ActionPowerDev_최형석
ActionPower Dev Test

## 아키텍처
### MVVM + Repository Pattern
```
View (ViewController)
  ↓
ViewModel (PostVM)
  ↓
Repository (PostRepo)
  ↓
DataSources (PostAPI, Database)
```

### 구성 요소

#### PostVM (ViewModel)
- UI 상태 관리 및 Input/Output 변환
- 페이지네이션 로직 처리
- API 응답과 로컬 DB 게시글 병합
- 네트워크 상태 모니터링 및 자동 동기화 트리거

#### PostRepo (Repository)
- 비즈니스 로직 처리 계층
- API와 로컬 DB 사이의 중재 역할
- 온/오프라인 상황에 따른 CRUD 시퀀스 결정
- 동기화 로직 구현

#### DataSources
- **PostAPIDataSource**: 서버 API 통신
- **DataBaseDataSource**: Realm 기반 로컬 저장소

### Swinject 기반 DI 컨테이너
프로젝트는 Swinject를 사용한 **Assembly Pattern**으로 의존성을 관리합니다.

### Assembly 구조
```
SceneDelegate
  ↓
Assembler
  ↓
├── DataBaseAssembly (로컬 DB)
├── PostAPIAssembly (네트워크 & API)
└── PostAssembly (ViewModel & ViewController)
```

## 동작 시나리오

### 1. 온라인 상태에서 게시글 생성
```
1. 사용자가 게시글 작성 → VM.createPost() 호출
2. Repo → API 생성 요청
3. 성공 시: 서버 응답을 로컬 DB에 저장 (syncStatus: .sync)
4. 실패 시: 로컬 전용으로 저장 (syncStatus: .localOnly, pendingStatus: .create)
5. UI 즉시 업데이트
```

### 2. 오프라인 상태에서 게시글 생성
```
1. 사용자가 게시글 작성 → VM.createPost() 호출
2. Repo → API 요청 실패 (네트워크 에러)
3. catch 블록에서 로컬 전용으로 저장 (syncStatus: .localOnly, pendingStatus: .create)
4. UI에 즉시 반영
5. 온라인 전환 시 자동 동기화
```

### 3. 서버 게시글 수정
```
1. 사용자가 기존 게시글 수정 → VM.updatePost() 호출
2. Repo가 게시글 상태 확인 (serverId 존재 여부, syncStatus 등)
3. 온라인: API 수정 요청 → 성공 시 로컬 DB 업데이트
4. 오프라인 또는 실패: 로컬 DB에 pendingStatus: .update 마킹
5. UI 즉시 업데이트
```

### 4. 앱 생성 게시글 수정
```
앱에서 생성한 게시글(createdLocally: true)은 특별 처리:
- 온라인 상태: 로컬 DB만 업데이트 (서버 재전송 불필요)
- 오프라인 상태: pendingStatus: .update로 마킹 → 온라인 전환 시 동기화
```

### 5. 게시글 삭제
```
1. 사용자가 게시글 삭제 → VM.deletePost() 호출
2. Repo가 게시글 유형 판단:
   - 로컬 전용 게시글: isDeleted 플래그만 설정
   - 서버 게시글: API 삭제 요청 → 성공 시 로컬 DB에서 제거
3. 실패 시: pendingStatus: .delete 마킹
4. deletedServerIds에 추가하여 향후 조회 시 필터링
```

### 6. 온라인 전환 시 자동 동기화
```
1. NetworkMonitor가 네트워크 연결 감지
2. PostVM의 setupNetworkMonitoring()에서 감지
3. Repo.syncPendingPosts() 호출
4. pendingStatus가 있는 모든 게시글을 순회:
   - .create: API 생성 요청 → 새 serverId로 교체
   - .update: API 수정 요청 → syncStatus를 .sync로 변경
   - .delete: API 삭제 요청 → 로컬 DB에서 제거
5. 동기화 결과를 UI에 Signal로 전달
```

## 핵심 설계 및 트레이드오프

### 1. 로컬 DB 우선 수정
모든 CRUD는 로컬 DB에 먼저 반영 후 API 요청

**이유**:
- UI 즉각 반응성 확보
- 오프라인 환경에서도 일관된 UX

**트레이드오프**:
- 서버 요청 실패 시 상태 관리 복잡도 증가
- 동기화 로직 필요

### 2. 이중 ID 시스템 (localId + serverId)
모든 게시글은 고유한 localId를 가지며, 서버 동기화 시 serverId 추가

**이유**:
- 오프라인 생성 게시글도 고유 식별자 보유
- 서버 응답 전에도 UI에서 게시글 조작 가능

**트레이드오프**:
- ID 관리 복잡도 증가

### 3. 상태 필드 분리 (syncStatus + pendingStatus)
동기화 상태와 대기 중인 작업을 별도 필드로 관리

**syncStatus**:
- `.sync`: 서버와 동기화됨
- `.localOnly`: 로컬 전용
- `.needSync`: 동기화 필요
- `.fail`: 동기화 실패

**pendingStatus**:
- `.none`: 대기 작업 없음
- `.create`: 생성 대기
- `.update`: 수정 대기
- `.delete`: 삭제 대기

**이유**:
- 현재 상태와 해야 할 작업을 명확히 구분
- 동기화 로직이 어떤 API를 호출해야 하는지 명확

**트레이드오프**:
- 상태 조합이 복잡해질 수 있음

### 4. 앱 생성 게시글 특별 처리
앱에서 생성한 게시글은 수정/삭제시 서버 재전송 생략

**이유**:
- DummyJSON API는 게시글 생성은 성공하나, 생성 성공한 게시글의 id는 유효하지 않아 수정/삭제가 api로 불가한 이슈 발생

**트레이드오프**:
- 서버가 실제 CRUD를 지원한다면 수정 필요

### 5. VM에서 병합, Repo에서 필터링
**결정**: 
- **Repo**: 삭제된 게시글 필터링 (deletedServerIds)
- **VM**: API 게시글 + 로컬 게시글 병합

**이유**:
- Repo는 데이터 담당
- VM은 UI 표시 로직 담당

**트레이드오프**:
- 데이터 흐름이 두 계층을 거침
- 디버깅 시 두 곳을 모두 확인 필요
