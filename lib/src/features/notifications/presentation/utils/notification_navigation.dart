import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/widgets/chat_popup.dart';
import 'package:flutter_swipes/src/features/notifications/domain/app_notification.dart';
import 'package:flutter_swipes/src/features/payments/presentation/screens/direct_request_review_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/profile_detail_screen.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/listing_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens notification targets without assuming that priority requests are chats.
Future<void> openNotificationTarget(
  BuildContext context,
  AppNotification notification,
) async {
  final link = notification.linkUrl?.trim();
  final related = notification.relatedUserId;

  if (link != null && link.isNotEmpty) {
    final uri = Uri.tryParse(link);
    if (uri != null) {
      final path = uri.path;
      final directRequestMatch =
          RegExp(r'/direct-request/([^/]+)').firstMatch(path);
      if (directRequestMatch != null) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DirectRequestReviewScreen(
              requestId: directRequestMatch.group(1)!,
              senderName: notification.title,
            ),
          ),
        );
        return;
      }
      final listingMatch = RegExp(r'/listing/([^/]+)').firstMatch(path);
      if (listingMatch != null) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                ListingDetailScreen(listingId: listingMatch.group(1)),
          ),
        );
        return;
      }
      final profileMatch = RegExp(r'/profile/([^/]+)').firstMatch(path);
      if (profileMatch != null) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProfileDetailScreen(userId: profileMatch.group(1)!),
          ),
        );
        return;
      }
      final messagesMatch = RegExp(r'/messages/([^/]+)').firstMatch(path);
      if (messagesMatch != null && related != null) {
        await showChatPopup(
          context,
          conversation: ChatConversation(
            id: messagesMatch.group(1)!,
            otherUserId: related,
            name: notification.title,
            lastMessage: notification.message,
            timestamp: 'now',
          ),
        );
        return;
      }
      if (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
  }

  switch (notification.visualType) {
    case 'message':
      if (related != null) {
        await showChatPopup(
          context,
          conversation: ChatConversation(
            id: 'pending-$related',
            otherUserId: related,
            name: notification.title,
            lastMessage: notification.message,
            timestamp: 'now',
          ),
        );
      }
      return;
    case 'like':
    case 'match':
      if (related != null) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProfileDetailScreen(userId: related),
          ),
        );
      }
      return;
    default:
      return;
  }
}
