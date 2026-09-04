from pathlib import Path


def find_matching_paren(text: str, open_idx: int) -> int:
    depth = 0
    i = open_idx
    quote = None
    triple = False
    while i < len(text):
        ch = text[i]
        nxt3 = text[i:i+3]
        if quote is not None:
            if triple:
                if nxt3 == quote * 3:
                    i += 3
                    quote = None
                    triple = False
                    continue
                i += 1
                continue
            if ch == '\\':
                i += 2
                continue
            if ch == quote:
                quote = None
            i += 1
            continue
        if nxt3 in ("'''", '"""'):
            quote = nxt3[0]
            triple = True
            i += 3
            continue
        if ch in ("'", '"'):
            quote = ch
            i += 1
            continue
        if text.startswith('//', i):
            nl = text.find('\n', i)
            if nl == -1:
                return -1
            i = nl + 1
            continue
        if text.startswith('/*', i):
            end = text.find('*/', i + 2)
            if end == -1:
                return -1
            i = end + 2
            continue
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


bento = Path('lib/src/features/dashboard/presentation/screens/bento_dashboard_screen.dart')
text = bento.read_text()
class_idx = text.index('class _BentoCardState extends State<_BentoCard>')
ret_idx = text.index('return AnimatedScale(', class_idx)
call_idx = text.index('AnimatedScale(', ret_idx)
open_idx = text.index('(', call_idx)
call_end = find_matching_paren(text, open_idx)
if call_end < 0:
    raise SystemExit('Could not locate AnimatedScale closing parenthesis')
segment = text[call_idx:call_end + 1]
child_idx = segment.find('child: Container(')
if child_idx < 0:
    raise SystemExit('Could not locate Bento Container child')
container_idx = segment.find('Container(', child_idx)
container_open = segment.find('(', container_idx)
container_end = find_matching_paren(segment, container_open)
if container_end < 0:
    raise SystemExit('Could not locate Bento Container closing parenthesis')
container_expr = segment[container_idx:container_end + 1]
text = text[:call_idx] + container_expr + text[call_end + 1:]
bento.write_text(text)

prop = Path('lib/src/features/dashboard/presentation/widgets/property_teaser_card.dart')
text = prop.read_text()
old = '''      children: [
        video
            ? poster != null
                  ? _still(poster)
                  : const ColoredBox(color: Color(0xFF15171C))
            : _still(url),
        if (ready && _manualPlaying) _CoverVideo(controller: player),
'''
new = '''      children: [
        if (video && ready && _manualPlaying)
          _CoverVideo(controller: player)
        else if (video)
          poster != null
              ? _still(poster)
              : const ColoredBox(color: Color(0xFF15171C))
        else
          _still(url),
'''
if old not in text:
    raise SystemExit('Could not locate Properties poster/video stack')
text = text.replace(old, new, 1)
prop.write_text(text)
print('Property dashboard compositor patch applied.')
