import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The fractional page of a page view, as a [ValueListenable].
///
/// This is internal to the package: it is not exported, and the analyzer
/// flags any use of it from another package.
///
/// Listeners are added to and removed from [controller], so they are notified
/// whenever it is. [value] is the page of the page view attached to
/// [controller]. Before a page view attaches and lays out, it is the
/// controller's [PageController.initialPage]. While more than one page view is
/// attached, as during a route transition, it is the page of the one that
/// attached first. Reading [PageController.page] then would throw.
///
/// It holds no state, so two of them on the same controller are equal. A
/// widget rebuilt with a new one keeps its listeners.
@immutable
@internal
final class PageControllerIndex implements ValueListenable<double> {
  /// Creates a [ValueListenable] of the page of [controller].
  @internal
  const PageControllerIndex(this.controller);

  /// The controller whose page this follows.
  final PageController controller;

  @override
  double get value {
    final initialPage = controller.initialPage.toDouble();

    if (controller.positions.isEmpty) return initialPage;

    // PageController.page asserts unless exactly one page view is attached, so
    // read the page of the first one directly.
    final position = controller.positions.first as PageMetrics;
    final page = position.page;

    if (page == null) return initialPage;

    return page;
  }

  @override
  void addListener(VoidCallback listener) => controller.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      controller.removeListener(listener);

  @override
  bool operator ==(Object other) =>
      other is PageControllerIndex && other.controller == controller;

  @override
  int get hashCode => controller.hashCode;
}
