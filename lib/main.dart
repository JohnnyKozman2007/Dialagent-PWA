import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'router/app_router.dart';  // ensure this import exists
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  final prefs = await SharedPreferences.getInstance();

  runApp(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Restaurant PWA',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(primary: Colors.green),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(primary: Colors.green.shade400),
        scaffoldBackgroundColor: Colors.grey.shade900,
        cardColor: Colors.grey.shade800,
      ),
      themeMode: themeMode,
      routerConfig: router,   // <-- changed from appRouter to router
      debugShowCheckedModeBanner: false,
    );
  }
}
