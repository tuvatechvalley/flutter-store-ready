import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/item.dart';
import 'date_format.dart';
import 'items_controller.dart';

class ItemDetailPage extends ConsumerWidget {
  const ItemDetailPage({required this.id, super.key});

  /// Already validated by the router (see `InputValidators.isSafeId`).
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(itemDetailProvider(id));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.itemDetailTitle)),
      body: AsyncValueView<Item>(
        value: value,
        onRetry: () => ref.invalidate(itemDetailProvider(id)),
        data: (item) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: Insets.lg),
          child: ResponsiveCenter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  item.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: Insets.sm),
                Text(
                  l10n.lastUpdated(formatDate(context, item.updatedAt)),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: Insets.lg),
                SelectableText(item.description),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
