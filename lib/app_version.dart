/// Single source of truth for the app version.
/// Update this constant whenever a new release is made.
/// This avoids reliance on platform-specific version resource extraction
/// (e.g., PackageInfo.fromPlatform) which can be unreliable on Windows.
const String appVersion = '0.9.0';

/// Whether the current build is a pre-release (alpha, beta, rc, dev).
/// Pre-release builds use a separate database file to protect the stable
/// database from schema changes that may be incompatible with older versions.
bool get isPreRelease {
  final lower = appVersion.toLowerCase();
  return lower.contains('-alpha') ||
      lower.contains('-beta') ||
      lower.contains('-rc') ||
      lower.contains('-dev');
}

/// The stable version number without the pre-release suffix.
/// e.g. '0.9.0-alpha1' → '0.9.0'
String get stableVersionBase => appVersion.split('-').first;
