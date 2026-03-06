import 'dart:convert';

import 'package:codexm_flutter/features/codex/application/json_rpc_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolves request and emits notifications', () async {
    late JsonRpcClient client;
    final sentLines = <String>[];

    client = JsonRpcClient((line) async {
      sentLines.add(line);
      final message = jsonDecode(line) as Map<String, dynamic>;
      if (message['method'] == 'ping') {
        await client.handleLine(
          jsonEncode(<String, Object?>{
            'id': message['id'],
            'result': <String, Object?>{'ok': true},
          }),
        );
      }
    });

    final notifications = <JsonRpcNotification>[];
    final sub = client.notifications.listen(notifications.add);

    final result = await client.request<Object?>(
      'ping',
      params: const <String, Object?>{'value': 1},
    );
    await client.handleLine(
      jsonEncode(<String, Object?>{
        'method': 'item/agentMessage/delta',
        'params': <String, Object?>{
          'delta': <String, Object?>{'text': 'hello'},
        },
      }),
    );

    expect((result as Map)['ok'], isTrue);
    expect(sentLines.single, contains('"method":"ping"'));
    expect(notifications.single.method, 'item/agentMessage/delta');

    await sub.cancel();
    await client.close();
  });

  test('handles server requests via request handler', () async {
    final sentLines = <String>[];
    final client = JsonRpcClient((line) async {
      sentLines.add(line);
    });

    client.serverRequestHandler = (request) async {
      expect(request.method, 'workspace/read');
      return <String, Object?>{'accepted': true};
    };

    await client.handleLine(
      jsonEncode(<String, Object?>{
        'id': 7,
        'method': 'workspace/read',
        'params': const <String, Object?>{'path': '/tmp/demo'},
      }),
    );

    final response = jsonDecode(sentLines.single) as Map<String, dynamic>;
    expect(response['id'], 7);
    expect((response['result'] as Map)['accepted'], isTrue);
    await client.close();
  });
}
