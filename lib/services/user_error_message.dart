import 'package:firebase_auth/firebase_auth.dart';

const String kDefaultUserErrorMessage = '요청 처리 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.';

String toUserMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-credential':
      case 'invalid-login-credentials':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-email':
        return '이메일 또는 비밀번호를 확인해 주세요.';
      case 'email-already-in-use':
        return '이미 사용 중인 이메일입니다.';
      case 'account-exists-with-different-credential':
        return '같은 이메일로 다른 로그인 방식 계정이 있습니다. 기존 방식으로 로그인 후 계정을 연동해 주세요.';
      case 'provider-already-linked':
        return '이미 연결된 로그인 방식입니다.';
      case 'credential-already-in-use':
        return '해당 계정은 다른 사용자에 이미 연결되어 있습니다.';
      case 'requires-recent-login':
        return '보안을 위해 다시 로그인한 뒤 시도해 주세요.';
      case 'missing-google-token':
        return 'Google 인증 토큰을 가져오지 못했습니다. 다시 시도해 주세요.';
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
      case 'web-context-cancelled':
        return '로그인을 취소했습니다.';
      case 'popup-blocked':
        return '브라우저에서 팝업이 차단되었습니다. 팝업 허용 후 다시 시도해 주세요.';
      case 'operation-not-allowed':
        return '현재 비활성화된 로그인 방식입니다. 관리자 설정을 확인해 주세요.';
      case 'network-request-failed':
        return '네트워크 연결을 확인해 주세요.';
      case 'too-many-requests':
        return '시도가 너무 많습니다. 잠시 후 다시 시도해 주세요.';
      case 'user-disabled':
        return '사용이 중지된 계정입니다. 관리자에게 문의해 주세요.';
      default:
        return '인증 처리 중 오류가 발생했습니다.';
    }
  }

  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return '권한이 없습니다. 운영진 승인 여부를 확인하세요.';
      case 'unauthenticated':
        return '로그인이 필요합니다.';
      case 'unavailable':
        return '서비스 연결이 불안정합니다. 잠시 후 다시 시도해 주세요.';
      case 'not-found':
        return '요청한 데이터를 찾을 수 없습니다.';
      case 'already-exists':
        return '이미 존재하는 데이터입니다.';
      case 'deadline-exceeded':
        return '요청 시간이 초과되었습니다. 다시 시도해 주세요.';
      default:
        return '데이터 처리 중 오류가 발생했습니다.';
    }
  }

  return kDefaultUserErrorMessage;
}
