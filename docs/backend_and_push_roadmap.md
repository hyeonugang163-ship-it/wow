# MJTalk Backend / Firebase Push / LiveKit Roadmap

이 문서는 **Firebase/FCM + Real Backend + LiveKit SFU** 도입을 위한 단계별 로드맵입니다.  
현재는 설계/계획서만 정리하며, **코드나 설정 파일은 전혀 수정하지 않습니다.**

---

## 1. 현재 상태 (2025-프리알파 기준)

- 클라이언트 – Android Flutter 앱
  - PTT 코어 (Walkie/Manner, 1초 홀드, 쿨다운, Block/신고, Foreground Service, 라이프사이클 가드) 구현 완료.
  - FakeBackend / FakeVoiceTransport 기반으로 **로컬에서만** 친구/채팅/음성 노트/무전 메타데이터 관리.
  - AppEnvironment(dev/alpha/prod) 분리 및 Settings·Dev 메뉴, 디버그 로그·Issue Report까지 포함.
- 클라이언트 – iOS
  - APNs / Push / CallKit / PTT Framework 관련 설계 아이디어와 Stub 수준의 코드/핸들러만 일부 존재.
  - 실제 iOS 빌드/테스트는 아직 진행하지 못한 상태(Windows + Android 중심 개발 환경).
- 서버
  - 아직 **실제 서버(REST/WebSocket)/DB/LiveKit SFU는 없다.**
  - Repository / API 인터페이스는 설계 수준이며, Fake 구현으로만 동작.
- 운영
  - Pre-Alpha 체크리스트, 디버그 로그 뷰어, Issue Report 복사 기능으로  
    내부 테스트 및 버그 수집은 가능한 수준.

---

## 2. Phase 1 – Firebase 프로젝트 & Android FCM 준비

> **목표:** Firebase 콘솔에서 프로젝트/Android 앱을 만들고,  
> Android에서 FCM을 사용할 수 있는 **사전 준비(콘솔/설정 단계)**만 완료한다.  
> 이 Phase에서는 코드와 설정 파일(pubspec.yaml, Gradle, AndroidManifest 등)을 수정하지 않는다.

### 2.1 진행 순서 (콘솔/설정 중심 체크리스트)

- [ ] Google 계정으로 Firebase 콘솔 로그인
  - [ ] https://console.firebase.google.com 접속.
- [ ] 새 Firebase 프로젝트 생성
  - [ ] 프로젝트 이름 예: `MJTalk-PreAlpha` (실제 이름은 원하는 대로).
  - [ ] Google Analytics 사용 여부 선택(필요 시 ON).
- [ ] Android 앱 추가
  - [ ] **패키지명 확인 (읽기만):**
    - Android 쪽 실제 패키지명(예: `com.example.voyage` 또는 프로젝트에서 사용하는 값)을  
      AndroidManifest / Gradle 설정을 **열어서 확인만 하고, 수정은 하지 않는다.**
  - [ ] 앱 닉네임, SHA-1 / SHA-256 인증서 지문 필요 여부 확인
    - SHA-1/256이 필요하면 keytool 명령어 예시를 문서에만 남긴다 (실행은 사람이 직접).
    - 예시 (참고용 텍스트):  
      `keytool -list -v -keystore <path-to-keystore> -alias <alias-name> -storepass <password>`
- [ ] `google-services.json` 다운로드
  - [ ] Firebase 콘솔의 Android 앱 등록 절차를 마치고 `google-services.json` 파일을 다운로드한다.
  - [ ] **파일 위치 계획만 문서에 기록:**  
    - 예: `android/app/google-services.json`  
    - 실제로 파일을 넣거나 Gradle 설정을 수정하는 작업은 **Phase 2로 미룬다.**
- [ ] Firebase Cloud Messaging 활성화 확인
  - [ ] Firebase 콘솔의 “Cloud Messaging” 메뉴에서 프로젝트가 FCM을 사용할 수 있는 상태인지 확인.
  - [ ] Android용 서버 키 / Sender ID 등은 백엔드와 연동할 때 사용할 값으로 기록만 해둔다.

### 2.2 Phase 1 주의 사항

- 이 Phase에서는:
  - pubspec.yaml 수정 X
  - Gradle/AndroidManifest 수정 X
  - Dart/네이티브 코드 수정 X
- 결과물은 **Firebase 콘솔 스크린샷 + google-services.json 파일 + FCM 서버 키/프로젝트 정보** 정도의 정리된 자료이다.

---

## 3. Phase 2 – Android FCM 클라이언트 연동 계획 (설계만, 코드 변경 금지)

> **목표:** 나중에 FCM을 붙일 때 사용할 **구조/역할 분담**을 미리 설계한다.  
> 실제 코드/플러그인 추가는 이후 단계에서 수행하며, 여기서는 “어떤 레이어에 무엇을 둘지”만 정리한다.

### 3.1 전체 구조 개요

- Flutter 레이어 (Dart)
  - 공통 인터페이스: `PushNotificationHandler` (가칭)
    - Android FCM / iOS APNs 모두 이 인터페이스를 통해 Dart로 이벤트 전달.
    - 앱 내에서는 `PttPushHandler` 또는 유사한 기존 핸들러에 push 이벤트를 연결.
  - `PttPushHandler`:
    - 이미 존재하는 PTT 관련 push 처리 핸들러에,
    - “Android에서 온 FCM”, “iOS에서 온 APNs”를 구분할 수 있는 필드를 추가 설계(예: `platform`, `pushSource` 등).
    - FCM payload → 도메인 이벤트(PttUiEvent 또는 내부 이벤트 버스) 로 변환하는 책임.

- Android 네이티브 레이어 (문서상 설계만)
  - FirebaseMessagingService 서브클래스 (예: `MjTalkFirebaseMessagingService`)
    - `onNewToken(token: String)`
      - 새 FCM 토큰을 수신했을 때, 추후 서버/Repository로 전달할 경로를 마련.
      - 현재는 콘솔 로그 + 로컬 저장 정도로 설계.
    - `onMessageReceived(remoteMessage: RemoteMessage)`
      - `type` / `category` / `ptt` / `chat` 등 payload 필드를 기준으로 분기.
      - 앱이 **포그라운드** 상태일 때:
        - Flutter 엔진이 살아 있다면 MethodChannel/EventChannel 등을 통해 Dart로 바로 전달.
      - 앱이 **백그라운드/종료** 상태일 때:
        - 시스템 알림(Notification)을 표시하여 사용자가 탭하면 Flutter 앱이 열리도록 설계.

### 3.2 메시지 페이로드 설계(초안)

- PTT 관련 push (예: `type = "ptt"`):
  - 필드 예:
    - `type`: `"ptt"`
    - `friendId`
    - `messageId`
    - `pttMode` (walkie / manner)
    - `timestamp`
  - 음성 데이터 본문은 포함하지 않고, 서버/스토리지의 리소스 경로 또는 messageId만 전달.
- 채팅 텍스트 push (예: `type = "chat"`):
  - 필드 예:
    - `type`: `"chat"`
    - `friendId`
    - `messageId`
    - `hasPreview`: true/false (미리보기 텍스트를 넣어도 되는지 여부 정도).
- 기타 시스템 push:
  - 친구 요청, 무전 허용 요청, Block/신고 결과 등은 `type` 값을 별도로 설계.

### 3.3 플러그인/코드 도입에 대한 원칙 (문서상만)

- FCM 연동 시 사용할 수 있는 Flutter 패키지 예:
  - `firebase_core`, `firebase_messaging` 등.
- 하지만 **이 문서 단계에서는**:
  - pubspec.yaml에 패키지 추가 X
  - Android 네이티브 코드 생성 X
  - Dart 코드 수정 X  
  → “어떤 패키지를 어떤 레이어에서 사용할지 계획만 세운다.”

---

## 4. Phase 3 – Real Backend (REST / WebSocket) 도입 로드맵

> **목표:** FakeBackend / FakeRepository를 점진적으로 실제 서버 기반 아키텍처로 교체한다.  
> 1차는 REST API 중심, 이후 WebSocket으로 실시간 업데이트를 추가한다.

### 4.1 백엔드 1차 – 단일 리전 + 단순 REST

- 주요 엔드포인트 예시 (개념만):
  - `POST /auth/login`, `POST /auth/refresh`
  - `GET /friends`, `POST /friends/requests`, `POST /friends/allow_walkie`
  - `GET /chats/{friendId}`, `POST /chats/{friendId}/messages`
  - `POST /ptt/upload` (음성 노트/무전 녹음 파일 업로드, 메타데이터 함께)
  - `POST /reports` (Block/신고)
- 인증 방식:
  - Firebase Auth 또는 자체 토큰 기반(Auth 서버) 중 택 1.
  - Access token / Refresh token 설계 (문서로만).
- 클라이언트 측 역할:
  - 기존 FakeRepository 인터페이스를 유지하면서, RealRepository 구현을 추가.
  - AppEnvironment:
    - dev: FakeBackend 우선, RealBackend는 선택적으로.
    - alpha: RealBackend를 점진적으로 ON, 특정 테스터에게만.
    - prod: RealBackend를 기본으로 사용.

### 4.2 백엔드 2차 – WebSocket / 실시간 업데이트

- 목표:
  - 채팅/무전 **메타데이터**(“새 메시지 도착”, “상대방이 듣기 시작”)를 실시간으로 전달.
  - 미디어 본문(음성/텍스트) 자체는 REST/S3/GCS로 처리.
- 서버:
  - WebSocket 엔드포인트 예: `wss://api.mjtalk.com/ws`
  - 인증된 연결에서만 이벤트 push.
- 클라이언트:
  - Repository 레벨에서 WebSocket을 구독하고,
  - 들어오는 이벤트를 Chat/PTT 상태로 반영.

### 4.3 백엔드 3차 – 멀티 리전 / 스케일링 (미래 계획)

- 트래픽 증가 시 고려 사항(TODO 수준):
  - 지역별 서버/DB 분리.
  - 메시지/미디어 저장소(S3/GCS 버킷) 리전 분할.
  - LiveKit/미디어 서버도 지역별로 배치.

---

## 5. Phase 4 – LiveKit / SFU 기반 PTT 실시간 음성 전송

> **목표:** 현재 녹음 후 전송 중심인 PTT를, LiveKit 같은 SFU를 통해  
> **실시간에 가까운 Walkie 모드**로 확장한다.

### 5.1 전송 계층 설계 연계

- 이미 정의된 `VoiceTransport` 인터페이스를 기준으로:
  - 현재: `FakeVoiceTransport` 또는 파일 기반 전송.
  - 이후: `LiveKitVoiceTransport` (가칭) 구현 추가.
- 원칙:
  - UI/컨트롤러는 `VoiceTransport` 인터페이스만 바라보고,
  - 실제 구현 교체는 AppEnvironment/PolicyConfig/FF 레이어에서 결정.

### 5.2 단계별 도입 계획

1. 개발/테스트용 LiveKit 프로젝트 세팅
   - LiveKit Cloud 또는 자체 호스팅 선택.
   - 프로젝트 생성, API Key/Secret 발급 (문서에만 기록).
2. dev 환경에서만 LiveKit 연결 시험
   - FakeVoiceTransport와 LiveKitVoiceTransport를 토글하며 품질 비교.
   - Pre-Alpha 테스터 일부에게만 LiveKit 모드 노출.
3. 네트워크 조건별 품질 측정
   - Wi-Fi / LTE / 3G / 높은 패킷 로스 환경에서:
     - TTP(버튼→첫 재생), 지연, 끊김, 재연결 빈도 측정 계획 수립.
4. alpha/prod 전환 조건 정의
   - 특정 KPI (예: p95 TTP, 실패율)가 기준치를 만족할 때만 기본 모드로 승격.

---

## 6. iOS Push / CallKit / PTT Framework 향후 계획 (문서만)

> 현재는 Windows + Android 중심 환경으로, iOS는 실제 빌드/테스트가 어렵다.  
> Mac + iOS 디바이스 환경이 준비되었을 때 아래 단계로 진행한다.

### 6.1 APNs / Push 기본 설정

- Apple Developer 계정 준비.
- Certificates / Keys
  - APNs Auth Key 생성 (`.p8`) 또는 인증서 방식 선택.
  - Bundle ID 등록, Team ID / Key ID 기록.
- Firebase 사용 시:
  - Firebase Cloud Messaging + APNs Key 연동 절차 문서화.

### 6.2 iOS 푸시 페이로드 / 핸들링

- Android FCM과 최대한 동일한 payload 구조 사용:
  - `type`, `friendId`, `messageId`, `pttMode`, `timestamp` 등.
- iOS App Delegate / Notification Service Extension / Notification Content Extension 설계:
  - 포그라운드: 앱 내 핸들러로 직접 전달.
  - 백그라운드/종료: 시스템 알림 표시 후 탭 시 Flutter로 라우팅.

### 6.3 CallKit / PushKit / PTT Framework (iOS 18+)

- Push-to-Talk entitlement
  - Apple Developer 문서/포털에서 entitlement 신청 절차 검토.
  - PTT 앱 카테고리 정책, 심사 요구사항 조사.
- CallKit / PushKit 사용 시 원칙:
  - VoIP Push는 CallKit 수신 UI 필수, 자동 수락 금지.
  - PTT는 “전화”가 아닌 “무전/미디어”에 가깝기 때문에, 최소 권한/최소 UI로 설계.

---

## 7. 보안 / 프라이버시 / 로그·메트릭 확장 계획

> 설계도 v1.1의 프라이버시/보안 원칙을  
> 실서버/푸시/LiveKit 환경으로 확장했을 때 어떻게 지킬지 정리한다.

### 7.1 메시지/음성 콘텐츠 취급

- 저장 원칙:
  - 서버/스토리지에는 **암호화된 blob**만 저장하는 방향 고려.
  - 보관 기간: 수신/재생 후 N일이 지나면 자동 삭제(설정 가능).
- 접근 통제:
  - 운영자/관리자도 상시 전체 대화 열람 불가.
  - 신고/법적 요구 등 특수 상황에서만 제한된 범위 접근 + 접근 로그 남기기.

### 7.2 로그 / 메트릭

- 로그:
  - 클라이언트/서버 로그에는 메시지/음성 내용 자체를 남기지 않는다.
  - `message_id`, `user_id`, `peer_id`, `timestamp`, 오류 코드, 품질 지표 등 메타데이터만 기록.
- 메트릭:
  - TTP(버튼→재생), 실패율, 네트워크 오류율, 재연결 횟수 등.
  - 플랫폼, AppEnvironment, PttMode, 네트워크 타입별로 집계.

### 7.3 인증/권한

- 인증:
  - Firebase Auth 또는 자체 Auth 서버 선택 후, 토큰 발급/갱신 정책 정의.
- 권한/정책:
  - 친구/Block/신고/무전 허용 리스트를 서버 권한 모델로 정리.
  - 서버에서 RateLimit/Abuse Detection 수행 후 클라이언트에 피드백하는 프로토콜 설계.

---

## 8. Phase별 체크리스트 (착수 기준 / 완료 기준)

각 Phase를 시작/끝낼 때 기준을 명확히 하여,  
“지금 어디 단계까지 왔는지”를 쉽게 볼 수 있게 한다.

### Phase 1 – Firebase 프로젝트 & Android FCM 준비

**착수 기준**
- [ ] Pre-Alpha 체크리스트 기준으로 Android 로컬 테스트가 안정적이다.
- [ ] AppEnvironment(dev/alpha/prod) 구조와 FakeBackend/FakeVoiceTransport 구조가 정리되어 있다.
- [ ] Firebase를 도입할 Google 계정/조직이 결정되어 있다.

**완료 기준**
- [ ] Firebase 콘솔에서 프로젝트가 생성되어 있다.
- [ ] Android 앱이 Firebase 프로젝트에 등록되어 있다.
- [ ] `google-services.json` 파일이 로컬에 준비되어 있다 (적절한 위치에 둘 계획 포함).
- [ ] FCM 서버 키/프로젝트 정보가 정리되어 있으며,  
      아직 코드는 안 붙였지만 “이제 FCM을 붙일 준비가 되었다”고 말할 수 있다.

---

### Phase 2 – Android FCM 클라이언트 연동 계획 (설계 단계)

**착수 기준**
- [ ] Phase 1이 완료되어 Firebase/FCM 프로젝트 정보가 정리되어 있다.
- [ ] 푸시를 통해 무엇을 전달할지(PTT/채팅/친구 요청 등) 기본 페이로드 설계가 되어 있다.
- [ ] 기존 PTT/채팅 Repository/핸들러 구조를 대략 이해하고 있다.

**완료 기준**
- [ ] Flutter 레이어의 `PushNotificationHandler` / `PttPushHandler` 설계 문서가 정리되어 있다.
- [ ] Android FirebaseMessagingService에서 onNewToken / onMessageReceived 역할 분담이 문서로 정의되어 있다.
- [ ] FCM payload 필드 설계(type, friendId, messageId, pttMode 등)가 문서에 정리되어 있다.
- [ ] 어떤 Flutter 패키지를 쓸지(예: `firebase_messaging`) 선택만 되어 있고,  
      실제 pubspec/코드 변경은 하지 않은 상태다.

---

### Phase 3 – Real Backend (REST / WebSocket) 도입

**착수 기준**
- [ ] 현재 FakeBackend/FakeRepository 인터페이스가 정리되어 있다.
- [ ] 기본 도메인 모델(유저, 친구, 채팅, 메시지, PTT 기록 등) 스키마 초안이 있다.
- [ ] 인증 방식(Firebase Auth 또는 자체 Auth)에 대한 방향성이 정해져 있다.

**완료 기준 (1차 REST 단계)**
- [ ] 최소한의 REST API(/friends, /chats, /messages, /ptt/upload 등)가 동작하는 테스트 서버가 있다.
- [ ] dev/alpha 환경에서 일부 사용자에게 RealRepository를 연결하여 테스트할 수 있다.
- [ ] FakeBackend와 RealBackend를 AppEnvironment/설정으로 손쉽게 스위칭할 수 있다.

**완료 기준 (2차 WebSocket 단계)**
- [ ] WebSocket 기반 실시간 업데이트(새 메시지/무전 도착 알림)가 동작한다.
- [ ] 클라이언트가 WebSocket 이벤트를 Repository 레벨에서 받아 UI에 반영할 수 있다.

---

### Phase 4 – LiveKit / SFU 기반 PTT 실시간 음성 전송

**착수 기준**
- [ ] Phase 3의 Real Backend 1차 REST 도입이 어느 정도 안정화되어 있다.
- [ ] `VoiceTransport` 인터페이스와 PttController 구조가 정리되어 있다.
- [ ] 네트워크/미디어 품질을 측정할 기본 로깅/메트릭 체계가 준비되어 있다.

**완료 기준**
- [ ] dev 환경에서 LiveKit과의 연결/발행/수신 테스트가 가능하다.
- [ ] alpha 환경에서 제한된 테스터에게 LiveKit 기반 Walkie 모드를 제공할 수 있다.
- [ ] TTP, 지연, 끊김, 재연결율 등 주요 KPI가 목표 범위 내에 들어온다.
- [ ] FakeVoiceTransport와 LiveKitVoiceTransport를 환경/설정으로 스위칭할 수 있다.

---

### iOS / 보안·프라이버시 확장 – 보조 트랙

**iOS Push / CallKit / PTT Framework**
- 착수 기준:
  - [ ] Mac + iOS 디바이스 개발 환경이 준비되어 있다.
  - [ ] Apple Developer 계정 및 인증서/Key 관리 체계가 정리되어 있다.
- 완료 기준:
  - [ ] APNs 설정 및 기본 Push 수신/탭 → 앱 진입 플로우가 동작한다.
  - [ ] iOS Push payload가 Android FCM payload와 호환되는 수준으로 정리되어 있다.
  - [ ] (장기) iOS 18+ PTT Framework entitlement 검토/신청이 문서화되어 있다.

**보안 / 프라이버시 / 로그·메트릭**
- 착수 기준:
  - [ ] 기본 프라이버시 원칙(최소 보관, 운영자 열람 최소화, 로그에 내용 미저장)이 정리되어 있다.
- 완료 기준:
  - [ ] 실서버/스토리지/LiveKit 도입 후에도 위 원칙을 지키는지 점검하는 체크리스트가 있다.
  - [ ] 로그/메트릭 스키마에 콘텐츠가 아닌 메타데이터만 남도록 설계되어 있다.

