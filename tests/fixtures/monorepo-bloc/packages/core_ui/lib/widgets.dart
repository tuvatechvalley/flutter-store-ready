import 'package:flutter/material.dart';

class AppText extends StatelessWidget {
  const AppText(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(text);
}

void showAppError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

class AppLoader extends StatelessWidget {
  const AppLoader({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class AppFailureCard extends StatelessWidget {
  const AppFailureCard({required this.onRetry, super.key});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Text('Could not connect. Check your internet and try again.'),
      ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
    ],
  );
}
