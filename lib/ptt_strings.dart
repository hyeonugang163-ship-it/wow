class PttStrings {
  static const String holdTooShort =
      '무전은 버튼을 1초 이상 꾹 누르고 말해 주세요.';

  static const String cooldownBlocked =
      '너무 빠르게 연속으로 무전할 수 없습니다.';

  static const String rateLimitSoft =
      '해당 친구에게 너무 자주 무전하고 있어요.';

  static const String friendBlocked =
      '차단한 친구에게는 무전을 보낼 수 없습니다.';

  static const String friendNotAllowWalkie =
      '이 친구는 무전 허용이 꺼져 있어, 매너모드로 전송됩니다.';

  static const String noFriendSelected =
      '무전 버튼을 쓰기 전에 Friends 화면에서 '
      '무전 대상을 먼저 선택해 주세요.';

  static const String micPermissionMissing =
      '마이크 권한이 없어 무전을 보낼 수 없습니다. '
      '설정에서 권한을 켜 주세요.';

  static const String fgsError =
      '무전 서비스가 제대로 시작되지 않았습니다. '
      '앱을 다시 실행해 주세요.';

  static const String abuseReported = '신고가 접수되었습니다.';

  static const String genericError =
      '무전 처리 중 오류가 발생했습니다. '
      '잠시 후 다시 시도해 주세요.';

  static const String genericInfo = '무전 안내를 확인해 주세요.';
}

class PttUiMessages {
  static String messageForType(String messageKey) {
    switch (messageKey) {
      case 'ptt.holdTooShort':
        return PttStrings.holdTooShort;
      case 'ptt.cooldownBlocked':
        return PttStrings.cooldownBlocked;
      case 'ptt.rateLimitSoft':
        return PttStrings.rateLimitSoft;
      case 'ptt.friendBlocked':
        return PttStrings.friendBlocked;
      case 'ptt.friendNotAllowWalkie':
        return PttStrings.friendNotAllowWalkie;
      case 'ptt.noFriendSelected':
        return PttStrings.noFriendSelected;
      case 'ptt.micPermissionMissing':
        return PttStrings.micPermissionMissing;
      case 'ptt.fgsError':
        return PttStrings.fgsError;
      case 'ptt.abuseReported':
        return PttStrings.abuseReported;
      case 'ptt.genericError':
        return PttStrings.genericError;
      default:
        return PttStrings.genericInfo;
    }
  }
}

