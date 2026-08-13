import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
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
    return async.when(
      loading: () => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go(AppPaths.exploreEvents),
          ),
        ),
        body: Center(
          child: Text(
            'Could not load event',
            style: GoogleFonts.spaceGrotesk(color: Colors.white70),
          ),
        ),
      ),
      data: (event) {
        if (event == null) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.go(AppPaths.exploreEvents),
              ),
            ),
            body: Center(
              child: Text(
                'Event not found',
                style: GoogleFonts.spaceGrotesk(color: Colors.white70),
              ),
            ),
          );
        }
        return EventDetailScreen(event: event);
      },
    );
  }
}
