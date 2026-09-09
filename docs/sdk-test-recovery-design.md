# SDK 및 연동 테스트 복구 설계

orchestrator: Codex

Kakao SDK 객체만 테스트 경계 대역으로 제어하고 실제 App·메뉴·지리 거리 계산·마커·범위·리사이즈 코드를 실행한다. 실제 위치 권한 실패 콜백 누락을 확인해 지도 상태를 바꾸지 않고 경고하는 처리를 추가했다. 실제 서비스 접속이나 지도 모듈 자체의 대체 구현은 사용하지 않는다.

BeMyColleague 원래 gitlink의 f6aaa7c 커밋은 원격 Repository not found 때문에 복원할 수 없다. 하지만 fc178934685e54bf31480e5036bdcfe64fde9048의 git-subtree-split 기록이 같은 f6aaa7c 원본을 src/jaywapp-dart-google-sheet에 반입한 근거다. 따라서 그 단일 구현을 표준 lib/ 구조의 jaywapp_google_sheet 로컬 Dart 패키지로 연결한다. 앱은 pubspec path ../../jaywapp-dart-google-sheet를 사용한다. 매니저·범위·HTTP client는 복사하지 않고 이동하며 기존 파일 경로에는 export만 남겨 기존 호출을 보존한다. 죽은 gitlink와 이전 .gitmodules만 제거한다. 패키지의 의존성 범위는 앱의 기존 범위와 동일하다.

Flutter 세 앱의 .metadata revision은 3.32.6이다. 로컬 SDK Git tag에서 flutter_test의 test_api 0.7.4·matcher 0.12.17·leak_tracker 10.0.9가 기존 lock과 맞는 것을 확인했다. 이는 호환 SDK 후보 근거이며 전체 패키지 해결 성공을 뜻하지 않는다. 이번 범위에서는 별도 SDK 다운로드·공유 SDK 교체·원본 lock 변경을 하지 않는다.
