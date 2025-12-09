import 'package:voyage/backend/api_result.dart';
import 'package:voyage/friend.dart';
import 'package:voyage/ptt_debug_log.dart';

abstract class FriendApi {
  Future<ApiResult<List<Friend>>> fetchFriends();

  Future<ApiResult<void>> updateFriendPttAllow(
    String friendId,
    bool allow,
  );

  Future<ApiResult<void>> blockFriend(String friendId);

  Future<ApiResult<void>> unblockFriend(String friendId);
}

class FakeFriendApi implements FriendApi {
  FakeFriendApi({
    List<Friend>? initialFriends,
  }) : _friends = List<Friend>.from(
          initialFriends ??
              const <Friend>[
                Friend(id: 'u1', name: '친구 1', status: '항상 무전 가능'),
                Friend(id: 'u2', name: '친구 2', status: '가끔 응답'),
                Friend(id: 'u3', name: '친구 3', status: '업무 시간만 무전'),
                Friend(id: 'u4', name: '친구 4', status: '야간 근무 중'),
              ],
        );

  final List<Friend> _friends;
  final Map<String, bool> _pttAllow = <String, bool>{};
  final Map<String, bool> _blocked = <String, bool>{};

  @override
  Future<ApiResult<List<Friend>>> fetchFriends() async {
    PttLogger.log(
      '[Backend][FriendApi][Fake]',
      'fetchFriends',
      meta: <String, Object?>{
        'friendCount': _friends.length,
      },
    );
    // Block/pttAllow flags are kept separately and consumed at repository/UI.
    return ApiResult<List<Friend>>.success(List<Friend>.from(_friends));
  }

  @override
  Future<ApiResult<void>> updateFriendPttAllow(
    String friendId,
    bool allow,
  ) async {
    if (allow) {
      _pttAllow[friendId] = true;
    } else {
      _pttAllow.remove(friendId);
    }

    PttLogger.log(
      '[Backend][FriendApi][Fake]',
      'updateFriendPttAllow',
      meta: <String, Object?>{
        'friendIdHash': friendId.hashCode,
        'allow': allow,
      },
    );

    return ApiResult<void>.success(null);
  }

  @override
  Future<ApiResult<void>> blockFriend(String friendId) async {
    _blocked[friendId] = true;

    PttLogger.log(
      '[Backend][FriendApi][Fake]',
      'blockFriend',
      meta: <String, Object?>{
        'friendIdHash': friendId.hashCode,
      },
    );

    return ApiResult<void>.success(null);
  }

  @override
  Future<ApiResult<void>> unblockFriend(String friendId) async {
    _blocked.remove(friendId);

    PttLogger.log(
      '[Backend][FriendApi][Fake]',
      'unblockFriend',
      meta: <String, Object?>{
        'friendIdHash': friendId.hashCode,
      },
    );

    return ApiResult<void>.success(null);
  }
}

/// Placeholder for real HTTP-backed implementation.
class RealFriendApi implements FriendApi {
  RealFriendApi();

  @override
  Future<ApiResult<List<Friend>>> fetchFriends() {
    return Future<ApiResult<List<Friend>>>.value(
      ApiResult<List<Friend>>.failure(
        const ApiError(
          type: ApiErrorType.unknown,
          message: 'RealFriendApi.fetchFriends is not implemented',
        ),
      ),
    );
  }

  @override
  Future<ApiResult<void>> updateFriendPttAllow(
    String friendId,
    bool allow,
  ) {
    return Future<ApiResult<void>>.value(
      ApiResult<void>.failure(
        const ApiError(
          type: ApiErrorType.unknown,
          message: 'RealFriendApi.updateFriendPttAllow is not implemented',
        ),
      ),
    );
  }

  @override
  Future<ApiResult<void>> blockFriend(String friendId) {
    return Future<ApiResult<void>>.value(
      ApiResult<void>.failure(
        const ApiError(
          type: ApiErrorType.unknown,
          message: 'RealFriendApi.blockFriend is not implemented',
        ),
      ),
    );
  }

  @override
  Future<ApiResult<void>> unblockFriend(String friendId) {
    return Future<ApiResult<void>>.value(
      ApiResult<void>.failure(
        const ApiError(
          type: ApiErrorType.unknown,
          message: 'RealFriendApi.unblockFriend is not implemented',
        ),
      ),
    );
  }
}
