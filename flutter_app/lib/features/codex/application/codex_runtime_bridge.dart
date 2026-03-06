import 'package:codexm_native/codexm_native.dart';

abstract class CodexRuntimeBridge {
  Stream<RuntimeLineEvent> runtimeLineEvents();

  Future<void> startRuntime({
    required String runtimeId,
    required String cwdPath,
    String? executablePath,
    String? assetPath,
    List<String>? args,
    Map<String, String>? env,
  });

  Future<void> stopRuntime({String? runtimeId});

  Future<void> sendRuntimeLine({
    required String runtimeId,
    required String line,
  });
}

class NativeCodexRuntimeBridge implements CodexRuntimeBridge {
  NativeCodexRuntimeBridge([CodexmNative? native]) : _native = native ?? const CodexmNative();

  final CodexmNative _native;

  @override
  Stream<RuntimeLineEvent> runtimeLineEvents() => _native.runtimeLineEvents();

  @override
  Future<void> sendRuntimeLine({
    required String runtimeId,
    required String line,
  }) {
    return _native.sendRuntimeLine(
      runtimeId: runtimeId,
      line: line,
    );
  }

  @override
  Future<void> startRuntime({
    required String runtimeId,
    required String cwdPath,
    String? executablePath,
    String? assetPath,
    List<String>? args,
    Map<String, String>? env,
  }) {
    return _native.startRuntime(
      runtimeId: runtimeId,
      cwdUri: cwdPath,
      executablePath: executablePath,
      assetPath: assetPath,
      args: args,
      env: env,
    );
  }

  @override
  Future<void> stopRuntime({String? runtimeId}) {
    return _native.stopRuntime(runtimeId: runtimeId);
  }
}
