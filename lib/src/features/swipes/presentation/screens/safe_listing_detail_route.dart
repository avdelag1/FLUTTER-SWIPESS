import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/swipes/data/repositories/listing_repository.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/listing_detail_screen.dart';

/// Network-safe entry point for deep-linked listing pages.
///
/// A Supabase request must never leave the user on an endless spinner. This
/// wrapper owns one request at a time, times it out, and relies on the shared
/// app header for navigation so a second Back control never overlaps it.
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
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Center(
            child: snapshot.connectionState != ConnectionState.done
                ? Column(
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
                        style: TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12),
                      FilledButton(
                        onPressed: _retry,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
