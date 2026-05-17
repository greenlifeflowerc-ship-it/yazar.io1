import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'game/game_settings.dart';
import 'game/skin_registry.dart';
import 'game/skin_settings.dart';
import 'screens/main_menu_screen.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'services/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Initialize Local Storage first.
  await StorageService.instance.init();
  
  // Load settings and skins from storage.
  GameSettings.instance.loadFromStorage();
  SkinSettings.instance.loadFromStorage();

  // Initialize Supabase BEFORE first frame so AuthService can hook into the
  // session immediately.
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Hydrate the auth singleton from the persisted session (if any) and start
  // listening for state changes.
  AuthService.instance.bootstrap();

  // Fire-and-forget: start decoding all skin assets so bots have skins ready
  // by the time the player enters a game.
  SkinRegistry.instance.ensureLoaded();

  runApp(const YazarApp());
}

class YazarApp extends StatelessWidget {
  const YazarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YAZAR.IO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      home: const MainMenuScreen(),
    );
  }
}
