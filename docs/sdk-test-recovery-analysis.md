# SDK 및 연동 테스트 복구 분석

orchestrator: Codex

사용자 승인: 이전 검증 변경 커밋·푸시 후 다음 단계 진행. 범위는 proto-shop-finder Kakao 경계 테스트, BeMyColleague 기존 서브모듈 복구, Flutter SDK/lock 호환성 조사다. 외부 서비스 계정 로그인·API 쓰기·대규모 업그레이드는 제외한다.

근거: src/be-my-colleague/.gitmodules에 Sheets 저장소 URL과 원래 경로가 있고 Git 트리에는 f6aaa7ce44c1a4aa85590df998a42387f2110f4f gitlink가 존재한다. 모노레포 루트에는 .gitmodules가 없어 자동 초기화가 되지 않는다. 실제 원본 고정 revision 복원만 허용하며 임의 소스 복사는 하지 않는다.

Flutter 세 앱 .metadata 생성 revision은 077b4a4ce10a07b82caa6897f0c626f9c0a3ac90이다. 현재 C:/flutter의 3.41.9와 원본 lockfile이 맞지 않는다. 기존 SDK를 바꾸거나 lock을 올리지 않고 적합한 별도 SDK를 조사한다.

최종 결정: 원격 서브모듈 복원은 Repository not found로 실패했다. 원본 f6aaa7c는 같은 저장소 subtree commit fc178934685e54bf31480e5036bdcfe64fde9048에 반입된 근거가 있어 로컬 단일 path package 연결로 해결했다. 선언된 외부 패키지 버전 범위는 유지했고 pub get 결과는 로컬 패키지 하나 추가였다. 신규 SDK는 다운로드하지 않았고 모든 추적 lockfile 변경이 없음을 확인했다.
