import 'package:core_ui/widgets.dart';
import 'package:flutter/material.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CatalogCubit, CatalogState>(
      builder: (context, state) {
        if (state.isLoading) return const AppLoader();
        if (state.hasFailed) return AppFailureCard(onRetry: () {});
        return const AppText('Privacy policy: https://acme.example/privacy');
      },
    );
  }
}
