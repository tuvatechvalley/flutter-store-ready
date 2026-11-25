import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/item.dart';
import 'date_format.dart';
import 'items_controller.dart';

class ItemsPage extends ConsumerWidget {
  const ItemsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(itemsControllerProvider);
    final controller = ref.read(itemsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.itemsTitle)),
      body: AsyncValueView<ItemsState>(
        value: value,
        onRetry: () => ref.invalidate(itemsControllerProvider),
        isEmpty: (s) => s.items.isEmpty,
        empty: RefreshIndicator.adaptive(
          onRefresh: controller.refresh,
          // Needs a scrollable to allow pull-to-refresh on an empty list.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: constraints.maxHeight,
                child: EmptyView(
                  title: l10n.itemsEmptyTitle,
                  message: l10n.itemsEmptyMessage,
                ),
              ),
            ),
          ),
        ),
        data: (state) => RefreshIndicator.adaptive(
          onRefresh: controller.refresh,
          child: _ItemsList(state: state, onLoadMore: controller.loadMore),
        ),
      ),
    );
  }
}

class _ItemsList extends StatelessWidget {
  const _ItemsList({required this.state, required this.onLoadMore});

  final ItemsState state;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) {
    final size = WindowSize.of(context);
    final footer = _Footer(state: state, onLoadMore: onLoadMore);

    // Pagination is triggered by the footer becoming visible (see _Footer),
    // which also works when the first page does not fill the screen.
    if (size.isCompact) {
      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.items.length + 1,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) =>
            i == state.items.length ? footer : _ItemTile(item: state.items[i]),
      );
    }
    // Tablets / landscape: grid of cards instead of stretched rows. Tile
    // height follows the user's font scale so text never overflows.
    final tileHeight = MediaQuery.textScalerOf(context).scale(100) + 48;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.all(Insets.page(size)),
          sliver: SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 420,
              mainAxisExtent: tileHeight,
              mainAxisSpacing: Insets.md,
              crossAxisSpacing: Insets.md,
            ),
            itemCount: state.items.length,
            itemBuilder: (context, i) => Card(
              clipBehavior: Clip.antiAlias,
              child: _ItemTile(item: state.items[i]),
            ),
          ),
        ),
        SliverToBoxAdapter(child: footer),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${item.description}\n${l10n.lastUpdated(formatDate(context, item.updatedAt))}',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.go('/items/${Uri.encodeComponent(item.id)}'),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state, required this.onLoadMore});

  final ItemsState state;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (state.loadMoreFailure != null) {
      return Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          children: [
            Text(l10n.loadMoreFailed, textAlign: TextAlign.center),
            TextButton(
              onPressed: () => unawaited(onLoadMore()),
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }
    if (state.hasMore) {
      // Built lazily only when scrolled into view: load the next page then.
      if (!state.isLoadingMore) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => unawaited(onLoadMore()),
        );
      }
      return const LoadingView();
    }
    return const SizedBox(height: Insets.xl);
  }
}
