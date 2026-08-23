import 'package:share_plus/share_plus.dart';

abstract final class AppShare {
  static const _origin = 'https://swipess.com';

  static String listingUrl(String id) => '$_origin/s/listing/$id';
  static String profileUrl(String id) => '$_origin/u/$id';
  static String eventUrl(String id) => '$_origin/s/event/$id';

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
