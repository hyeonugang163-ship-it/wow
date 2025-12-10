import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/backend/auth_api.dart';
import 'package:voyage/backend/chat_api.dart';
import 'package:voyage/backend/friend_api.dart';
import 'package:voyage/backend/firebase/firebase_auth_client.dart';
import 'package:voyage/backend/firebase/firebase_user_profile_repository.dart';
import 'package:voyage/backend/ptt_media_api.dart';
import 'package:voyage/backend/repositories.dart';
import 'package:voyage/feature_flags.dart';
import 'package:voyage/ptt_debug_log.dart';

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
    if (FF.useFakeBackend) {
      return FakeFriendApi();
    }
    return RealFriendApi();
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
    final useFake = FF.useFakeBackend;
    PttLogger.logConsoleOnly(
      '[Backend][Repository]',
      'create FriendRepository',
      meta: <String, Object?>{'useFakeBackend': useFake},
    );
    final api = ref.read(friendApiProvider);
    if (useFake) {
      return FakeFriendRepository(api, ref);
    }
    return RealFriendRepository(api, ref);
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
