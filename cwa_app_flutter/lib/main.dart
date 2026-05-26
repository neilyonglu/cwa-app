import 'package:cwa_app_client/cwa_app_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

import 'features/home/home_screen.dart';
import 'theme/app_theme.dart';

/// Serverpod client（之後串 RadarEndpoint / FavoriteEndpoint 用到）。
/// 本檔暫不會主動呼叫，但保留初始化以便日後直接接上。
late final Client client;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemOverlay);

  final serverUrl = await getServerUrl();
  client = Client(serverUrl)
    ..connectivityMonitor = FlutterConnectivityMonitor()
    ..authSessionManager = FlutterAuthSessionManager();
  client.auth.initialize();

  runApp(const CwaApp());
}

class CwaApp extends StatelessWidget {
  const CwaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CWA Rain',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.dark,
      home: const HomeScreen(),
    );
  }
}
