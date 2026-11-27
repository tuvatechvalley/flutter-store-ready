import 'package:core_ui/widgets.dart';
import 'package:flutter/material.dart';

class BrokenWrapperScreen extends StatelessWidget {
  const BrokenWrapperScreen({super.key});

  Future<void> _submit(BuildContext context) async {
    try {
      await Future<void>.value();
    } on Object catch (err) {
      showAppError(context, '$err');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 44,
      child: const AppText('Clips at 200% font scale'),
    );
  }
}
