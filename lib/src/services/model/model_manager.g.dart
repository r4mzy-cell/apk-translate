// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_manager.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ModelManager)
final modelManagerProvider = ModelManagerProvider._();

final class ModelManagerProvider
    extends $AsyncNotifierProvider<ModelManager, List<ModelInfo>> {
  ModelManagerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'modelManagerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$modelManagerHash();

  @$internal
  @override
  ModelManager create() => ModelManager();
}

String _$modelManagerHash() => r'fecc15c1f57f0f1f3abb40aaf66161601e9f2755';

abstract class _$ModelManager extends $AsyncNotifier<List<ModelInfo>> {
  FutureOr<List<ModelInfo>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<ModelInfo>>, List<ModelInfo>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<ModelInfo>>, List<ModelInfo>>,
        AsyncValue<List<ModelInfo>>,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}

/// Provider for ModelManager

@ProviderFor(modelManager)
final modelManagerProvider = ModelManagerProvider._();

/// Provider for ModelManager

final class ModelManagerProvider
    extends $FunctionalProvider<ModelManager, ModelManager, ModelManager>
    with $Provider<ModelManager> {
  /// Provider for ModelManager
  ModelManagerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'modelManagerProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$modelManagerHash();

  @$internal
  @override
  $ProviderElement<ModelManager> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ModelManager create(Ref ref) {
    return modelManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ModelManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ModelManager>(value),
    );
  }
}

String _$modelManagerHash() => r'cd9f3d425f4261ef0b79aadf2cc4e52f8d4b67e0';

/// AppDatabase provider

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

/// AppDatabase provider

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  /// AppDatabase provider
  AppDatabaseProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'appDatabaseProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'5f40b143250066f9cd432da65ff950b1a800d8ef';
