import 'dart:io';

import 'package:flutter/services.dart';

import 'lan_access_models.dart';

abstract class LanAccessPlatform {
  Stream<LanNetworkSnapshot> networkSnapshots();

  Future<LanNetworkSnapshot> currentNetwork();

  Future<bool> requestNotificationPermission();

  Future<void> openNotificationSettings();

  Future<void> startForegroundService({required String message});

  Future<void> updateForegroundService({required String message});

  Future<void> stopForegroundService();
}

class MethodChannelLanAccessPlatform implements LanAccessPlatform {
  MethodChannelLanAccessPlatform({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
    bool Function()? isAndroid,
  }) : _methodChannel =
           methodChannel ?? const MethodChannel('codexm/lan_access'),
       _eventChannel =
           eventChannel ?? const EventChannel('codexm/lan_networks'),
       _isAndroid = isAndroid ?? (() => Platform.isAndroid);

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  final bool Function() _isAndroid;

  @override
  Stream<LanNetworkSnapshot> networkSnapshots() {
    if (!_isAndroid()) {
      return const Stream<LanNetworkSnapshot>.empty();
    }
    return _eventChannel.receiveBroadcastStream().map((event) {
      return LanNetworkSnapshot.fromMap(
        Map<Object?, Object?>.from(event as Map),
      );
    });
  }

  @override
  Future<LanNetworkSnapshot> currentNetwork() async {
    if (!_isAndroid()) {
      return const LanNetworkSnapshot();
    }
    final result = await _methodChannel.invokeMapMethod<Object?, Object?>(
      'getNetworkSnapshot',
    );
    return LanNetworkSnapshot.fromMap(result ?? const <Object?, Object?>{});
  }

  @override
  Future<bool> requestNotificationPermission() async {
    if (!_isAndroid()) {
      return true;
    }
    return await _methodChannel.invokeMethod<bool>(
          'requestNotificationPermission',
        ) ??
        false;
  }

  @override
  Future<void> openNotificationSettings() async {
    if (_isAndroid()) {
      await _methodChannel.invokeMethod<void>('openNotificationSettings');
    }
  }

  @override
  Future<void> startForegroundService({required String message}) async {
    if (_isAndroid()) {
      await _methodChannel.invokeMethod<void>('startForegroundService', {
        'message': message,
      });
    }
  }

  @override
  Future<void> updateForegroundService({required String message}) async {
    if (_isAndroid()) {
      await _methodChannel.invokeMethod<void>('updateForegroundService', {
        'message': message,
      });
    }
  }

  @override
  Future<void> stopForegroundService() async {
    if (_isAndroid()) {
      await _methodChannel.invokeMethod<void>('stopForegroundService');
    }
  }
}
