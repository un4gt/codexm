import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codexm_native/codexm_native_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelCodexmNative platform = MethodChannelCodexmNative();
  const MethodChannel channel = MethodChannel('codexm_native/methods');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'getPlatformVersion':
              return '42';
            case 'update.getAppInfo':
              return {
                'packageName': 'com.example.app',
                'versionName': '1.2.3',
                'versionCode': 123,
              };
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });

  test('getAppUpdateAppInfo', () async {
    final info = await platform.getAppUpdateAppInfo();

    expect(info.packageName, 'com.example.app');
    expect(info.versionName, '1.2.3');
    expect(info.versionCode, 123);
  });
}
