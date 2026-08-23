import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/listing_repository.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/listing_detail_screen.dart';
import 'package:go_router/go_router.dart';

/// Network-safe entry point for deep-linked listing pages.
///
/// A Supabase request must never leave the user on an endless spinner. This
/// wrapper owns one request at a time, times it out, and always keeps a usable
/// back button on screen while loading or after an error.
class SafeListingDetailRoute extends StatefulWidget {
  const SafeListingDetailRoute({super.key, required this.listingId});

  final String listingId;

  @override
  State<SafeListingDetailRoute> createState() => _SafeListingDetailRouteState();
}

class _SafeListingDetailRouteState extends State<SafeListingDetailRoute> {
  late Future<Listing?> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SafeListingDetailRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listingId != widget.listingId) _load();
  }

  void _load() {
    _future = ListingRepository()
        .fetchById(widget.listingId)
        .timeout(const Duration(seconds: 12));
  }

  void _retry() => setState(_load);

  void _back() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.go(AppPaths.clientDashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Listing?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData &&
            snapshot.data != null) {
          return ListingDetailScreen(listingData: snapshot.data!);
        }

        final error = snapshot.error;
        return Scaffold(
          backgroundColor: AppTheme.dashBg,
          body: Stack(
            children: [
              Center(
                child: snapshot.connectionState != ConnectionState.done
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                          SizedBox(height: 14),
                          Text(
                            'Loading listing…',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            error is TimeoutException
                                ? 'The listing took too long to load.'
                                : snapshot.data == null && error == null
                                ? 'Listing not found.'
                                : 'Could not load this listing.',
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _retry,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 8,
                left: 16,
                child: CapBackButton(onTap: _back),
              ),
            ],
          ),
        );
      },
    );
  }
}
