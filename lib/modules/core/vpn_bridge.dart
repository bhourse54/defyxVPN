import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class VpnBridge {
  VpnBridge._internal();
  static final VpnBridge _instance = VpnBridge._internal();
  factory VpnBridge() => _instance;

  final _methodChannel = MethodChannel('com.defyx.vpn');

  Future<T> _invokeWithFallback<T>(
    String method, {
    Object? arguments,
    required T fallback,
  }) async {
    try {
      return await _methodChannel.invokeMethod<T>(method, arguments) ?? fallback;
    } on PlatformException {
      return fallback;
    }
  }

  Future<String?> getVpnStatus() async =>
      await _invokeWithFallback<String>('getVpnStatus', fallback: 'unavailable');

  Future<void> setAsnName() async {
    try {
      await _methodChannel.invokeMethod('setAsnName');
    } on PlatformException {
      // No-op on Linux when DXcore is unavailable.
    }
  }

  Future<String> getPing() async =>
      await _invokeWithFallback<String>('calculatePing', fallback: 'unavailable');

  Future<void> setTimezone(String timezone) async {
    try {
      await _methodChannel.invokeMethod("setTimezone", {"timezone": timezone});
    } on PlatformException {
      // No-op on Linux when DXcore is unavailable.
    }
  }

  Future<bool> disconnectVpn() async =>
      await _invokeWithFallback<bool>('disconnect', fallback: false);

  Future<bool> stopVPN() async =>
      await _invokeWithFallback<bool>('stopVPN', fallback: false);

  Future<void> stopTun2Socks() async {
    try {
      await _methodChannel.invokeMethod("stopTun2Socks");
    } on PlatformException {
      // No-op on Linux when DXcore is unavailable.
    }
  }

  Future<bool> connectVpn() async =>
      await _invokeWithFallback<bool>('connect', fallback: false);

  Future<bool?> grantVpnPermission() async =>
      await _methodChannel.invokeMethod<bool>("grantVpnPermission");

  Future<bool> startVPN(String flowline, String pattern, bool deepScan, bool healthCheck) async =>
      await _invokeWithFallback<bool>("startVPN", arguments: {
        "flowLine": flowline,
        "pattern": pattern,
        "deepScan": deepScan.toString(),
        "healthCheck": healthCheck.toString()
      }, fallback: false);

  Future<void> startTun2socks() async {
    try {
      await _methodChannel.invokeMethod("startTun2socks");
    } on PlatformException {
      // No-op on Linux when DXcore is unavailable.
    }
  }

  Future<bool> isTunnelRunning() async =>
      await _invokeWithFallback<bool>("isTunnelRunning", fallback: false);

  Future<void> setConnectionMethod(String method) async {
    try {
      await _methodChannel
          .invokeMethod("setConnectionMethod", {"method": method});
    } on PlatformException {
      // No-op on Linux when DXcore is unavailable.
    }
  }
  Future<String> getFlowLine() async {
    final isTestMode = dotenv.env['IS_TEST_MODE'] ?? 'false';
    final flowLine = await _invokeWithFallback<String>(
      'getFlowLine',
      arguments: {"isTest": isTestMode},
      fallback: '',
    );
    return flowLine;
  }

  Future<String> getCachedFlowLine() async {
    return await _invokeWithFallback<String>(
      'getCachedFlowLine',
      fallback: '',
    );
  }

  Future<String> decodeAndVerifyFlowline(String flowLine) async {
    final decoded = await _invokeWithFallback<String>(
      'decodeAndVerifyFlowline',
      arguments: {"flowLine": flowLine},
      fallback: '',
    );
    return decoded;
  }

  Future<void> setCacheDir(String cacheDir) async {
    try {
      await _methodChannel.invokeMethod('setCacheDir', {"cacheDir": cacheDir});
    } on PlatformException {
      // No-op on Linux when DXcore is unavailable.
    }
  }

  Future<String> getSharedDirectory() async =>
      (await _methodChannel.invokeMethod<String>('getSharedDirectory')) ?? "";

  Future<String> getFlag() async =>
      await _invokeWithFallback<String>('getFlag', fallback: 'unavailable');

  Future<bool> prepareVpn() async =>
      await _invokeWithFallback<bool>('prepareVPN', fallback: false);

  Future<bool> isVPNPrepared() async =>
      await _invokeWithFallback<bool>('isVPNPrepared', fallback: false);
}
