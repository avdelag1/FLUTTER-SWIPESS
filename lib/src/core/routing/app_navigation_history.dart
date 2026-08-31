import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Small app-level route history used only when a screen cannot perform a real
/// Navigator/GoRouter pop. This lets Back return to the page the user actually
/// came from instead of jumping to Dashboard.
///
/// We still prefer a native/router pop first because that preserves the exact
/// widget instance, scroll offset and in-page state. History is the fallback for
/// destinations reached with `go()`, which intentionally replaces the router
/// stack.
abstract final class AppNavigationHistory {
  static const int _maxEntries = 60;
  static final List<String> _entries = <String>[];

  static String? get current => _entries.isEmpty ? null : _entries.last;

  static void record(String location) {
    final normalized = _normalize(location);
    if (normalized.isEmpty) return;
    if (_entries.isNotEmpty && _entries.last == normalized) return;
    _entries.add(normalized);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }
  }

  /// Return the route immediately before [currentLocation] without mutating
  /// history. Overlay-close actions use this so closing PEARL/AI/Map cannot
  /// accidentally eat a page from Back history.
  static String? previousFor(String currentLocation) {
    final current = _normalize(currentLocation);
    if (_entries.isEmpty) return null;

    var index = _entries.length - 1;
    if (_entries[index] == current) {
      index -= 1;
    } else {
      final found = _entries.lastIndexOf(current);
      if (found >= 0) index = found - 1;
    }
    if (index < 0 || index >= _entries.length) return null;
    return _entries[index];
  }

  /// Previous page whose path is not the same as [currentLocation].
  /// Skips stacked copies of the same tool (AI listing builder, etc.).
  static String? previousDistinctFrom(String currentLocation) {
    final currentPath = _pathOf(_normalize(currentLocation));
    if (currentPath.isEmpty || _entries.isEmpty) return previousFor(currentLocation);

    for (var i = _entries.length - 1; i >= 0; i--) {
      if (_pathOf(_entries[i]) != currentPath) return _entries[i];
    }
    return null;
  }

  static String _pathOf(String location) {
    final uri = Uri.tryParse(location);
    if (uri == null) return location;
    var path = uri.path.isEmpty ? '/' : uri.path;
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return path;
  }

  /// Remove [currentLocation] from the top and return the page immediately
  /// before it. The returned entry remains in the stack, so routing to it does
  /// not create a duplicate history item.
  static String? consumeCurrentAndPrevious(String currentLocation) {
    final current = _normalize(currentLocation);
    if (_entries.isEmpty) return null;

    if (_entries.last == current) {
      _entries.removeLast();
    } else {
      final index = _entries.lastIndexOf(current);
      if (index >= 0) {
        _entries.removeRange(index, _entries.length);
      }
    }
    return _entries.isEmpty ? null : _entries.last;
  }

  /// Reconcile history after a successful router pop. This prevents a later
  /// route-information notification from turning Back into a two-page loop.
  static void reconcilePop({
    required String before,
    required String after,
  }) {
    final from = _normalize(before);
    final to = _normalize(after);
    if (from.isEmpty || to.isEmpty || from == to) return;

    if (_entries.isNotEmpty && _entries.last == from) {
      _entries.removeLast();
    }
    final existing = _entries.lastIndexOf(to);
    if (existing >= 0 && existing < _entries.length - 1) {
      _entries.removeRange(existing + 1, _entries.length);
    } else if (_entries.isEmpty || _entries.last != to) {
      record(to);
    }
  }

  static String _normalize(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return trimmed;
    var path = uri.path.isEmpty ? '/' : uri.path;
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    final query = uri.hasQuery ? '?${uri.query}' : '';
    final fragment = uri.hasFragment ? '#${uri.fragment}' : '';
    return '$path$query$fragment';
  }
}

/// Listens to GoRouter's route-information provider once for the whole app.
class NavigationHistoryBootstrap extends StatefulWidget {
  const NavigationHistoryBootstrap({
    super.key,
    required this.router,
    required this.child,
  });

  final GoRouter router;
  final Widget child;

  @override
  State<NavigationHistoryBootstrap> createState() =>
      _NavigationHistoryBootstrapState();
}

class _NavigationHistoryBootstrapState extends State<NavigationHistoryBootstrap> {
  @override
  void initState() {
    super.initState();
    widget.router.routeInformationProvider.addListener(_record);
    WidgetsBinding.instance.addPostFrameCallback((_) => _record());
  }

  @override
  void didUpdateWidget(covariant NavigationHistoryBootstrap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.router, widget.router)) {
      oldWidget.router.routeInformationProvider.removeListener(_record);
      widget.router.routeInformationProvider.addListener(_record);
      _record();
    }
  }

  @override
  void dispose() {
    widget.router.routeInformationProvider.removeListener(_record);
    super.dispose();
  }

  void _record() {
    AppNavigationHistory.record(
      widget.router.routeInformationProvider.value.uri.toString(),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
