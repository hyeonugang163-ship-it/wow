import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/friend.dart';

class FriendListNotifier extends StateNotifier<List<Friend>> {
  FriendListNotifier() : super(_initialFriends);

  // TODO: remove dummy friends when wiring real backend.
  static const List<Friend> _initialFriends = [
    Friend(id: 'u1', name: '친구 1', status: '항상 무전 가능'),
    Friend(id: 'u2', name: '친구 2', status: '가끔 응답'),
    Friend(id: 'u3', name: '친구 3', status: '업무 시간만 무전'),
    Friend(id: 'u4', name: '친구 4', status: '야간 근무 중'),
  ];

  // 이후에 상태 변경(온라인/오프라인 등) 메서드들을 추가할 수 있다.
}

final friendListProvider =
    StateNotifierProvider<FriendListNotifier, List<Friend>>(
  (ref) => FriendListNotifier(),
);

final currentPttFriendIdProvider = StateProvider<String?>(
  (ref) => null,
);

class FriendPttAllowNotifier extends StateNotifier<Map<String, bool>> {
  FriendPttAllowNotifier() : super(const {});

  void setAllowed(String friendId, bool allowed) {
    final newState = Map<String, bool>.from(state);
    if (allowed) {
      newState[friendId] = true;
    } else {
      newState.remove(friendId);
    }
    state = newState;
  }

  bool isAllowed(String friendId) {
    return state[friendId] ?? false;
  }
}

final friendPttAllowProvider =
    StateNotifierProvider<FriendPttAllowNotifier, Map<String, bool>>(
  (ref) => FriendPttAllowNotifier(),
);
