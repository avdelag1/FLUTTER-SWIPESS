import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/core/widgets/pull_down_to_dashboard.dart';
import 'package:flutter_swipes/src/features/events/data/event_engagement_tracker.dart';
import 'package:flutter_swipes/src/features/events/presentation/providers/events_provider.dart';
import 'package:flutter_swipes/src/features/events/presentation/screens/event_detail_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Loads `/explore/events/:id` the same way Capacitor `EventoDetail` does.
class EventDetailRouteScreen extends ConsumerWidget {
  const EventDetailRouteScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(eventByIdProvider(eventId));

    return PullDownToDashboard(
      onDismiss: () => context.go(AppPaths.clientDashboard),
      child: async.when(
        loading: () => Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Center(
            child: CircularProgressIndicator(
              color: AppTheme.brandPrimary,
              strokeWidth: 2,
            ),
          ),
        ),
        error: (e, _) => _EventDetailShell(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Could not load event.',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 20),
              GestureDetector(
                onTap: () => ref.invalidate(eventByIdProvider(eventId)),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.brandPrimary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'TRY AGAIN',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 1.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        data: (event) {
          if (event == null) {
            return _EventDetailShell(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.white24,
                    size: 48,
                  ),
                  SizedBox(height: 18),
                  Text(
                    'No results found',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 1.8,
                    ),
                  ),
                  SizedBox(height: 18),
                  GestureDetector(
                    onTap: () => context.go(AppPaths.exploreEvents),
                    child: Text(
                      'GO BACK',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.brandPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          unawaited(
            EventEngagementTracker.track(
              event,
              'impression',
              source: 'event_detail',
              oncePerSession: true,
            ),
          );
          unawaited(
            EventEngagementTracker.track(
              event,
              'tap_detail',
              source: 'event_detail',
              oncePerSession: true,
            ),
          );
          return EventDetailScreen(event: event);
        },
      ),
    );
  }
}

class _EventDetailShell extends StatelessWidget {
  const _EventDetailShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: CapBackButton(
                fallbackPath: AppPaths.exploreEvents,
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
