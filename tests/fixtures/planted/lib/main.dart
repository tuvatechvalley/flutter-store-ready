import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.openBox('auth');
  // planted: permission asked while the app starts
  await Geolocator.requestPermission();
  // planted: ad SDK started with no consent step anywhere
  await MobileAds.instance.initialize();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    // planted: the whole app ignores font sizes above 1.3x
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
      ),
      child: child!,
    ),
    theme: ThemeData(
      // planted: every button becomes full-width
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      ),
    ),
    home: Scaffold(
      bottomNavigationBar: BottomNavigationBar(items: const []),
    ),
  );
}
