# Google Play 내부 테스트(Internal testing) 준비 체크리스트

이 문서는 **voyage (Android PTT 앱)** 을 Google Play 콘솔의 **내부 테스트(Internal testing)** 트랙으로 배포하기 위해 필요한 준비 사항을 정리한 것이다.  
목표는 전세계 정식 출시가 아니라, **본인/지인 몇 명에게만 스토어를 통해 설치/업데이트를 편하게** 하기 위한 것이다.

---

## 1. 앱 빌드 산출물(APK/AAB) 준비

- Play 스토어에 올릴 수 있는 빌드 형태
  - **AAB (Android App Bundle)**: Play 스토어 권장 형식, 실제 배포 시 주로 사용.
  - **APK**: 로컬/직접 배포용. Play 콘솔에도 올릴 수 있지만, 신규 앱은 AAB를 사용하는 흐름이 일반적.
- Flutter 빌드 명령 예시 (현재 프로젝트 기준):
  - **APK (직접 설치/테스트용)**:
    ```bash
    flutter build apk --release --dart-define=APP_ENV=alpha
    ```
  - **AAB (Play 콘솔 업로드용)**:
    ```bash
    flutter build appbundle --release --dart-define=APP_ENV=alpha
    ```
  - `APP_ENV=alpha`:
    - `lib/app_env.dart` 에서 `APP_ENV` 값을 읽어 사용한다.
    - `alpha` 는 개발/테스트용 환경, 추후 실제 서비스용 `prod` 를 도입할 수 있다.
- 빌드 산출물 위치
  - APK: `build/app/outputs/flutter-apk/app-release.apk`
  - AAB: `build/app/outputs/bundle/release/app-release.aab`

---

## 2. 패키지명(applicationId), 서명키, 버전 정책

- **패키지명 / applicationId**
  - 경로: `android/app/build.gradle.kts`
  - 현재 설정 예:
    ```kotlin
    android {
        namespace = "com.example.voyage"
        defaultConfig {
            applicationId = "com.example.voyage"
            ...
        }
    }
    ```
  - 이 `applicationId` 가 Play 콘솔에서의 **패키지 이름**이 된다.
  - **한 번 스토어에 등록하면 사실상 변경이 불가능**하다고 생각하고, 최종적으로 사용할 패키지명을 신중하게 고른다.
    - 예: `com.yourname.mjtalk` 등.

- **서명키 (signing key)**
  - Play 스토어에 업로드하는 빌드는 **항상 서명된(release signed)** 빌드여야 한다.
  - 현재 Gradle 설정 예:
    ```kotlin
    signingConfigs {
        create("release") {
            // TODO: 실제 스토어 배포용 keystore 준비 후 값 채우기
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            // keystore 준비 전까지는 debug 키로 서명해 내부 테스트용으로 사용
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    ```
  - 내부 테스트용으로는 `debug` 키로 서명된 빌드도 충분하지만,
    - Play **App Signing** 을 사용할 계획이라면, 별도의 keystore 생성 후 `signingConfigs.release` 에 연결해야 한다.
  - keystore 생성/관리(비밀번호, 백업 등)는 별도 문서/절차로 다룬다.

- **버전 정책**
  - 소스 오브 트루스: `pubspec.yaml` 의 `version` 필드.
    ```yaml
    version: 1.0.0+1
    ```
    - `1.0.0` → `versionName`
    - `+1` → `versionCode`
  - Play 콘솔에서는 **versionCode(= buildNumber)가 증가하지 않으면 새 빌드를 올릴 수 없다.**
  - 내부 테스트라도:
    - 새로운 빌드를 업로드할 때마다 `+buildNumber` 를 1씩 증가시키는 습관을 들이는 것이 좋다.

---

## 3. 스토어 기본 정보(메타데이터) 준비

Play 스토어에 앱을 등록할 때 필요한 기본 정보/이미지 목록이다.  
실제 텍스트/이미지는 이 항목들을 기준으로 따로 작성한다.

- **앱 이름**
  - 스토어에 노출될 이름 (예: `MJTalk`).
  - AndroidManifest 의 `android:label="@string/app_name"` 과 일관성 유지.

- **간단 설명 (Short description)**
  - 최대 80자 정도.
  - 예: “1:1 무전(PTT) + 채팅을 지원하는 간단한 커뮤니케이션 앱”

- **상세 설명 (Full description)**
  - 주요 기능/특징:
    - 1:1 채팅 (텍스트/음성 메시지)
    - 무전모드(Walkie) / 매너모드(Manner)
    - 자동재생 PTT (OS 정책을 따르는 범위 내)
    - 친구 리스트, 읽음 표시 등
  - 주의: 기술적 세부사항보다, 사용자 입장에서의 사용 방법과 장점을 위주로 작성.

- **아이콘**
  - 512x512 PNG (투명 배경 권장).
  - 프로젝트 내 런처 아이콘과 동일하거나, 동일한 브랜드 가이드를 따르는 이미지.

- **스크린샷 / 피처 그래픽**
  - 최소 2–4장 정도:
    - 친구 리스트 화면
    - 1:1 채팅 + 음성 메시지 버블 화면
    - PTT 홈/모드 토글 화면
  - 실제 단말(1080x1920 정도)에서 캡처한 이미지를 사용.

- **카테고리**
  - 앱 vs 게임: **앱**
  - 카테고리: **커뮤니케이션**(Communication) 또는 비슷한 범주.

- **연락처 정보**
  - **이메일 주소** (필수): 버그/문의용.
  - 웹사이트/소셜 링크(optional).

- **개인정보처리방침(Privacy Policy) URL**
  - Notion, GitHub Pages, 간단한 정적 HTML 페이지 등 어디든 상관없지만, **외부에서 접근 가능한 URL** 필요.
  - 내용에 포함되어야 할 최소 항목:
    - Firebase Auth/Firestore/Storage 를 사용한다는 점.
    - 익명 UID 및 메시지/친구 데이터가 서버에 저장/처리된다는 점.
    - 제3자 제공 여부 및 로그/메타데이터 처리 방식(예: 메시지 내용은 로그에 남기지 않음).

---

## 4. Google Play 콘솔 트랙 개념 (Internal / Closed / Open / Production)

- **트랙 종류 개요**
  - **Internal testing (내부 테스트)**
    - 매우 작은 규모(개발자/지인 등)를 대상으로 빠른 검증.
    - 초대 링크 또는 이메일을 통해 설치.
    - 스토어 검색 결과에는 노출되지 않음.
  - **Closed testing (클로즈드 테스트)**
    - 좀 더 넓은 그룹(예: 커뮤니티/베타 테스터)을 대상으로.
    - Google 그룹/메일링 리스트 등을 통해 관리.
  - **Open testing (오픈 테스트)**
    - 누구나 참여 가능하지만, 여전히 “테스트” 트랙으로 표시.
  - **Production (프로덕션)**
    - 정식 공개 트랙. 스토어 검색/추천 등에 노출.

- **내부 테스트 트랙 사용 권장 시나리오**
  - 1:1 PTT MVP를 개발자/지인 몇 명에게만 배포해:
    - 설치/업데이트를 Play 스토어를 통해 편하게 하고 싶을 때.
    - 여러 디바이스에서 동일 패키지/버전 관리가 필요할 때.

- **내부 테스트 기본 절차 (상위 단계)**
  1. **Google Play 콘솔**에 로그인하고 새 앱 생성.
     - 패키지 이름(applicationId)을 프로젝트와 동일하게 입력.
  2. 앱 이름/설명/카테고리/아이콘/스크린샷/연락처/개인정보처리방침 URL 등 기본 정보 입력.
  3. 내용 등급(Content rating), 타깃 연령대, 데이터 보안(Data safety) 설문 완료.
  4. **릴리스 관리 → 테스트 → 내부 테스트** 메뉴에서 새 내부 테스트 릴리스 생성.
  5. 빌드한 `.aab` 파일 업로드 (`app-release.aab`).
  6. 테스터(이메일 또는 그룹)를 추가하고, 내부 테스트용 링크 생성.
  7. 검토/심사(내부 테스트는 보통 짧게) 후 링크를 통해 설치.

---

## 5. 권한(Android Permissions) 및 프라이버시 기본 체크

- **사용 중인 주요 Android 권한 (예시, Manifest 기준)**
  - `RECORD_AUDIO`
    - PTT(무전) 음성 녹음을 위해 사용.
  - `POST_NOTIFICATIONS`
    - 메시지/PTT 관련 푸시 알림을 표시하기 위해 사용.
  - `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MICROPHONE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`
    - Android 14/15 환경에서 PTT 녹음/재생을 Foreground Service 로 동작시키기 위해 사용.

- **권한 사용 설명 (Play 콘솔 폼)**
  - 각 권한에 대해 “왜 필요한지”를 한 줄씩 정리해 두었다가 콘솔 폼에 입력:
    - 예: “RECORD_AUDIO: 사용자가 PTT 버튼을 길게 눌러 음성 메시지를 녹음할 때 필요합니다.”
  - 위치/주소록/사진/파일 등 다른 민감한 권한을 사용하지 않는다면, 그 점을 명시하면 심사에 도움이 된다.

- **프라이버시/데이터 처리 최소 체크리스트**
  - 어떤 데이터가 Firebase 쪽에 저장되는지:
    - 익명 또는 Firebase UID
    - 친구 정보/채팅 메시지 메타데이터
    - 음성 파일(Cloud Storage) 및 그 URL(Firestore)
  - 로그/분석:
    - 메시지 내용(텍스트/음성 텍스트 변환 등)을 로그에 남기지 않도록 설계한 경우, 이를 정책 문서에 명시.
  - 사용자 권리:
    - 계정/데이터 삭제 요청을 받았을 때 어떻게 대응할지 기초적인 방침만 정리.

---

## 6. 최종 체크리스트

Play 콘솔에서 실제로 **내부 테스트를 시작하기 전**에 아래 항목들을 점검한다.

- [ ] `flutter build appbundle --release --dart-define=APP_ENV=alpha` 로 `.aab` 빌드 성공
- [ ] `android/app/build.gradle.kts` 의 `applicationId` 와 Play 콘솔 앱의 패키지 이름이 일치
- [ ] `pubspec.yaml` 의 `version`(X.Y.Z+build) 설정을 이해했고, 빌드마다 buildNumber 를 증가시키는 정책 정리
- [ ] 앱 이름/간단 설명/상세 설명 초안 작성 완료
- [ ] 아이콘(512x512), 스크린샷(2–4장) 준비 완료
- [ ] 사용 중인 Android 권한(RECORD_AUDIO 등)과 그 사용 목적 정리 완료
- [ ] 간단한 개인정보처리방침 초안 작성 + 외부에서 접근 가능한 URL 확보
- [ ] Google Play 콘솔에서 내부 테스트 트랙 생성/릴리스/테스터 추가 흐름을 상위 수준에서 이해
- [ ] 첫 내부 테스트 빌드를 업로드할 준비 완료

이 문서 하나만으로도 “무엇을 준비해야 하는지 / 어떤 순서로 진행해야 하는지”를 감 잡을 수 있도록 유지하는 것이 목표다. 필요 시 실제 진행 상황에 맞춰 항목을 추가/수정하면 된다.

