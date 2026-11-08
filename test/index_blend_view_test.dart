import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:index_blend_view/index_blend_view.dart';

const _items = ['a', 'b', 'c', 'd', 'e', 'f'];

void main() {
  group('IndexBlendView', () {
    test('throws an assertion error given a negative item count', () {
      IndexBlendView build() => IndexBlendView(
        index: kAlwaysDismissedAnimation,
        itemCount: -1,
        itemBuilder: (context, index) => const SizedBox(),
      );

      expect(build, throwsAssertionError);
    });

    for (final value in [double.nan, double.infinity]) {
      testWidgets('throws an assertion error given an index of $value', (
        tester,
      ) async {
        await tester.pumpWidget(
          _blendView(AlwaysStoppedAnimation(value), itemCount: _items.length),
        );

        expect(tester.takeException(), isA<AssertionError>());
      });
    }

    testWidgets(
      'renders the item at the index when the item count grows to include it',
      (tester) async {
        final index = ValueNotifier(_items.length - 1.0);
        addTearDown(index.dispose);
        await tester.pumpWidget(_blendView(index, itemCount: 3));

        await tester.pumpWidget(_blendView(index, itemCount: _items.length));

        expect(_itemOpacity('f'), 1.0);
        expect(find.text('c'), findsNothing);
      },
    );

    group('when the index is replaced', () {
      late _SpyIndex oldIndex;
      late _SpyIndex newIndex;

      setUp(() {
        oldIndex = _SpyIndex(0.0);
        newIndex = _SpyIndex(3.0);
      });

      tearDown(() {
        oldIndex.dispose();
        newIndex.dispose();
      });

      testWidgets("renders the new index's item", (tester) async {
        await tester.pumpWidget(_blendView(oldIndex, itemCount: _items.length));
        await tester.pumpWidget(_blendView(newIndex, itemCount: _items.length));

        expect(_itemOpacity('d'), 1.0);
        expect(find.text('a'), findsNothing);
      });

      testWidgets('follows the new index as it changes', (tester) async {
        await tester.pumpWidget(_blendView(oldIndex, itemCount: _items.length));
        await tester.pumpWidget(_blendView(newIndex, itemCount: _items.length));

        newIndex.value = 4.0;
        await tester.pump();

        expect(_itemOpacity('e'), 1.0);
        expect(find.text('d'), findsNothing);
      });

      testWidgets('stops listening to the old index', (tester) async {
        await tester.pumpWidget(_blendView(oldIndex, itemCount: _items.length));
        await tester.pumpWidget(_blendView(newIndex, itemCount: _items.length));

        expect(oldIndex.hasListeners, isFalse);
        expect(newIndex.hasListeners, isTrue);
      });
    });

    testWidgets('stops listening to the index when removed', (tester) async {
      final index = _SpyIndex(0.0);
      addTearDown(index.dispose);
      await tester.pumpWidget(_blendView(index, itemCount: _items.length));

      await tester.pumpWidget(const SizedBox());

      expect(index.hasListeners, isFalse);
    });

    group('given the index is on the first item', () {
      late ValueNotifier<double> index;

      setUp(() => index = ValueNotifier(0.0));
      tearDown(() => index.dispose());

      testWidgets('renders only the first item', (tester) async {
        await tester.pumpWidget(_blendView(index, itemCount: _items.length));

        expect(_itemOpacity('a'), 1.0);
        expect(find.byType(FadeTransition), findsOneWidget);
      });

      testWidgets(
        'blends the neighboring items by the fraction when the index is between them',
        (tester) async {
          await tester.pumpWidget(_blendView(index, itemCount: _items.length));

          index.value = 0.25;
          await tester.pump();

          expect(_itemOpacity('a'), 0.75);
          expect(_itemOpacity('b'), 0.25);
        },
      );

      testWidgets(
        'does not rebuild the items as the index moves between them',
        (tester) async {
          await tester.pumpWidget(_blendView(index, itemCount: _items.length));

          index.value = 0.25;
          await tester.pump();
          final firstOpacity = _itemOpacity('b');
          final a = tester.widget(find.text('a'));
          final b = tester.widget(find.text('b'));

          index.value = 0.5;
          await tester.pump();

          expect(_itemOpacity('b'), greaterThan(firstOpacity));
          expect(tester.widget(find.text('a')), same(a));
          expect(tester.widget(find.text('b')), same(b));
        },
      );

      // A page controller's page can land a rounding error away from a whole
      // number after a fling, so also settle just either side of it.
      for (final (pos, value) in [
        ('on', 1.0),
        ('just below', 1.0 - 1e-12),
        ('just above', 1.0 + 1e-12),
      ]) {
        testWidgets('settles on the next item when the index lands $pos it', (
          tester,
        ) async {
          await tester.pumpWidget(_blendView(index, itemCount: _items.length));
          index.value = 0.5;
          await tester.pump();

          index.value = value;
          await tester.pump();

          expect(find.byType(FadeTransition), findsOneWidget);
          expect(_itemOpacity('b'), 1.0);
          expect(find.text('a'), findsNothing);
        });
      }

      for (final (movement, value) in [
        ('settles on', 1.0),
        ('moves past', 1.5),
      ]) {
        testWidgets(
          "keeps the incoming item's element when the index $movement it",
          (tester) async {
            await tester.pumpWidget(
              _blendView(index, itemCount: _items.length),
            );
            index.value = 0.5;
            await tester.pump();
            final incoming = find.text('b').evaluate().single;

            index.value = value;
            await tester.pump();

            expect(find.text('b').evaluate().single, same(incoming));
          },
        );
      }

      testWidgets(
        'keeps the item at full strength when the index moves given a single item',
        (tester) async {
          await tester.pumpWidget(_blendView(index, itemCount: 1));

          index.value = 0.5;
          await tester.pump();

          expect(find.byType(FadeTransition), findsOneWidget);
          expect(_itemOpacity('a'), 1.0);
        },
      );

      testWidgets('clamps a negative index to the first item', (tester) async {
        await tester.pumpWidget(_blendView(index, itemCount: _items.length));

        index.value = -0.5;
        await tester.pump();

        expect(find.byType(FadeTransition), findsOneWidget);
        expect(_itemOpacity('a'), 1.0);
      });

      testWidgets('renders nothing given no items', (tester) async {
        await tester.pumpWidget(_blendView(index, itemCount: 0));

        expect(find.byType(FadeTransition), findsNothing);
      });

      testWidgets(
        'uses the given transition builder when the index is between items',
        (tester) async {
          await tester.pumpWidget(
            _blendView(
              index,
              itemCount: _items.length,
              transitionBuilder: (child, animation) {
                return ScaleTransition(scale: animation, child: child);
              },
            ),
          );

          index.value = 0.25;
          await tester.pump();

          expect(_itemScale('a'), 0.75);
          expect(_itemScale('b'), 0.25);
        },
      );

      testWidgets(
        'gives the layout builder the correct incoming and outgoing items while blending',
        (tester) async {
          Widget? currentChild;
          var previousChildren = <Widget>[];
          await tester.pumpWidget(
            _blendView(
              index,
              itemCount: _items.length,
              layoutBuilder: (current, previous) {
                currentChild = current;
                previousChildren = previous;
                return AnimatedSwitcher.defaultLayoutBuilder(current, previous);
              },
            ),
          );

          index.value = 0.25;
          await tester.pump();

          expect(currentChild?.key, const ValueKey(1));
          expect(previousChildren.single.key, const ValueKey(0));
        },
      );
    });

    group('given the index is on the last item', () {
      late ValueNotifier<double> index;

      setUp(() => index = ValueNotifier(_items.length - 1.0));
      tearDown(() => index.dispose());

      testWidgets(
        'keeps the last item at full strength when the index goes past the end',
        (tester) async {
          await tester.pumpWidget(_blendView(index, itemCount: _items.length));

          index.value = _items.length - 0.5;
          await tester.pump();

          expect(find.byType(FadeTransition), findsOneWidget);
          expect(_itemOpacity('f'), 1.0);
        },
      );

      testWidgets('passes indices past the end to the builder when unbounded', (
        tester,
      ) async {
        await tester.pumpWidget(
          IndexBlendView(
            index: index,
            // Wraps the index itself, as an endless carousel would.
            itemBuilder: (context, index) =>
                Text(_items[index % _items.length], textDirection: .ltr),
          ),
        );

        index.value = _items.length.toDouble();
        await tester.pump();

        expect(_itemOpacity('a'), 1.0);
      });
    });
  });
}

/// A blend of [_items] driven by [index], limited to [itemCount] items when
/// given.
Widget _blendView(
  ValueListenable<double> index, {
  required int? itemCount,
  AnimatedSwitcherTransitionBuilder transitionBuilder =
      AnimatedSwitcher.defaultTransitionBuilder,
  AnimatedSwitcherLayoutBuilder layoutBuilder =
      AnimatedSwitcher.defaultLayoutBuilder,
}) {
  return IndexBlendView(
    index: index,
    itemCount: itemCount,
    itemBuilder: (context, index) => Text(_items[index], textDirection: .ltr),
    transitionBuilder: transitionBuilder,
    layoutBuilder: layoutBuilder,
  );
}

/// The opacity the blend is currently rendering [item] at, failing the test
/// unless the item holds exactly one slot.
double _itemOpacity(String item) {
  final finder = find.ancestor(
    of: find.text(item),
    matching: find.byType(FadeTransition),
  );
  expect(finder, findsOneWidget);
  final transition = finder.evaluate().single.widget as FadeTransition;
  return transition.opacity.value;
}

/// The scale the blend is currently rendering [item] at, failing the test
/// unless the item holds exactly one slot.
double _itemScale(String item) {
  final finder = find.ancestor(
    of: find.text(item),
    matching: find.byType(ScaleTransition),
  );
  expect(finder, findsOneWidget);
  final transition = finder.evaluate().single.widget as ScaleTransition;
  return transition.scale.value;
}

/// A [ValueNotifier] that exposes whether it has listeners.
class _SpyIndex extends ValueNotifier<double> {
  _SpyIndex(super._value);

  /// Override for test visibility only.
  @override
  bool get hasListeners => super.hasListeners;
}
