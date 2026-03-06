import 'package:codexm_flutter/features/settings/application/codex_smoke_rpc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds initialize request and recognizes response', () {
    final rpc = CodexSmokeRpc();
    final requestId = rpc.nextRequestId();

    final request = rpc.tryDecodeMessage(rpc.buildInitializeRequest(requestId));
    expect(request?['id'], requestId);
    expect(request?['method'], 'initialize');

    final response = rpc.tryDecodeMessage('{"jsonrpc":"2.0","id":$requestId,"result":{"ok":true}}');
    expect(response, isNotNull);
    expect(rpc.isInitializeResponse(response!, requestId), isTrue);
  });

  test('extracts thread id and assistant delta', () {
    final rpc = CodexSmokeRpc();

    final threadMessage = rpc.tryDecodeMessage(
      '{"jsonrpc":"2.0","id":2,"result":{"thread":{"id":"thread_123"}}}',
    );
    expect(rpc.extractThreadId(threadMessage!), 'thread_123');

    final deltaMessage = rpc.tryDecodeMessage(
      '{"jsonrpc":"2.0","method":"item/agentMessage/delta","params":{"delta":{"text":"hello"}}}',
    );
    expect(rpc.extractAssistantDelta(deltaMessage!), 'hello');
  });
}
