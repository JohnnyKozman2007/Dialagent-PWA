import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_options.dart';
import 'router/app_router.dart';  // ensure this import exists

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseOptions.url,
    publishableKey: SupabaseOptions.anonKey,
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Restaurant PWA',
      theme: ThemeData(
        primarySwatch: Colors.green,
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(primary: Colors.green),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.green,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(primary: Colors.green.shade400),
        scaffoldBackgroundColor: Colors.grey.shade900,
        cardColor: Colors.grey.shade800,
      ),
      themeMode: ThemeMode.system,
      routerConfig: router,   // <-- changed from appRouter to router
      debugShowCheckedModeBanner: false,
    );
  }
}
