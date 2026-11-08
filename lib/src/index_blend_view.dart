import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A widget that blends between neighboring items, driven by a fractional
/// index.
///
/// This widget listens to [index]. On a whole number, it renders the item at
/// that index. Between two whole numbers, it renders the items either side
/// and blends between them by the fractional part. For example, an index of
/// `2.25` renders item 2 with an animation value of `0.75` and item 3 with
/// `0.25`.
///
/// As with [ListView.builder], items are built lazily: [itemBuilder] is
/// called only for the one or two items required by [index], so the list can
/// be long, or unbounded when [itemCount] is null.
///
/// ## Example
///
/// ```dart
/// const images = ['image1.jpg', 'image2.jpg', 'image3.jpg'];
///
/// IndexBlendView(
///   index: tabController.animation!,
///   itemCount: images.length,
///   itemBuilder: (context, index) => Image.asset(images[index]),
/// )
/// ```
///
/// ## Custom transitions
///
/// By default, items fade in and out with a [FadeTransition]. Pass a
/// [transitionBuilder] for other effects, such as scaling, sliding, or a
/// combination:
///
/// ```dart
/// IndexBlendView(
///   index: myIndex,
///   itemCount: myItems.length,
///   itemBuilder: (context, index) => MyWidget(myItems[index]),
///   transitionBuilder: (child, animation) {
///     return ScaleTransition(
///       scale: animation,
///       child: FadeTransition(
///         opacity: animation,
///         child: child,
///       ),
///     );
///   },
/// )
/// ```
class IndexBlendView extends StatefulWidget {
  /// Creates a widget that blends between neighboring items, driven by
  /// [index].
  const IndexBlendView({
    required this.index,
    required this.itemBuilder,
    this.itemCount,
    this.transitionBuilder = AnimatedSwitcher.defaultTransitionBuilder,
    this.layoutBuilder = AnimatedSwitcher.defaultLayoutBuilder,
    super.key,
  }) : assert(
         itemCount == null || itemCount >= 0,
         'IndexBlendView.itemCount must not be negative, but its value was '
         '$itemCount.',
       );

  /// The fractional index to blend at.
  ///
  /// The whole part picks the lower item and the fractional part is how far
  /// the blend has moved on to the higher one. When [itemCount] is given, the
  /// index is clamped to the items, so an index past either end shows the end
  /// item at full strength. Otherwise it is clamped to zero and above.
  final ValueListenable<double> index;

  /// Builds the widget for the item at a given index.
  ///
  /// When [itemCount] is given, the index is always in the range `0` to
  /// `itemCount - 1`. Otherwise it can be any non-negative integer. The widget
  /// is then wrapped in the transition animation.
  final IndexedWidgetBuilder itemBuilder;

  /// The number of items, or null for an unbounded list.
  ///
  /// When given, an [index] past the last item keeps showing it at full
  /// strength, and an item count of `0` renders nothing. When null,
  /// [itemBuilder] is called with any whole index that [index] reaches.
  final int? itemCount;

  /// A function that wraps each item with an animation that transitions it in
  /// as the animation runs forward and out as it runs in reverse. This is
  /// called each time this widget builds, which happens when [index] moves to
  /// different items, not for every change in its value.
  ///
  /// The default is [AnimatedSwitcher.defaultTransitionBuilder].
  ///
  /// See also:
  ///
  ///  * [AnimatedSwitcherTransitionBuilder] for more information about
  ///    how a transition builder should function.
  final AnimatedSwitcherTransitionBuilder transitionBuilder;

  /// A function that wraps the two items with a widget that lays them both
  /// out. This is called every time this widget is built.
  ///
  /// The default is [AnimatedSwitcher.defaultLayoutBuilder].
  ///
  /// The item at the higher index is the `currentChild`, and the item at the
  /// lower index is in `previousChildren`. Once [index] settles on a whole
  /// number, its item is the `currentChild` alone.
  ///
  /// See also:
  ///
  ///  * [AnimatedSwitcherLayoutBuilder] for more information about
  ///    how a layout builder should function.
  final AnimatedSwitcherLayoutBuilder layoutBuilder;

  @override
  State<IndexBlendView> createState() => _IndexBlendViewState();
}

class _IndexBlendViewState extends State<IndexBlendView> {
  final _transitionNotifier = ValueNotifier<double>(0.0);

  int _indexA = 0;
  int _indexB = 0;

  @override
  void initState() {
    super.initState();

    widget.index.addListener(_indexListener);
    _syncIndex();
  }

  @override
  void didUpdateWidget(IndexBlendView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.index != oldWidget.index) {
      oldWidget.index.removeListener(_indexListener);
      widget.index.addListener(_indexListener);
    }

    _syncIndex();
  }

  @override
  void dispose() {
    widget.index.removeListener(_indexListener);
    _transitionNotifier.dispose();
    super.dispose();
  }

  void _indexListener() {
    final haveIndicesChanged = _syncIndex();

    // Rebuild only if the indices now point at different items. The progress
    // reaches the transitions through their animation, so they repaint without
    // a rebuild.
    if (haveIndicesChanged) {
      setState(() {
        // _syncIndex has already updated the item indices.
      });
    }
  }

  /// Reads the latest value of [IndexBlendView.index] and updates [_indexA],
  /// [_indexB] and the transition value to match it.
  ///
  /// Returns `true` only when [_indexA] or [_indexB] changed, not when only the
  /// transition value did.
  bool _syncIndex() {
    final clampedIndex = _clampIndex(widget.index.value);
    final indexA = clampedIndex.floor();
    final indexB = clampedIndex.ceil();
    final changed = indexA != _indexA || indexB != _indexB;

    _indexA = indexA;
    _indexB = indexB;
    _transitionNotifier.value = clampedIndex - indexA;

    return changed;
  }

  /// Clamps [index] to the items when [IndexBlendView.itemCount] is given, or
  /// to zero and above when it is null.
  ///
  /// An index within [precisionErrorTolerance] of a whole number is first
  /// snapped to it, so a rounding error doesn't stop the index settling.
  ///
  /// With no items, this clamps to zero; [build] renders nothing then, so the
  /// indices are never used.
  double _clampIndex(double index) {
    assert(
      index.isFinite,
      'IndexBlendView.index must be finite, but its value was $index.',
    );

    // Sources such as a page controller can land a rounding error off a whole
    // number, which would leave two items rendered instead of one.
    final wholeIndex = index.roundToDouble();
    final snappedIndex = (index - wholeIndex).abs() < precisionErrorTolerance
        ? wholeIndex
        : index;

    final itemCount = widget.itemCount;
    final maxIndex = itemCount == null
        ? double.infinity
        : math.max(itemCount - 1.0, 0.0);

    // Prevent blending to a non-existing item. An unbounded list has no last
    // item, so only its start is clamped.
    return snappedIndex.clamp(0.0, maxIndex);
  }

  /// Builds the item at [index], wrapped in its transition driven by
  /// [animation].
  ///
  /// The item is keyed by [index], so it keeps its element and state when it
  /// moves between slots.
  Widget _buildItem(int index, Animation<double> animation) {
    return KeyedSubtree(
      key: ValueKey(index),
      child: widget.transitionBuilder(
        widget.itemBuilder(context, index),
        animation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0) {
      return const SizedBox.shrink();
    }

    // While settled, both indices are the same, so render the item once, at
    // full strength. Its key keeps the element it had if it was already
    // rendered, so it does not lose state. A single item is always settled.
    if (_indexA == _indexB) {
      return widget.layoutBuilder(
        _buildItem(_indexA, kAlwaysCompleteAnimation),
        const [],
      );
    }

    final animation = Animation.fromValueListenable(_transitionNotifier);

    return widget.layoutBuilder(_buildItem(_indexB, animation), [
      _buildItem(_indexA, ReverseAnimation(animation)),
    ]);
  }
}
