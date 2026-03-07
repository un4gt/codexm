import 'dart:io';

import 'package:codexm_flutter/app/theme/app_theme.dart';
import 'package:codexm_flutter/features/workspaces/presentation/pages/workspaces_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  late Directory documentsDir;
  late Directory temporaryDir;

  setUp(() async {
    documentsDir = await Directory.systemTemp.createTemp('codexm_docs_');
    temporaryDir = await Directory.systemTemp.createTemp('codexm_tmp_');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          switch (call.method) {
            case 'getApplicationDocumentsDirectory':
              return documentsDir.path;
            case 'getTemporaryDirectory':
              return temporaryDir.path;
            default:
              return null;
          }
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
          switch (call.method) {
            case 'read':
              return null;
            case 'write':
            case 'delete':
              return null;
            default:
              return null;
          }
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
    if (documentsDir.existsSync()) {
      await documentsDir.delete(recursive: true);
    }
    if (temporaryDir.existsSync()) {
      await temporaryDir.delete(recursive: true);
    }
  });

  testWidgets('shows empty workspace guidance and primary actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const WorkspacesPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('还没有工作区'), findsOneWidget);
    expect(find.text('新建工作区'), findsOneWidget);
    expect(find.text('克隆仓库'), findsOneWidget);
    expect(find.text('工作区'), findsAtLeastNWidgets(1));
    expect(find.text('只保留最小必要入口：选择工作区、进入会话、拉取或继续克隆。'), findsOneWidget);
  });
}
