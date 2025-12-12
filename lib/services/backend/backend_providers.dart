import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/services/backend/auth_api.dart';
import 'package:voyage/services/backend/chat_api.dart';
import 'package:voyage/services/backend/friend_api.dart';
import 'package:voyage/services/backend/firebase/firebase_auth_client.dart';
import 'package:voyage/services/backend/firebase/firebase_user_profile_repository.dart';
import 'package:voyage/services/backend/ptt_media_api.dart';
import 'package:voyage/services/backend/repositories.dart';
import 'package:voyage/core/feature_flags.dart';
import 'package:voyage/features/ptt/application/ptt_debug_log.dart';

final firebaseAuthClientProvider = Provider<FirebaseAuthClient>(
  (ref) => FirebaseAuthClient(),
);

final firebaseUserProfileRepositoryProvider =
    Provider<FirebaseUserProfileRepository>(
  (ref) => FirebaseUserProfileRepository(),
);

final authApiProvider = Provider<AuthApi>(
  (ref) {
    if (FF.useFakeBackend) {
      return const FakeAuthApi();
    }
    return RealAuthApi();
  },
);

final friendApiProvider = Provider<FriendApi>(
  (ref) {
    // NOTE: 친구 목록은 현재 단계에서는 항상 FakeFriendApi를 사용한다.
    // FF.useFakeBackend와 무관하게 더미 친구(u1~u4)를 노출하기 위함이다.
    return FakeFriendApi();
  },
);

final chatApiProvider = Provider<ChatApi>(
  (ref) {
    if (FF.useFakeBackend) {
      return FakeChatApi();
    }
    return RealChatApi();
  },
);

final pttMediaApiProvider = Provider<PttMediaApi>(
  (ref) {
    if (FF.useFakeBackend) {
      return FakePttMediaApi();
    }
    return RealPttMediaApi();
  },
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) {
    final useFake = FF.useFakeBackend;
    // NOTE: provider 초기화 시점에는 다른 provider state를
    // 수정할 수 없으므로, 디버그 로그는 콘솔 출력만 남긴다.
    PttLogger.logConsoleOnly(
      '[Backend][Repository]',
      'create AuthRepository',
      meta: <String, Object?>{'useFakeBackend': useFake},
    );
    final api = ref.read(authApiProvider);
    if (useFake) {
      return FakeAuthRepository(api, ref);
    }
    return RealAuthRepository(api, ref);
  },
);

final friendRepositoryProvider = Provider<FriendRepository>(
  (ref) {
    const bool useFake = true;
    PttLogger.logConsoleOnly(
      '[Backend][Repository]',
      'create FriendRepository',
      meta: <String, Object?>{'useFakeBackend': useFake},
    );
    final api = ref.read(friendApiProvider);
    return FakeFriendRepository(api, ref);
  },
);

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) {
    final useFake = FF.useFakeBackend;
    PttLogger.logConsoleOnly(
      '[Backend][Repository]',
      'create ChatRepository',
      meta: <String, Object?>{'useFakeBackend': useFake},
    );
    final api = ref.read(chatApiProvider);
    if (useFake) {
      return FakeChatRepository(api, ref);
    }
    return RealChatRepository(api, ref);
  },
);

final pttMediaRepositoryProvider = Provider<PttMediaRepository>(
  (ref) {
    final useFake = FF.useFakeBackend;
    PttLogger.logConsoleOnly(
      '[Backend][Repository]',
      'create PttMediaRepository',
      meta: <String, Object?>{'useFakeBackend': useFake},
    );
    final api = ref.read(pttMediaApiProvider);
    if (useFake) {
      return FakePttMediaRepository(api, ref);
    }
    return RealPttMediaRepository(api, ref);
  },
);
