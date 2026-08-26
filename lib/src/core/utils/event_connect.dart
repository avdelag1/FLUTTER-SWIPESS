import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:url_launcher/url_launcher.dart';

/// Builds public contact URLs for event hosts (WhatsApp first).
abstract final class EventConnect {
  static String digits(String? raw) =>
      (raw ?? '').replaceAll(RegExp(r'\D'), '');

  static bool hasWhatsApp(String? phone) => digits(phone).length >= 8;

  /// `https://wa.me/<digits>?text=…` from a promoter phone number.
  static Uri? whatsAppUri(String? phone, {String? message}) {
    final d = digits(phone);
    if (d.length < 8) return null;
    if (message == null || message.trim().isEmpty) {
      return Uri.parse('https://wa.me/$d');
    }
    return Uri.parse('https://wa.me/$d?text=${Uri.encodeComponent(message)}');
  }

  static Uri? instagramUri(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return null;
    if (v.startsWith('http://') || v.startsWith('https://')) {
      return Uri.tryParse(v);
    }
    var handle = v.replaceAll('@', '').trim();
    handle = handle.replaceFirst(
      RegExp(r'^(www\.)?instagram\.com/', caseSensitive: false),
      '',
    );
    handle = handle.split('/').first.split('?').first;
    if (handle.isEmpty) return null;
    return Uri.parse('https://www.instagram.com/$handle/');
  }

  static Uri? websiteUri(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return null;
    if (v.startsWith('http://') || v.startsWith('https://')) {
      return Uri.tryParse(v);
    }
    return Uri.tryParse('https://$v');
  }

  static Uri? facebookUri(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return null;
    if (v.startsWith('http://') || v.startsWith('https://')) {
      return Uri.tryParse(v);
    }
    var handle = v.replaceAll('@', '').trim();
    handle = handle.replaceFirst(
      RegExp(r'^(www\.)?facebook\.com/', caseSensitive: false),
      '',
    );
    handle = handle.split('?').first;
    if (handle.isEmpty) return null;
    return Uri.parse('https://www.facebook.com/$handle');
  }

  static Future<void> open(Uri? uri) async {
    if (uri == null) return;
    AppHaptics.medium();
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
