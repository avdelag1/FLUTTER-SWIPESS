import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/map/domain/map_presence_status.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/profile.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

typedef MapFriendSelect = void Function(Profile profile);

/// Instagram-style "search for friends" tray for nearby people on the map.
class MapFriendsTray extends StatefulWidget {
  const MapFriendsTray({
    super.key,
    required this.profiles,
    required this.onSelect,
    this.onShareBack,
  });

  final List<Profile> profiles;
  final MapFriendSelect onSelect;
  final VoidCallback? onShareBack;

  static Future<void> show(
    BuildContext context, {
    required List<Profile> profiles,
    required MapFriendSelect onSelect,
    VoidCallback? onShareBack,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111318),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.62,
        minChildSize: 0.38,
        maxChildSize: 0.92,
        builder: (context, controller) => MapFriendsTray(
          profiles: profiles,
          onSelect: onSelect,
          onShareBack: onShareBack,
        ),
      ),
    );
  }

  @override
  State<MapFriendsTray> createState() => _MapFriendsTrayState();
}

class _MapFriendsTrayState extends State<MapFriendsTray> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = widget.profiles.where((profile) {
      if (q.isEmpty) return true;
      return profile.displayName.toLowerCase().contains(q) ||
          (profile.city ?? '').toLowerCase().contains(q) ||
          (profile.role ?? '').toLowerCase().contains(q);
    }).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Text(
            'Nearby on the map',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: (value) => setState(() => _query = value),
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search for friends…',
              hintStyle: GoogleFonts.plusJakartaSans(
                color: Colors.white38,
                fontSize: 13,
              ),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF1C2230),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      q.isEmpty
                          ? 'No people nearby right now'
                          : 'No matches for "$_query"',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final profile = filtered[index];
                      return _FriendRow(
                        profile: profile,
                        onTap: () {
                          AppHaptics.selection();
                          Navigator.of(context).pop();
                          widget.onSelect(profile);
                        },
                        onShareBack: widget.onShareBack,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.profile,
    required this.onTap,
    this.onShareBack,
  });

  final Profile profile;
  final VoidCallback onTap;
  final VoidCallback? onShareBack;

  @override
  Widget build(BuildContext context) {
    final status = MapPresenceStatus.resolve(profile.mapStatus);
    final avatar = profile.avatarUrl?.trim();
    final when = profile.createdAt;

    return Material(
      color: const Color(0xFF171A21),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF2A2D35),
                backgroundImage:
                    avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
                child: avatar == null || avatar.isEmpty
                    ? const Icon(Icons.person_rounded, color: Colors.white54)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (status != null) status.label,
                        profile.city ?? 'Nearby',
                        if (when != null) _timeAgo(when),
                      ].where((e) => e.isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (onShareBack != null)
                TextButton(
                  onPressed: () {
                    AppHaptics.light();
                    onShareBack!();
                  },
                  child: Text(
                    'Share back',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return DateFormat('MMM d').format(time);
  }
}
