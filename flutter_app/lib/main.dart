import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/app_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = CodexmAppServices.create();
  await services.initialize();
  runApp(CodexmFlutterApp(services: services));
}
