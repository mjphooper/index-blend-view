import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:index_blend_view/src/page_controller_index.dart';

void main() {
  group('PageControllerIndex', () {
    late _FakePageController controller;
    late PageControllerIndex index;

    setUp(() {
      controller = _FakePageController(initialPage: 2);
      index = PageControllerIndex(controller);
    });

    tearDown(() {
      controller.dispose();
    });

    test('reports the initial page before a page view attaches', () {
      expect(index.value, 2.0);
    });

    test('reports the initial page before the page view lays out', () {
      controller.attachPageView(null);

      expect(index.value, 2.0);
    });

    test('reports the page while one page view is attached', () {
      controller.attachPageView(3.25);

      expect(index.value, 3.25);
    });

    test('reports the page of the first page view while two are attached', () {
      final first = controller.attachPageView(3.25);
      controller.attachPageView(0.0);

      expect(index.value, 3.25);

      first.page = 4.0;

      expect(index.value, 4.0);
    });

    test('notifies its listeners when the controller notifies', () {
      var notifications = 0;
      void listener() => notifications++;
      index.addListener(listener);

      controller.notifyListeners();

      expect(notifications, 1);
    });

    test('stops notifying a listener once it is removed', () {
      var notifications = 0;
      void listener() => notifications++;
      index
        ..addListener(listener)
        ..removeListener(listener);

      controller.notifyListeners();

      expect(notifications, 0);
    });

    test('equals another on the same controller', () {
      final other = PageControllerIndex(controller);

      expect(index, other);
      expect(index.hashCode, other.hashCode);
    });

    test('differs from one on another controller', () {
      final otherController = _FakePageController(initialPage: 2);
      addTearDown(otherController.dispose);

      expect(index, isNot(PageControllerIndex(otherController)));
    });
  });
}

/// A [PageController] whose attached page views are added by the test, with
/// no widgets involved.
class _FakePageController extends PageController {
  _FakePageController({super.initialPage});

  final _positions = <_FakePagePosition>[];

  /// Attaches a page view on [page], null until it lays out.
  ///
  /// Like a real controller, this doesn't notify the listeners.
  _FakePagePosition attachPageView(double? page) {
    final position = _FakePagePosition(page);
    _positions.add(position);
    return position;
  }

  @override
  Iterable<ScrollPosition> get positions => _positions;

  /// Override for test visibility only.
  @override
  void notifyListeners() => super.notifyListeners();
}

/// The position of a page view attached to a [_FakePageController].
class _FakePagePosition extends Fake implements ScrollPosition, PageMetrics {
  _FakePagePosition(this.page);

  @override
  double? page;
}
