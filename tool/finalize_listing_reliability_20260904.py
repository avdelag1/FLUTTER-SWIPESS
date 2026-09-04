from pathlib import Path

p = Path('lib/src/features/swipes/data/repositories/listing_repository.dart')
s = p.read_text()
old = """            if (moderateImage != null) {
              try {
                await moderateImage(url);
              } catch (_) {
                try {
                  await _client.storage.from('listing-images').remove([path]);
                } catch (_) {}
                rethrow;
              }
            }
            urls[i] = url;
"""
new = """            if (moderateImage != null) {
              try {
                await moderateImage(url);
              } catch (_) {
                // The moderation client already fails open on infrastructure
                // errors. A thrown verdict applies only to this photo, so
                // remove it without cancelling the other approved photos.
                try {
                  await _client.storage.from('listing-images').remove([path]);
                } catch (_) {}
                return;
              }
            }
            urls[i] = url;
"""
if old not in s:
    raise SystemExit('moderation anchor not found')
s = s.replace(old, new, 1)
old = """    return urls.whereType<String>().toList(growable: false);
"""
new = """    final approved = urls.whereType<String>().toList(growable: false);
    if (approved.isEmpty) {
      throw Exception(
        'None of the selected photos could be accepted. Choose a different photo and try again.',
      );
    }
    return approved;
"""
if old not in s:
    raise SystemExit('photo return anchor not found')
p.write_text(s)

for helper in [
    '.github/workflows/apply-listing-auth-speed-20260904.yml',
    '.github/workflows/apply-listing-auth-speed-20260904-v2.yml',
    '.github/workflows/apply-listing-auth-speed-20260904-v3.yml',
    '.github/workflows/finalize-listing-reliability-20260904.yml',
    '.github/workflows/finalize-listing-reliability-20260904-v2.yml',
    'tool/fix_listing_auth_speed_20260904.py',
    'tool/finalize_listing_reliability_20260904.py',
]:
    Path(helper).unlink(missing_ok=True)

print('final listing reliability patch applied')
