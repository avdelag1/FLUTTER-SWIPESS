import 'package:share_plus/share_plus.dart';

abstract final class AppShare {
  static const origin = 'https://www.swipess.com';

  static const _origin = origin;
  // Bump this when the server-side rich preview/open-link behavior changes.
  // Social apps aggressively cache Open Graph metadata by URL, so a tiny
  // version query forces WhatsApp/Instagram/etc. to request the current data.
  static const _previewVersion = '3';

  // All shareable Swipess objects use the /s/* handoff URLs. On an installed
  // native app, Universal/App Links open the matching object in Swipess. On
  // the web, Vercel sends /s/* through the preview function: crawlers receive
  // Open Graph metadata while real people are redirected to the real route.
  static String listingUrl(String id) =>
      '$_origin/s/listing/$id?pv=$_previewVersion';
  static String profileUrl(String id) =>
      '$_origin/s/profile/$id?pv=$_previewVersion';
  static String eventUrl(String id) =>
      '$_origin/s/event/$id?pv=$_previewVersion';

  static Future<void> text(String text, {String? subject}) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  }

  static Future<void> listing({required String id, String? title}) {
    final name = (title ?? 'this listing').trim();
    return text(
      'Check out $name on Swipess\n${listingUrl(id)}',
      subject: 'Swipess listing',
    );
  }

  static Future<void> profile({required String id, String? name}) {
    final label = (name ?? 'this Swipess member').trim();
    return text(
      'Connect with $label on Swipess\n${profileUrl(id)}',
      subject: 'Swipess profile',
    );
  }

  static Future<void> event({required String id, String? title}) {
    final label = (title ?? 'this event').trim();
    return text(
      'Check out $label on Swipess\n${eventUrl(id)}',
      subject: 'Swipess event',
    );
  }
}
