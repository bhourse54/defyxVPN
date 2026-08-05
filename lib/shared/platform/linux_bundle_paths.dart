String normalizeLinuxArchitecture(String architecture) {
  final normalized = architecture.trim().toLowerCase();
  switch (normalized) {
    case 'x86_64':
    case 'amd64':
    case 'x64':
      return 'x64';
    case 'aarch64':
    case 'arm64':
      return 'arm64';
    default:
      throw ArgumentError.value(
        architecture,
        'architecture',
        'Unsupported Linux architecture',
      );
  }
}

String linuxBundlePath({
  required String buildDir,
  required String architecture,
  required String configuration,
}) {
  final normalizedArch = normalizeLinuxArchitecture(architecture);
  final normalizedConfig = configuration.trim().toLowerCase();
  return '$buildDir/linux/$normalizedArch/$normalizedConfig/bundle';
}
