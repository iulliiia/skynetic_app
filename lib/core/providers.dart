import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skynetic_app/core/api/api_client.dart';
import 'package:skynetic_app/core/auth/auth_repository.dart';
import 'package:skynetic_app/core/auth/token_storage.dart';
import 'package:skynetic_app/core/config/app_config.dart';
import 'package:skynetic_app/features/chat/chat_repository.dart';
import 'package:skynetic_app/features/lesions/lesion_repository.dart';
import 'package:skynetic_app/features/review/review_repository.dart';

/// Infrastructure providers. Tests override [tokenStorageProvider],
/// [authRepositoryProvider] and [lesionRepositoryProvider].

final tokenStorageProvider = Provider<TokenStorage>((ref) => SecureTokenStorage());

/// Fires when the API client had to drop the session (refresh rejected).
final sessionExpiredProvider = Provider<ChangeNotifier>((ref) {
  final n = _SessionExpiredNotifier();
  ref.onDispose(n.dispose);
  return n;
});

class _SessionExpiredNotifier extends ChangeNotifier {
  void fire() => notifyListeners();
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final expired = ref.watch(sessionExpiredProvider) as _SessionExpiredNotifier;
  return ApiClient(
    baseUrl: AppConfig.platformBaseUrl,
    storage: ref.watch(tokenStorageProvider),
    onSessionExpired: expired.fire,
  );
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ApiAuthRepository(ref.watch(apiClientProvider), ref.watch(tokenStorageProvider)),
);

final lesionRepositoryProvider = Provider<LesionRepository>(
  (ref) => ApiLesionRepository(ref.watch(apiClientProvider)),
);

final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => ApiReviewRepository(ref.watch(apiClientProvider)),
);

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ApiChatRepository(ref.watch(apiClientProvider), ref.watch(tokenStorageProvider)),
);
