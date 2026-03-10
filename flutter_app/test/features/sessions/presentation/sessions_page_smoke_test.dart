import 'dart:io';
import 'dart:convert';

import 'package:codexm_flutter/app/theme/app_theme.dart';
import 'package:codexm_flutter/features/sessions/presentation/pages/sessions_page.dart';
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

  testWidgets('shows workspace empty state guidance', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const SessionsPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('先准备一个工作区'), findsOneWidget);
    expect(find.text('前往工作区'), findsOneWidget);
  });

  testWidgets('shows session list sidebar on expanded width', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.reset());

    final workspacesDir = Directory('${documentsDir.path}/workspaces');
    final indexDir = Directory('${workspacesDir.path}/.index');
    await indexDir.create(recursive: true);
    await File('${indexDir.path}/workspaces.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'version': 1,
        'workspaces': [
          {
            'id': 'test',
            'name': '测试工作区',
            'createdAt': 1,
            'localPath': '${workspacesDir.path}/test/',
            'git': null,
            'webdav': null,
          },
        ],
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const SessionsPage(activeWorkspaceId: 'test'),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('会话'), findsAtLeastNWidgets(1));
  });
}
