import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/providers.dart';
import '../domain/item.dart';

@immutable
final class ItemsState {
  const ItemsState({
    required this.items,
    required this.nextCursor,
    this.isLoadingMore = false,
    this.loadMoreFailure,
  });

  final List<Item> items;
  final String? nextCursor;
  final bool isLoadingMore;

  /// Pagination errors are shown inline, without discarding loaded items.
  final AppFailure? loadMoreFailure;

  bool get hasMore => nextCursor != null;

  ItemsState copyWith({
    List<Item>? items,
    String? Function()? nextCursor,
    bool? isLoadingMore,
    AppFailure? Function()? loadMoreFailure,
  }) => ItemsState(
    items: items ?? this.items,
    nextCursor: nextCursor != null ? nextCursor() : this.nextCursor,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreFailure: loadMoreFailure != null
        ? loadMoreFailure()
        : this.loadMoreFailure,
  );
}

final itemsControllerProvider =
    AsyncNotifierProvider.autoDispose<ItemsController, ItemsState>(
      ItemsController.new,
    );

final class ItemsController extends AsyncNotifier<ItemsState> {
  CancelToken? _cancelToken;

  @override
  Future<ItemsState> build() async {
    // Cancel in-flight requests when the screen is closed.
    final token = _cancelToken = CancelToken();
    ref.onDispose(token.cancel);
    final page = await ref
        .watch(itemsRepositoryProvider)
        .fetchPage(cancelToken: token);
    return ItemsState(items: page.items, nextCursor: page.nextCursor);
  }

  /// Pull-to-refresh: keeps current data visible until new data arrives.
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } on Object {
      // The error is already exposed through `state` and rendered by the UI.
    }
  }

  Future<void> loadMore() async {
    if (!ref.mounted) return; // may be called from a post-frame callback
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(
      current.copyWith(isLoadingMore: true, loadMoreFailure: () => null),
    );
    try {
      final page = await ref
          .read(itemsRepositoryProvider)
          .fetchPage(cursor: current.nextCursor, cancelToken: _cancelToken);
      if (!ref.mounted) return;
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...page.items],
          nextCursor: () => page.nextCursor,
          isLoadingMore: false,
          // `current` is the state before this call and may still carry the
          // previous failure: a successful retry must clear it.
          loadMoreFailure: () => null,
        ),
      );
    } on Object catch (error, stackTrace) {
      if (!ref.mounted) return;
      final failure = mapToFailure(error, stackTrace);
      if (failure is CancelledFailure) return;
      ref.read(loggerProvider).error('Load more failed', failure, stackTrace);
      state = AsyncData(
        current.copyWith(isLoadingMore: false, loadMoreFailure: () => failure),
      );
    }
  }
}

/// Detail of a single item. `family` keyed by the (validated) id.
final itemDetailProvider = FutureProvider.autoDispose.family<Item, String>((
  ref,
  id,
) {
  final token = CancelToken();
  ref.onDispose(token.cancel);
  return ref.watch(itemsRepositoryProvider).fetchById(id, cancelToken: token);
});
