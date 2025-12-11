// NOTE: Android 1:1 PTT MVP 수동 QA 체크리스트.
//
// 이 파일은 코드가 아니라, 출시 전 점검을 위한
// 개발자용 TODO 목록을 담고 있다.
//
// [기본 동작]
// [ ] 앱 설치 후 첫 실행 → 익명 로그인 성공 & 크래시 없음
// [ ] 친구 리스트(Fake) 표시
// [ ] 텍스트 메시지 전송/수신 OK
// [ ] 음성 메시지(1초 이상) 전송/재생 OK
//
// [실시간 / 읽음 상태]
// [ ] 다른 클라이언트/콘솔에서 메시지 추가 시 실시간 반영
// [ ] seenBy 기반 읽음 표시 동작
// [ ] 친구 리스트 lastMessage / hasUnread 뱃지 동작
//
// [전송 실패/재전송]
// [ ] 네트워크 끊고 텍스트 전송 → failed 상태 표시
// [ ] 네트워크 끊고 음성 전송 → failed 상태 표시
// [ ] failed 버블 탭 시 재전송 시도
// [ ] 재전송 성공 후 상태가 sent 로 변경 (중복 전송 여부는 추후 서버에서 정리)
//
// [PTT 모드 / 자동재생]
// [ ] walkie / manner 모드 토글 UI 동작
// [ ] walkie 모드에서 새 음성 자동재생 (상호 허용/정책에 따른 범위 내)
// [ ] manner 모드에서는 탭해서 재생
//
// [푸시 / 알림 / DND]
// [ ] FCM 푸시 (포그라운드) → 로컬 알림 표시 + ChatPage 진입
// [ ] FCM 푸시 (백그라운드/종료) → 알림 탭 시 ChatPage 진입
// [ ] 매너모드: 알림이 조용(silent) 스타일로 동작 (playSound=false)
// [ ] walkie 모드 + 백그라운드: loud 채널로 소리/진동 알림
// [ ] DND 켜진 상태에서도 앱이 크래시하지 않고, OS 정책대로 소리/무음 처리
//
// [안정성 / 상태 꼬임]
// [ ] PTT 녹음/재생이 동시에 겹치지 않고, 이상한 중복 재생/녹음 없음
// [ ] 네트워크/Storage/Firebase 에러 시에도 앱이 죽지 않고, 경고 로그만 남는다
//
// [디버그 도구]
// [ ] /debug 화면에서 APP_ENV / uid / PttMode / Firebase project / FCM token 확인
// [ ] DebugLogsPage(/debug/logs)에서 최근 로그와 버그 리포트 텍스트 복사 가능
//
// [Android 릴리즈 빌드 방법]
// 1) 터미널에서 프로젝트 루트(voyage)로 이동
// 2) 다음 명령 실행:
//    flutter build apk --release --dart-define=APP_ENV=alpha
// 3) 출력 APK:
//    build/app/outputs/flutter-apk/app-release.apk
// 4) 기기에 APK 설치 후, 위 체크리스트 전체를 다시 점검한다.
//
// prod 빌드에서는 /debug 라우트를 일반 사용자에게 노출하지 않는 것을 권장한다.
