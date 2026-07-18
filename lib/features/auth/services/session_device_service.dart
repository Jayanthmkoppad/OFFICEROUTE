import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef SessionDeviceMetadata = ({
  String deviceId,
  String deviceModel,
  String platform,
  String appVersion,
});

class SessionDeviceService {
  SessionDeviceService._();

  static const _deviceIdKey = 'officeroute_session_device_id';

  static Future<SessionDeviceMetadata> load() async {
    final preferences = SharedPreferencesAsync();
    var deviceId = await preferences.getString(_deviceIdKey);
    if (deviceId == null || deviceId.trim().isEmpty) {
      deviceId = _newDeviceId();
      await preferences.setString(_deviceIdKey, deviceId);
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final deviceInfo = await DeviceInfoPlugin().deviceInfo;
    final data = deviceInfo.data;

    return (
      deviceId: deviceId,
      deviceModel: _deviceModel(data),
      platform: _platformLabel(data),
      appVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
    );
  }

  static String _newDeviceId() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  static String _deviceModel(Map<String, dynamic> data) {
    final manufacturer = (data['manufacturer'] ?? data['name'] ?? '')
        .toString();
    final model =
        (data['model'] ??
                data['productName'] ??
                data['computerName'] ??
                data['browserName'] ??
                'Unknown device')
            .toString();
    return <String>[
      manufacturer,
      model,
    ].where((value) => value.trim().isNotEmpty).join(' ').trim();
  }

  static String _platformLabel(Map<String, dynamic> data) {
    final os = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.fuchsia => 'Fuchsia',
    };
    final version =
        (data['version'] ??
                data['systemVersion'] ??
                data['displayVersion'] ??
                data['osRelease'] ??
                '')
            .toString();
    return version.trim().isEmpty ? os : '$os $version';
  }
}
