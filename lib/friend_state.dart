// NOTE: 설계도 v1.1 기준 친구 리스트/무전 허용/차단 상태를 관리하며,
// Block 상태에 따라 Walkie/Manner PTT가 막히도록 사용된다.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/backend/backend_providers.dart';
import 'package:voyage/backend/repositories.dart';
import 'package:voyage/friend.dart';
import 'package:voyage/ptt_debug_log.dart';

class FriendListNotifier extends StateNotifier<List<Friend>> {
  FriendListNotifier(this._repository) : super(const <Friend>[]);

  final FriendRepository _repository;

  Future<void> loadInitial() async {
    try {
      final friends = await _repository.loadFriends();
      state = friends;
      PttLogger.log(
        '[Friends][State]',
        'initial friends loaded',
        meta: <String, Object?>{'count': friends.length},
      );
    } catch (e) {
      PttLogger.log(
        '[Friends][State]',
        'failed to load initial friends',
        meta: <String, Object?>{'error': e.toString()},
      );
    }
  }

  // 이후에 상태 변경(온라인/오프라인 등) 메서드들을 추가할 수 있다.
}

final friendListProvider =
    StateNotifierProvider<FriendListNotifier, List<Friend>>(
  (ref) {
    final repository = ref.read(friendRepositoryProvider);
    final notifier = FriendListNotifier(repository);
    notifier.loadInitial();
    return notifier;
  },
);

final currentPttFriendIdProvider = StateProvider<String?>(
  (ref) => null,
);

class FriendPttAllowNotifier extends StateNotifier<Map<String, bool>> {
  FriendPttAllowNotifier(this._repository) : super(const {});

  final FriendRepository _repository;

  Future<void> setAllowed(String friendId, bool allowed) async {
    final newState = Map<String, bool>.from(state);
    if (allowed) {
      newState[friendId] = true;
    } else {
      newState.remove(friendId);
    }
    state = newState;

    await _repository.syncPttAllow(friendId, allowed);
  }

  bool isAllowed(String friendId) {
    return state[friendId] ?? false;
  }
}

final friendPttAllowProvider =
    StateNotifierProvider<FriendPttAllowNotifier, Map<String, bool>>(
  (ref) {
    final repository = ref.read(friendRepositoryProvider);
    return FriendPttAllowNotifier(repository);
  },
);

class FriendBlockNotifier extends StateNotifier<Map<String, bool>> {
  FriendBlockNotifier(this._repository) : super(const {});

  final FriendRepository _repository;

  Future<void> setBlocked(String friendId, bool blocked) async {
    final next = Map<String, bool>.from(state);
    if (blocked) {
      next[friendId] = true;
    } else {
      next.remove(friendId);
    }
    state = next;

    if (blocked) {
      await _repository.block(friendId);
    } else {
      await _repository.unblock(friendId);
    }
  }

  bool isBlocked(String friendId) {
    return state[friendId] ?? false;
  }
}

final friendBlockProvider =
    StateNotifierProvider<FriendBlockNotifier, Map<String, bool>>(
  (ref) {
    final repository = ref.read(friendRepositoryProvider);
    return FriendBlockNotifier(repository);
  },
);

void reportFriendAbuse({
  required String friendId,
  String reason = 'manual_report',
}) {
  final timestamp = DateTime.now().toIso8601String();
  PttLogger.log(
    '[Safety][Report]',
    'friend abuse reported',
    meta: <String, Object?>{
      'friendId': friendId,
      'reason': reason,
      'timestamp': timestamp,
    },
  );
}
