import re
import os

files = [
    'lib/src/core/widgets/fun_avatar.dart',
    'lib/src/features/insights/presentation/screens/local_intel_screen.dart',
    'lib/src/features/swipes/presentation/screens/listing_detail_screen.dart',
    'lib/src/features/swipes/presentation/widgets/cap_swipe_card.dart',
    'lib/src/features/swipes/presentation/widgets/match_celebrate_modal.dart',
    'lib/src/features/swipes/presentation/widgets/swipeable_card_stack.dart',
    'lib/src/features/swipes/presentation/widgets/listing_share_sheet.dart',
    'lib/src/features/likes/presentation/widgets/owner_client_swipe_dialog.dart',
    'lib/src/features/likes/presentation/widgets/premium_liked_card.dart',
    'lib/src/features/auth/presentation/screens/legendary_onboarding_screen.dart',
    'lib/src/features/admin/presentation/screens/admin_eventos_screen.dart',
    'lib/src/features/admin/presentation/screens/admin_photos_screen.dart',
    'lib/src/features/admin/presentation/screens/admin_category_photos_screen.dart',
    'lib/src/features/dashboard/presentation/widgets/quick_filter_media.dart',
    'lib/src/features/map/presentation/screens/web_discovery_map_screen_v4.dart',
    'lib/src/features/map/presentation/screens/real_mapbox_globe_screen_v2.dart',
    'lib/src/features/add/presentation/screens/edit_listing_screen.dart',
    'lib/src/features/profile/presentation/screens/owner_properties_screen.dart',
    'lib/src/features/profile/presentation/screens/profile_detail_screen.dart',
    'lib/src/features/profile/presentation/widgets/themed_vap_card.dart',
    'lib/src/features/profile/presentation/widgets/holographic_id_card.dart',
    'lib/src/features/profile/presentation/widgets/vap_id_photo_picker.dart',
    'lib/src/features/ai/presentation/widgets/intel_result_cards.dart',
    'lib/src/features/preview/presentation/screens/public_listing_preview_screen.dart',
    'lib/src/features/preview/presentation/screens/public_profile_preview_screen.dart',
    'lib/src/features/seekers/presentation/screens/worker_discovery_screen.dart',
    'lib/src/features/documents/presentation/widgets/document_preview_dialog.dart',
    'lib/src/features/video_tours/presentation/screens/video_tours_screen.dart',
    'lib/src/features/events/presentation/screens/events_screen.dart',
    'lib/src/features/events/presentation/screens/event_favorites_screen.dart',
    'lib/src/features/events/presentation/screens/event_detail_screen.dart'
]

def process():
    for fpath in files:
        if not os.path.exists(fpath): continue
        with open(fpath, 'r') as f:
            content = f.read()

        if 'Image.network' not in content:
            continue

        # Add import if missing
        if 'package:cached_network_image/cached_network_image.dart' not in content:
            import_match = list(re.finditer(r'^import\s+.*;$', content, re.MULTILINE))
            if import_match:
                last_import = import_match[-1]
                pos = last_import.end()
                content = content[:pos] + "\nimport 'package:cached_network_image/cached_network_image.dart';" + content[pos:]
            else:
                content = "import 'package:cached_network_image/cached_network_image.dart';\n" + content
        
        # Replace Image.network( URL, ...) with CachedNetworkImage( imageUrl: URL, ...)
        # Handle newlines and formatting
        # We replace: Image.network(
        # With: CachedNetworkImage(imageUrl: 
        # But we need to capture the first positional argument up to the comma or closing parenthesis.
        # This can be tricky if the argument contains commas (like in function calls).
        # Alternatively, we can use a simpler replacement: 
        # replace `Image.network` with `CachedNetworkImage` and fix the `imageUrl:` manually if it breaks.
        # Actually, let's just do it cleanly with a regex if we assume the first arg is simple.
        
        # We can find all indices of "Image.network("
        out_content = ""
        idx = 0
        while True:
            pos = content.find("Image.network(", idx)
            if pos == -1:
                out_content += content[idx:]
                break
            
            out_content += content[idx:pos]
            
            # Find the end of the argument (first comma at the same parenthesis level, or the closing parenthesis)
            start_arg = pos + len("Image.network(")
            paren_count = 0
            arg_end = start_arg
            found_comma = False
            for i in range(start_arg, len(content)):
                c = content[i]
                if c == '(':
                    paren_count += 1
                elif c == ')':
                    if paren_count == 0:
                        arg_end = i
                        break
                    paren_count -= 1
                elif c == ',':
                    if paren_count == 0:
                        arg_end = i
                        found_comma = True
                        break
            
            arg_text = content[start_arg:arg_end]
            
            # Replace!
            out_content += f"CachedNetworkImage(\n  imageUrl: {arg_text.strip()}"
            if found_comma:
                out_content += ","
            
            idx = arg_end + (1 if found_comma else 0)

        with open(fpath, 'w') as f:
            f.write(out_content)

process()
