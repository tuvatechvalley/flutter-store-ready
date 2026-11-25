import 'package:flutter_test/flutter_test.dart';
import 'package:starter_app/core/errors/app_failure.dart';
import 'package:starter_app/core/providers.dart';
import 'package:starter_app/features/items/data/items_repository.dart';
import 'package:starter_app/features/items/presentation/items_controller.dart';

import '../helpers/test_app.dart';

void main() {
  late FakeItemsRepository repo;

  setUp(() => repo = FakeItemsRepository(latency: Duration.zero));

  test('loads first page, then paginates to the end', () async {
    final container = createTestContainer(
      overrides: [itemsRepositoryProvider.overrideWithValue(repo)],
    );
    final sub = container.listen(itemsControllerProvider, (_, _) {});
    addTearDown(sub.close);

    var state = await container.read(itemsControllerProvider.future);
    expect(state.items, hasLength(20));
    expect(state.hasMore, isTrue);

    final controller = container.read(itemsControllerProvider.notifier);
    await controller.loadMore();
    await controller.loadMore();
    state = container.read(itemsControllerProvider).requireValue;
    expect(state.items, hasLength(45));
    expect(state.hasMore, isFalse);
    expect(
      state.items.map((i) => i.id).toSet(),
      hasLength(45),
      reason: 'no duplicates',
    );
  });

  test('first page failure surfaces a typed error', () async {
    repo.nextFailure = const NetworkFailure();
    final container = createTestContainer(
      overrides: [itemsRepositoryProvider.overrideWithValue(repo)],
    );
    final sub = container.listen(itemsControllerProvider, (_, _) {});
    addTearDown(sub.close);

    await expectLater(
      container.read(itemsControllerProvider.future),
      throwsA(isA<NetworkFailure>()),
    );
    expect(
      container.read(itemsControllerProvider).error,
      isA<NetworkFailure>(),
    );
  });

  test('load-more failure keeps loaded items and allows retry', () async {
    final container = createTestContainer(
      overrides: [itemsRepositoryProvider.overrideWithValue(repo)],
    );
    final sub = container.listen(itemsControllerProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(itemsControllerProvider.future);
    final controller = container.read(itemsControllerProvider.notifier);

    repo.nextFailure = const TimeoutFailure();
    await controller.loadMore();
    var state = container.read(itemsControllerProvider).requireValue;
    expect(state.items, hasLength(20));
    expect(state.loadMoreFailure, isA<TimeoutFailure>());

    await controller.loadMore();
    state = container.read(itemsControllerProvider).requireValue;
    expect(state.items, hasLength(40));
    expect(state.loadMoreFailure, isNull);
  });
}
