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
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  const nativeChannel = MethodChannel('codexm_native/methods');

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
        .setMockMethodCallHandler(nativeChannel, (call) async {
          final args = Map<String, Object?>.from(
            call.arguments as Map? ?? const <String, Object?>{},
          );
          switch (call.method) {
            case 'git.initRepository':
            case 'git.repositoryInfo':
              return {
                'branch': 'main',
                'headOid': 'abc123',
                'isClean': true,
                'isMerging': false,
              };
            case 'git.status':
              return {
                'staged': <String>[],
                'unstaged': <String>[],
                'untracked': <String>[],
                'conflicted': <String>[],
              };
            case 'git.diff':
              return '';
            case 'git.listWorktrees':
            case 'git.recentCommits':
              return <Object?>[];
            case 'git.createWorktree':
              final path = args['worktreeDirUri']!.toString();
              await Directory(path).create(recursive: true);
              return {
                'name': args['name'],
                'path': path,
                'valid': true,
                'locked': false,
              };
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeChannel, null);
    if (documentsDir.existsSync()) {
      await documentsDir.delete(recursive: true);
    }
    if (temporaryDir.existsSync()) {
      await temporaryDir.delete(recursive: true);
    }
  });

  testWidgets('shows workspace empty state guidance', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const SessionsPage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('先准备一个工作区'), findsOneWidget);
    expect(find.text('前往工作区'), findsOneWidget);
  });

  testWidgets('shows session list and chat detail on a wide tablet', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.reset());

    final workspacesDirPath = '${documentsDir.path}/workspaces';
    final workspaceLocalPath = '$workspacesDirPath/test/';
    await tester.runAsync(() async {
      final indexDir = Directory('$workspacesDirPath/.index');
      await indexDir.create(recursive: true);
      await File('${indexDir.path}/workspaces.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'version': 1,
          'workspaces': [
            {
              'id': 'test',
              'name': '测试工作区',
              'createdAt': 1,
              'localPath': workspaceLocalPath,
              'git': null,
              'webdav': null,
            },
          ],
        }),
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const SessionsPage(activeWorkspaceId: 'test'),
      ),
    );
    final composerHint = find.text('在这里输入消息...');
    for (var i = 0; i < 200; i += 1) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pump();
      if (composerHint.evaluate().isNotEmpty) {
        break;
      }
    }

    expect(composerHint, findsOneWidget);
    expect(find.text('会话'), findsOneWidget);
    expect(find.text('主会话'), findsAtLeastNWidgets(1));
    expect(find.byTooltip('新建会话'), findsOneWidget);
  });

  testWidgets('keeps slash suggestions above the phone keyboard', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio()
        ..resetViewInsets();
    });

    final workspacesDirPath = '${documentsDir.path}/workspaces';
    await tester.runAsync(() async {
      final indexDir = Directory('$workspacesDirPath/.index');
      await indexDir.create(recursive: true);
      await File('${indexDir.path}/workspaces.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'version': 1,
          'workspaces': [
            {
              'id': 'test',
              'name': '测试工作区',
              'createdAt': 1,
              'localPath': 'workspaces/test/',
              'git': null,
              'webdav': null,
            },
          ],
        }),
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const SessionsPage(activeWorkspaceId: 'test'),
      ),
    );
    for (var i = 0; i < 200 && find.text('主会话').evaluate().isEmpty; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pump();
    }
    await tester.tap(find.text('主会话').first);
    final composer = find.byType(TextField);
    for (var i = 0; i < 200 && composer.evaluate().isEmpty; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pump();
    }
    expect(composer, findsOneWidget);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    await tester.tap(composer);
    await tester.enterText(composer, '/');
    await tester.pumpAndSettle();

    final panel = find.byKey(const ValueKey('composer-suggestions-panel'));
    expect(panel, findsOneWidget);
    final panelRect = tester.getRect(panel);
    final composerRect = tester.getRect(composer);
    final keyboardTop = tester.view.physicalSize.height - 300;
    expect(panelRect.bottom, lessThanOrEqualTo(composerRect.top));
    expect(panelRect.bottom, lessThanOrEqualTo(keyboardTop));
    expect(panelRect.height, lessThanOrEqualTo(320));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(composer).controller!.text,
      '/permissions ',
    );
    expect(panel, findsNothing);
  });
}
