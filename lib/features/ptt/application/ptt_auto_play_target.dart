/// Global auto-play target registry used to bridge
/// native PTT pushes (iOS A안) and Flutter chat UI.
///
/// - Native(AppDelegate) → PttPushHandler: friendId / messageId 전달
/// - PttPushHandler: 전역 타깃을 등록
/// - ChatPage: 해당 friendId 채팅이 열렸을 때 타깃을 소비하고,
///   해당 messageId(또는 마지막 수신 음성)를 자동 재생한다.
class PttAutoPlayTarget {
  const PttAutoPlayTarget({
    required this.friendId,
    this.messageId,
    required this.createdAt,
  });

  final String friendId;
  final String? messageId;
  final DateTime createdAt;
}

class PttAutoPlayRegistry {
  static PttAutoPlayTarget? _pending;

  static void setTarget({
    required String friendId,
    String? messageId,
  }) {
    _pending = PttAutoPlayTarget(
      friendId: friendId,
      messageId: messageId,
      createdAt: DateTime.now(),
    );
  }

  /// Returns and clears the pending target if it matches [friendId].
  ///
  /// The target is treated as a one-shot hint for the next time
  /// the corresponding chat screen is opened.
  static PttAutoPlayTarget? takeIfMatches(String friendId) {
    final current = _pending;
    if (current == null) {
      return null;
    }
    if (current.friendId != friendId) {
      return null;
    }
    _pending = null;
    return current;
  }
}
