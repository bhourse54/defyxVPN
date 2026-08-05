import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:defyx_vpn/shared/platform/linux_bundle_paths.dart';

String _scriptPath() => File('scripts/validate_dxcore.sh').absolute.path;
String _runnerCMakeContents() =>
    File('linux/runner/CMakeLists.txt').readAsStringSync();

String _currentMachineArch() {
  final result = Process.runSync('uname', ['-m']);
  expect(result.exitCode, 0, reason: 'uname -m failed: ${result.stderr}');
  final arch = (result.stdout as String).trim();
  expect(arch, isNotEmpty);
  return arch;
}

String _targetFromMachine(String machine) {
  return normalizeLinuxArchitecture(machine);
}

File _writeLibrarySource(Directory dir, {required bool includeAllSymbols}) {
  final source = '''
#include <stdlib.h>
#include <string.h>

int StartVPN(const char* cacheDir, const char* flowLine, const char* pattern) {
  return (cacheDir != NULL && flowLine != NULL && pattern != NULL) ? 1 : 0;
}
int StopVPN(void) { return 1; }
void StartTun2Socks(long long fd, const char* addr) { (void)fd; (void)addr; }
void StopTun2Socks(void) {}
void Stop(void) {}
long long MeasurePing(void) { return 42; }
char* GetFlag(void) { return strdup("us"); }
void SetAsnName(void) {}
void SetTimeZone(float tz) { (void)tz; }
char* GetFlowLine(int isTest) { return strdup(isTest ? "test" : "prod"); }
char* GetCachedFlowLine(void) { return strdup("cached"); }
char* DecodeAndVerifyFlowline(const char* flowLine) { return strdup(flowLine ? flowLine : ""); }
char* GetVpnStatus(void) { return strdup("disconnected"); }
void SetProgressCallback(void (*callback)(char*)) { (void)callback; }
void SetVerboseLogging(int enable) { (void)enable; }
void FreeString(char* value) { free(value); }
void SetConnectionMethod(const char* method) { (void)method; }
void SetCacheDir(const char* cacheDir) { (void)cacheDir; }
int IsTunnelRunning(void) { return 0; }
''';

  final missingSymbolSource = source.replaceFirst(
    'char* GetCachedFlowLine(void) { return strdup("cached"); }\n',
    '',
  );
  final file = File(
    '${dir.path}/${includeAllSymbols ? 'valid' : 'missing_symbol'}.c',
  )..writeAsStringSync(includeAllSymbols ? source : missingSymbolSource);
  return file;
}

String _compileSharedObject(Directory dir, File source) {
  final cc = Platform.environment['CC'] ?? 'cc';
  final output = '${dir.path}/libDXcore.so';
  final compile = Process.runSync(
    cc,
    ['-shared', '-fPIC', source.path, '-o', output],
    workingDirectory: dir.path,
  );
  expect(
    compile.exitCode,
    0,
    reason: 'shared library compilation failed: ${compile.stdout}\n${compile.stderr}',
  );
  return output;
}

void main() {
  test('normalizes Linux bundle architecture names', () {
    expect(normalizeLinuxArchitecture('x86_64'), 'x64');
    expect(normalizeLinuxArchitecture('amd64'), 'x64');
    expect(normalizeLinuxArchitecture('arm64'), 'arm64');
    expect(normalizeLinuxArchitecture('aarch64'), 'arm64');
  });

  test('selects Flutter Linux bundle paths by architecture', () {
    expect(
      linuxBundlePath(
        buildDir: 'build',
        architecture: 'amd64',
        configuration: 'Release',
      ),
      'build/linux/x64/release/bundle',
    );
    expect(
      linuxBundlePath(
        buildDir: 'build',
        architecture: 'aarch64',
        configuration: 'Debug',
      ),
      'build/linux/arm64/debug/bundle',
    );
  });

  test('guards mock DXcore in release builds', () {
    final cmake = _runnerCMakeContents();
    expect(cmake, contains('option(DEFYX_ENABLE_MOCK_DXCORE'));
    expect(cmake, contains('must not be enabled in Release builds'));
  });

  test('validates a DXcore shared object with required symbols', () async {
    final machine = _currentMachineArch();
    final targetArch = _targetFromMachine(machine);
    final tempDir = await Directory.systemTemp.createTemp('dxcore_valid');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final source = _writeLibrarySource(tempDir, includeAllSymbols: true);
    final library = _compileSharedObject(tempDir, source);

    final result = await Process.run(
      'bash',
      [_scriptPath(), library, targetArch],
    );

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });

  test('rejects missing DXcore library', () async {
    final tempDir = await Directory.systemTemp.createTemp('dxcore_missing');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final result = await Process.run(
      'bash',
      [_scriptPath(), '${tempDir.path}/libDXcore.so', 'x64'],
    );

    expect(result.exitCode, isNot(0));
    expect(result.stderr.toString(), contains('not found'));
  });

  test('rejects DXcore libraries missing required exports', () async {
    final tempDir = await Directory.systemTemp.createTemp('dxcore_missing_symbol');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final source = _writeLibrarySource(tempDir, includeAllSymbols: false);
    final library = _compileSharedObject(tempDir, source);

    final result = await Process.run(
      'bash',
      [_scriptPath(), library, _targetFromMachine(_currentMachineArch())],
    );

    expect(result.exitCode, isNot(0));
    expect(result.stderr.toString(), contains('missing required exported symbols'));
  });

  test('rejects a DXcore library built for the wrong architecture', () async {
    final machine = _currentMachineArch();
    final targetArch = _targetFromMachine(machine);
    final wrongTarget = targetArch == 'x64' ? 'arm64' : 'x64';
    final tempDir = await Directory.systemTemp.createTemp('dxcore_wrong_arch');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final source = _writeLibrarySource(tempDir, includeAllSymbols: true);
    final library = _compileSharedObject(tempDir, source);

    final result = await Process.run(
      'bash',
      [_scriptPath(), library, wrongTarget],
    );

    expect(result.exitCode, isNot(0));
    expect(result.stderr.toString(), contains('machine type mismatch'));
  });
}
