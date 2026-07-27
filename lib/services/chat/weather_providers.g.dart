// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weather_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Riverpod surface for weather (Living Time §3) — @riverpod codegen style
/// (project standard, maintainer directive 2026-07-21): family parameters
/// are plain named args, autoDispose is the default, and the provider is
/// memoized per-argument so the deterministic recompute runs only when the
/// story day/session actually changes. The engine stays pure; inputs cross
/// the Provider→Riverpod boundary as plain values handed down by the
/// existing widget tree (TimeStrip).

@ProviderFor(dailyWeather)
final dailyWeatherProvider = DailyWeatherFamily._();

/// Riverpod surface for weather (Living Time §3) — @riverpod codegen style
/// (project standard, maintainer directive 2026-07-21): family parameters
/// are plain named args, autoDispose is the default, and the provider is
/// memoized per-argument so the deterministic recompute runs only when the
/// story day/session actually changes. The engine stays pure; inputs cross
/// the Provider→Riverpod boundary as plain values handed down by the
/// existing widget tree (TimeStrip).

final class DailyWeatherProvider
    extends $FunctionalProvider<DailyWeather, DailyWeather, DailyWeather>
    with $Provider<DailyWeather> {
  /// Riverpod surface for weather (Living Time §3) — @riverpod codegen style
  /// (project standard, maintainer directive 2026-07-21): family parameters
  /// are plain named args, autoDispose is the default, and the provider is
  /// memoized per-argument so the deterministic recompute runs only when the
  /// story day/session actually changes. The engine stays pure; inputs cross
  /// the Provider→Riverpod boundary as plain values handed down by the
  /// existing widget tree (TimeStrip).
  DailyWeatherProvider._({
    required DailyWeatherFamily super.from,
    required ({String sessionSeed, int dayCount, DateTime date}) super.argument,
  }) : super(
         retry: null,
         name: r'dailyWeatherProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$dailyWeatherHash();

  @override
  String toString() {
    return r'dailyWeatherProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $ProviderElement<DailyWeather> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DailyWeather create(Ref ref) {
    final argument =
        this.argument as ({String sessionSeed, int dayCount, DateTime date});
    return dailyWeather(
      ref,
      sessionSeed: argument.sessionSeed,
      dayCount: argument.dayCount,
      date: argument.date,
    );
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DailyWeather value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DailyWeather>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DailyWeatherProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$dailyWeatherHash() => r'531d2f11f34563f52413f0c25b2ccb644d6f905b';

/// Riverpod surface for weather (Living Time §3) — @riverpod codegen style
/// (project standard, maintainer directive 2026-07-21): family parameters
/// are plain named args, autoDispose is the default, and the provider is
/// memoized per-argument so the deterministic recompute runs only when the
/// story day/session actually changes. The engine stays pure; inputs cross
/// the Provider→Riverpod boundary as plain values handed down by the
/// existing widget tree (TimeStrip).

final class DailyWeatherFamily extends $Family
    with
        $FunctionalFamilyOverride<
          DailyWeather,
          ({String sessionSeed, int dayCount, DateTime date})
        > {
  DailyWeatherFamily._()
    : super(
        retry: null,
        name: r'dailyWeatherProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Riverpod surface for weather (Living Time §3) — @riverpod codegen style
  /// (project standard, maintainer directive 2026-07-21): family parameters
  /// are plain named args, autoDispose is the default, and the provider is
  /// memoized per-argument so the deterministic recompute runs only when the
  /// story day/session actually changes. The engine stays pure; inputs cross
  /// the Provider→Riverpod boundary as plain values handed down by the
  /// existing widget tree (TimeStrip).

  DailyWeatherProvider call({
    required String sessionSeed,
    required int dayCount,
    required DateTime date,
  }) => DailyWeatherProvider._(
    argument: (sessionSeed: sessionSeed, dayCount: dayCount, date: date),
    from: this,
  );

  @override
  String toString() => r'dailyWeatherProvider';
}

/// Current day-part weather (§3 v3) — same memoization contract as
/// [dailyWeather]; the hour is a plain family arg so the recompute runs only
/// when the story clock actually crosses a segment boundary (or the
/// day/session changes), not on every sidebar rebuild.

@ProviderFor(segmentWeather)
final segmentWeatherProvider = SegmentWeatherFamily._();

/// Current day-part weather (§3 v3) — same memoization contract as
/// [dailyWeather]; the hour is a plain family arg so the recompute runs only
/// when the story clock actually crosses a segment boundary (or the
/// day/session changes), not on every sidebar rebuild.

final class SegmentWeatherProvider
    extends $FunctionalProvider<SegmentWeather, SegmentWeather, SegmentWeather>
    with $Provider<SegmentWeather> {
  /// Current day-part weather (§3 v3) — same memoization contract as
  /// [dailyWeather]; the hour is a plain family arg so the recompute runs only
  /// when the story clock actually crosses a segment boundary (or the
  /// day/session changes), not on every sidebar rebuild.
  SegmentWeatherProvider._({
    required SegmentWeatherFamily super.from,
    required ({String sessionSeed, int dayCount, DateTime date, int hour})
    super.argument,
  }) : super(
         retry: null,
         name: r'segmentWeatherProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$segmentWeatherHash();

  @override
  String toString() {
    return r'segmentWeatherProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $ProviderElement<SegmentWeather> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SegmentWeather create(Ref ref) {
    final argument =
        this.argument
            as ({String sessionSeed, int dayCount, DateTime date, int hour});
    return segmentWeather(
      ref,
      sessionSeed: argument.sessionSeed,
      dayCount: argument.dayCount,
      date: argument.date,
      hour: argument.hour,
    );
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SegmentWeather value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SegmentWeather>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SegmentWeatherProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$segmentWeatherHash() => r'ae376be550e5d8628a22f2e43440965d3e68fe99';

/// Current day-part weather (§3 v3) — same memoization contract as
/// [dailyWeather]; the hour is a plain family arg so the recompute runs only
/// when the story clock actually crosses a segment boundary (or the
/// day/session changes), not on every sidebar rebuild.

final class SegmentWeatherFamily extends $Family
    with
        $FunctionalFamilyOverride<
          SegmentWeather,
          ({String sessionSeed, int dayCount, DateTime date, int hour})
        > {
  SegmentWeatherFamily._()
    : super(
        retry: null,
        name: r'segmentWeatherProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Current day-part weather (§3 v3) — same memoization contract as
  /// [dailyWeather]; the hour is a plain family arg so the recompute runs only
  /// when the story clock actually crosses a segment boundary (or the
  /// day/session changes), not on every sidebar rebuild.

  SegmentWeatherProvider call({
    required String sessionSeed,
    required int dayCount,
    required DateTime date,
    required int hour,
  }) => SegmentWeatherProvider._(
    argument: (
      sessionSeed: sessionSeed,
      dayCount: dayCount,
      date: date,
      hour: hour,
    ),
    from: this,
  );

  @override
  String toString() => r'segmentWeatherProvider';
}
