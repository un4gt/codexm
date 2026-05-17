import 'dart:io';
import 'dart:convert';

import 'package:codexm_flutter/app/theme/app_theme.dart';
import 'package:codexm_flutter/features/sessions/presentation/pages/sessions_page.dart';
import 'package:codexm_flutter/l10n/app_localizations.dart';
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

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeChannel, (call) async {
          switch (call.method) {
            case 'git.recentCommits':
              return const <Map<String, Object?>>[];
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
    await tester.pumpWidget(_testApp(const SessionsPage()));
    await tester.pumpAndSettle();

    expect(find.text('先准备一个工作区'), findsOneWidget);
    expect(find.text('前往工作区'), findsOneWidget);
  });

  testWidgets('keeps single-column chat layout on expanded width', (
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
      _testApp(const SessionsPage(activeWorkspaceId: 'test')),
    );
    final switchSessionButton = find.byTooltip('切换会话（1）');
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

    expect(switchSessionButton, findsOneWidget);
    expect(composerHint, findsOneWidget);
    expect(find.text('回到会话'), findsNothing);
    expect(find.text('最近会话'), findsNothing);
  });

  testWidgets('shows slash suggestions above composer and keeps focus on tap', (
    WidgetTester tester,
  ) async {
    _seedWorkspace(documentsDir);

    await tester.pumpWidget(
      _testApp(const SessionsPage(activeWorkspaceId: 'test')),
    );
    await _pumpUntilFound(tester, find.text('在这里输入消息...'));

    await tester.enterText(find.byType(TextField), '/');
    await tester.pump(const Duration(milliseconds: 220));

    final overlayFinder = find.byKey(
      const ValueKey('composer-suggestions-overlay'),
    );
    expect(overlayFinder, findsOneWidget);
    expect(find.text('/help'), findsOneWidget);

    final overlayBottom = tester.getBottomLeft(overlayFinder).dy;
    final textFieldTop = tester.getTopLeft(find.byType(TextField)).dy;
    expect(overlayBottom, lessThanOrEqualTo(textFieldTop));

    await tester.tap(find.text('/help'));
    await tester.pump(const Duration(milliseconds: 220));

    expect(
      find.byKey(const ValueKey('composer-suggestions-overlay')),
      findsNothing,
    );
    expect(
      (tester.widget(find.byType(TextField)) as TextField).focusNode?.hasFocus,
      isTrue,
    );
    expect(find.text('/help'), findsNothing);
  });

  testWidgets('shows mention loading, empty, and success states', (
    WidgetTester tester,
  ) async {
    final workspaceLocalPath = _seedWorkspace(documentsDir);

    await tester.pumpWidget(
      _testApp(const SessionsPage(activeWorkspaceId: 'test')),
    );
    await _pumpUntilFound(tester, find.text('在这里输入消息...'));

    await tester.enterText(find.byType(TextField), '@');
    await tester.pump();
    expect(
      find.byKey(const ValueKey('composer-mention-loading')),
      findsOneWidget,
    );

    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('composer-mention-empty')),
    );
    expect(
      find.byKey(const ValueKey('composer-mention-empty')),
      findsOneWidget,
    );

    await tester.runAsync(() async {
      await File('$workspaceLocalPath/lib/main.dart').create(recursive: true);
      await File(
        '$workspaceLocalPath/lib/main.dart',
      ).writeAsString('void main() {}');
    });

    await tester.enterText(find.byType(TextField), '');
    await tester.pump(const Duration(milliseconds: 80));
    await tester.enterText(find.byType(TextField), '@main');
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('composer-mention-suggestions')),
    );

    expect(
      find.byKey(const ValueKey('composer-mention-suggestions')),
      findsOneWidget,
    );
    expect(find.text('lib/main.dart'), findsOneWidget);
    expect(find.text('文件'), findsOneWidget);
  });
}

Widget _testApp(Widget child) {
  return MaterialApp(
    theme: buildAppTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

String _seedWorkspace(Directory documentsDir) {
  final workspacesDirPath = '${documentsDir.path}/workspaces';
  final workspaceLocalPath = '$workspacesDirPath/test/repo';
  final indexDir = Directory('$workspacesDirPath/.index');
  indexDir.createSync(recursive: true);
  Directory(workspaceLocalPath).createSync(recursive: true);
  File('${indexDir.path}/workspaces.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'workspaces': [
        {
          'id': 'test',
          'name': '测试工作区',
          'createdAt': 1,
          'localPath': '$workspacesDirPath/test/',
          'git': null,
          'webdav': null,
        },
      ],
    }),
  );
  return workspaceLocalPath;
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 200; i += 1) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pump();
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  expect(finder, findsOneWidget);
}
