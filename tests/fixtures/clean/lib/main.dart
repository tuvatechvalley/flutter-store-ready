import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) => logger.error(details.exception);
  PlatformDispatcher.instance.onError = (error, stack) {
    logger.error(error, stack);
    return true;
  };
  ErrorWidget.builder = (details) => const AppErrorWidget();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: ThemeData(
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
      ),
    ),
    home: Scaffold(
      body: const SafeArea(child: HomeScreen()),
      bottomNavigationBar: NavigationBar(destinations: const []),
    ),
  );
}
