import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/features/ptt/application/ptt_debug_log.dart';

/// Riverpod Provider 변경 사항을 PttLogger를 통해
/// 디버그 로그 버퍼에 기록하는 Observer.
///
/// - provider state 를 직접 변경하지 않고,
/// - 콘솔/디버그 로그에만 메타데이터 수준의 정보를 남긴다.
class AppProviderObserver extends ProviderObserver {
  const AppProviderObserver();

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    final providerName =
        provider.name ?? provider.runtimeType.toString();
    final valueType =
        newValue == null ? 'null' : newValue.runtimeType.toString();
    PttLogger.logConsoleOnly(
      '[Provider]',
      'update',
      meta: <String, Object?>{
        'provider': providerName,
        'valueType': valueType,
      },
    );
  }

  @override
  void didAddProvider(
    ProviderBase<Object?> provider,
    Object? value,
    ProviderContainer container,
  ) {
    final providerName =
        provider.name ?? provider.runtimeType.toString();
    PttLogger.logConsoleOnly(
      '[Provider]',
      'add',
      meta: <String, Object?>{
        'provider': providerName,
      },
    );
  }

  @override
  void didDisposeProvider(
    ProviderBase<Object?> provider,
    ProviderContainer container,
  ) {
    final providerName =
        provider.name ?? provider.runtimeType.toString();
    PttLogger.logConsoleOnly(
      '[Provider]',
      'dispose',
      meta: <String, Object?>{
        'provider': providerName,
      },
    );
  }
}
