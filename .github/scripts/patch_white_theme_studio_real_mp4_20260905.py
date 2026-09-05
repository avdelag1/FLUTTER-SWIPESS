from pathlib import Path


def read(path: str) -> str:
    return Path(path).read_text()


def write(path: str, value: str) -> None:
    Path(path).write_text(value)


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 match, got {count}')
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# AI LISTING BUILDER — make the whole form obey light/dark theme. Media/video
# canvases remain black intentionally, but page/form surfaces and typed text are
# black on white in light mode.
# ---------------------------------------------------------------------------
p = 'lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart'
s = read(p)

anchor = """  static const _blue = Color(0xFF4DA3FF);\n\n  final _city = TextEditingController();"""
insert = """  static const _blue = Color(0xFF4DA3FF);\n\n  bool get _isLight => Theme.of(context).brightness == Brightness.light;\n  Color get _ink => _isLight ? const Color(0xFF0A0A0D) : Colors.white;\n  Color get _muted =>\n      _isLight ? const Color(0xFF666670) : const Color(0xFF9B9BA5);\n  Color get _faint =>\n      _isLight ? const Color(0xFF81818B) : const Color(0xFF777780);\n  Color get _panelColor => _isLight ? Colors.white : _panel;\n  Color get _panelRaisedColor =>\n      _isLight ? const Color(0xFFF3F3F6) : _panelRaised;\n  Color get _hairline => _isLight\n      ? Colors.black.withValues(alpha: .10)\n      : Colors.white.withValues(alpha: .08);\n  List<Color> get _lightAwareGradient => _isLight\n      ? const [Color(0xFFFFFFFF), Color(0xFFF4F4F7)]\n      : const [Color(0xFF25252B), Color(0xFF1A1A1F)];\n\n  final _city = TextEditingController();"""
s = replace_once(s, anchor, insert, 'ai theme getters')

s = replace_once(
    s,
    """    return Scaffold(\n      backgroundColor: Colors.black,""",
    """    return Scaffold(\n      backgroundColor: Theme.of(context).scaffoldBackgroundColor,""",
    'ai scaffold',
)
s = replace_once(s, "color: Colors.white,\n                      fontSize: 25,", "color: _ink,\n                      fontSize: 25,", 'ai title ink')
s = replace_once(s, "color: const Color(0xFF9B9BA5),\n                      fontSize: 11.5,", "color: _muted,\n                      fontSize: 11.5,", 'ai subtitle')

old_desc = """                  Container(\n                    decoration: BoxDecoration(\n                      gradient: const LinearGradient(\n                        begin: Alignment.topLeft,\n                        end: Alignment.bottomRight,\n                        colors: [Color(0xFF232329), Color(0xFF17171C)],\n                      ),\n                      borderRadius: BorderRadius.circular(22),\n                      boxShadow: [\n                        BoxShadow(\n                          color: Colors.black.withValues(alpha: .38),\n                          blurRadius: 22,\n                          offset: const Offset(0, 10),\n                        ),\n                      ],\n                    ),"""
new_desc = """                  Container(\n                    decoration: BoxDecoration(\n                      gradient: LinearGradient(\n                        begin: Alignment.topLeft,\n                        end: Alignment.bottomRight,\n                        colors: _isLight\n                            ? const [Color(0xFFFFFFFF), Color(0xFFF4F4F7)]\n                            : const [Color(0xFF232329), Color(0xFF17171C)],\n                      ),\n                      borderRadius: BorderRadius.circular(22),\n                      border: Border.all(color: _hairline),\n                      boxShadow: [\n                        BoxShadow(\n                          color: Colors.black.withValues(alpha: _isLight ? .08 : .38),\n                          blurRadius: 22,\n                          offset: const Offset(0, 10),\n                        ),\n                      ],\n                    ),"""
s = replace_once(s, old_desc, new_desc, 'ai description surface')
s = replace_once(s, "color: const Color(0xFF777780),\n                              fontSize: 13,", "color: _faint,\n                              fontSize: 13,", 'ai description hint')
s = replace_once(s, "foregroundColor: Colors.white,\n                              ),", "foregroundColor: _ink,\n                              ),", 'ai enhance foreground')
s = replace_once(s, "color: const Color(0xFFD0D0D6),\n                              fontSize: 10.5,", "color: _muted,\n                              fontSize: 10.5,", 'ai mic helper')
s = replace_once(s, "dropdownColor: _panel,\n                                iconEnabledColor: Colors.white,", "dropdownColor: _panelColor,\n                                iconEnabledColor: _ink,", 'ai currency dropdown')

old_status = """                      decoration: BoxDecoration(\n                        color: const Color(0xFF17171D),\n                        borderRadius: BorderRadius.circular(16),\n                        boxShadow: [\n                          BoxShadow(\n                            color: Colors.black.withValues(alpha: .26),"""
new_status = """                      decoration: BoxDecoration(\n                        color: _panelColor,\n                        borderRadius: BorderRadius.circular(16),\n                        border: Border.all(color: _hairline),\n                        boxShadow: [\n                          BoxShadow(\n                            color: Colors.black.withValues(alpha: _isLight ? .07 : .26),"""
s = replace_once(s, old_status, new_status, 'ai status surface')
s = replace_once(s, "color: Colors.white,\n                                fontSize: 11.5,", "color: _ink,\n                                fontSize: 11.5,", 'ai status text')

# Theme the helpers used by every editable AI field.
old_input_shell = """  Widget _inputShell({required Widget child}) => Container(\n    decoration: BoxDecoration(\n      gradient: const LinearGradient(\n        begin: Alignment.topLeft,\n        end: Alignment.bottomRight,\n        colors: [Color(0xFF25252B), Color(0xFF1A1A1F)],\n      ),\n      borderRadius: BorderRadius.circular(19),\n      boxShadow: [\n        BoxShadow(\n          color: Colors.black.withValues(alpha: .34),\n          blurRadius: 18,\n          offset: const Offset(0, 8),\n        ),\n      ],\n    ),\n    child: child,\n  );"""
new_input_shell = """  Widget _inputShell({required Widget child}) => Container(\n    decoration: BoxDecoration(\n      gradient: LinearGradient(\n        begin: Alignment.topLeft,\n        end: Alignment.bottomRight,\n        colors: _lightAwareGradient,\n      ),\n      borderRadius: BorderRadius.circular(19),\n      border: Border.all(color: _hairline),\n      boxShadow: [\n        BoxShadow(\n          color: Colors.black.withValues(alpha: _isLight ? .07 : .34),\n          blurRadius: 18,\n          offset: const Offset(0, 8),\n        ),\n      ],\n    ),\n    child: child,\n  );"""
s = replace_once(s, old_input_shell, new_input_shell, 'ai input shell')

old_input_dec = """  }) => InputDecoration(\n    hintText: hint,\n    hintStyle: GoogleFonts.plusJakartaSans(\n      color: const Color(0xFF777780),\n      fontSize: 13,\n    ),\n    prefixIcon: Icon(icon, color: const Color(0xFFB9B9C2), size: 20),\n    border: InputBorder.none,\n    contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),\n  );\n\n  TextStyle get _fieldTextStyle => GoogleFonts.plusJakartaSans(\n    color: Colors.white,\n    fontSize: 14,\n    fontWeight: FontWeight.w600,\n  );"""
new_input_dec = """  }) => InputDecoration(\n    hintText: hint,\n    hintStyle: GoogleFonts.plusJakartaSans(\n      color: _faint,\n      fontSize: 13,\n    ),\n    prefixIcon: Icon(icon, color: _muted, size: 20),\n    border: InputBorder.none,\n    contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),\n  );\n\n  TextStyle get _fieldTextStyle => GoogleFonts.plusJakartaSans(\n    color: _ink,\n    fontSize: 14,\n    fontWeight: FontWeight.w600,\n  );"""
s = replace_once(s, old_input_dec, new_input_dec, 'ai input text')

# Section titles + category controls.
s = replace_once(s, "color: const Color(0xFF9B9BA5),\n      fontSize: 10,", "color: _muted,\n      fontSize: 10,", 'ai section title')
s = replace_once(s, "color: selected ? Colors.white : const Color(0xFFB9B9C2),", "color: selected ? Colors.white : _muted,", 'ai category icon')
s = replace_once(s, "color: selected ? Colors.white : const Color(0xFFD0D0D6),", "color: selected ? Colors.white : _ink,", 'ai category text')
s = replace_once(s, "backgroundColor: _panelRaised,", "backgroundColor: _panelRaisedColor,", 'ai category bg')

# Photo panel / non-video action cards become white/light gray in light mode.
s = s.replace("color: _panel,\n        borderRadius: BorderRadius.circular(18),\n        border: Border.all(color: Colors.white.withValues(alpha: .07)),", "color: _panelColor,\n        borderRadius: BorderRadius.circular(18),\n        border: Border.all(color: _hairline),")
s = s.replace("gradient: const LinearGradient(\n            begin: Alignment.topLeft,\n            end: Alignment.bottomRight,\n            colors: [Color(0xFF222228), Color(0xFF17171C)],\n          ),", "gradient: LinearGradient(\n            begin: Alignment.topLeft,\n            end: Alignment.bottomRight,\n            colors: _isLight\n                ? const [Color(0xFFFFFFFF), Color(0xFFF3F3F6)]\n                : const [Color(0xFF222228), Color(0xFF17171C)],\n          ),")
s = s.replace("border: Border.all(color: Colors.white.withValues(alpha: .07)),", "border: Border.all(color: _hairline),")

# Text on light action cards. Keep white where it sits on pink/black video overlays.
s = replace_once(s, """              style: GoogleFonts.plusJakartaSans(\n                color: Colors.white,\n                fontSize: 10.5,\n                fontWeight: FontWeight.w900,""", """              style: GoogleFonts.plusJakartaSans(\n                color: _ink,\n                fontSize: 10.5,\n                fontWeight: FontWeight.w900,""", 'ai media action label')
s = replace_once(s, """              style: GoogleFonts.plusJakartaSans(\n                color: Colors.white,\n                fontSize: 11,\n                fontWeight: FontWeight.w900,""", """              style: GoogleFonts.plusJakartaSans(\n                color: _ink,\n                fontSize: 11,\n                fontWeight: FontWeight.w900,""", 'ai add photos label')

# Verification panel follows the page theme.
s = replace_once(s, "color: const Color(0xFF17171C),\n        borderRadius: BorderRadius.circular(22),", "color: _panelColor,\n        borderRadius: BorderRadius.circular(22),", 'ai verification bg')
s = replace_once(s, "color: Colors.white,\n                        fontSize: 12.5,", "color: _ink,\n                        fontSize: 12.5,", 'ai verification title')
s = s.replace("backgroundColor: Colors.white.withValues(alpha: .07),\n                      foregroundColor: Colors.white,", "backgroundColor: _isLight ? const Color(0xFFF1F1F4) : Colors.white.withValues(alpha: .07),\n                      foregroundColor: _ink,")
s = s.replace("color: const Color(0xFFD7D7DE),\n                          fontSize: 10,", "color: _ink,\n                          fontSize: 10,")

# Info sheet is also a real app surface, not a forced dark modal.
s = replace_once(s, "color: const Color(0xFF17171C),\n          borderRadius: BorderRadius.circular(26),", "color: _panelColor,\n          borderRadius: BorderRadius.circular(26),", 'ai info sheet bg')
s = replace_once(s, "color: Colors.white,\n                      fontSize: 16,", "color: _ink,\n                      fontSize: 16,", 'ai info title')
s = replace_once(s, "color: const Color(0xFFC7C7CF),\n                fontSize: 12,", "color: _muted,\n                fontSize: 12,", 'ai info body')

# Header is a separate widget; read the theme directly from its BuildContext.
old_header = """  @override\n  Widget build(BuildContext context) {\n    return Padding(\n      padding: EdgeInsets.fromLTRB(10, 6, 14, 6),"""
new_header = """  @override\n  Widget build(BuildContext context) {\n    final ink = Theme.of(context).colorScheme.onSurface;\n    return Padding(\n      padding: EdgeInsets.fromLTRB(10, 6, 14, 6),"""
s = replace_once(s, old_header, new_header, 'ai header theme')
s = replace_once(s, "color: Colors.white,\n          ),\n          const Spacer(),", "color: ink,\n          ),\n          const Spacer(),", 'ai header back')
s = replace_once(s, "color: Colors.white,\n              fontSize: 12,", "color: ink,\n              fontSize: 12,", 'ai header title')

write(p, s)


# ---------------------------------------------------------------------------
# STUDIO COMPOSER — page chrome and controls obey white mode. The cinematic
# preview / actual movie player deliberately stay black because they are media.
# ---------------------------------------------------------------------------
p = 'lib/src/features/studio/presentation/screens/studio_composer_screen.dart'
s = read(p)
anchor = """class _StudioComposerScreenState extends State<StudioComposerScreen> {\n  static const _pink = Color(0xFFFF2D6F);"""
insert = """class _StudioComposerScreenState extends State<StudioComposerScreen> {\n  static const _pink = Color(0xFFFF2D6F);\n\n  bool get _isLight => Theme.of(context).brightness == Brightness.light;\n  Color get _ink => _isLight ? const Color(0xFF0A0A0D) : Colors.white;\n  Color get _muted =>\n      _isLight ? const Color(0xFF686872) : const Color(0xFF9B9BA5);\n  Color get _panel => _isLight ? Colors.white : const Color(0xFF17171C);\n  Color get _panelRaised =>\n      _isLight ? const Color(0xFFF3F3F6) : const Color(0xFF24242B);\n  Color get _hairline => _isLight\n      ? Colors.black.withValues(alpha: .10)\n      : Colors.white.withValues(alpha: .08);"""
s = replace_once(s, anchor, insert, 'studio theme getters')
s = replace_once(s, "backgroundColor: Colors.black,\n      appBar: AppBar(\n        backgroundColor: Colors.black,\n        foregroundColor: Colors.white,", "backgroundColor: Theme.of(context).scaffoldBackgroundColor,\n      appBar: AppBar(\n        backgroundColor: Theme.of(context).scaffoldBackgroundColor,\n        foregroundColor: _ink,", 'studio scaffold')
s = replace_once(s, "color: Colors.white,\n                fontSize: 25,", "color: _ink,\n                fontSize: 25,", 'studio title')
s = replace_once(s, "color: const Color(0xFF9B9BA5),\n                fontSize: 11.5,", "color: _muted,\n                fontSize: 11.5,", 'studio subtitle')
s = replace_once(s, "color: const Color(0xFF777780),\n                fontSize: 9.5,", "color: _muted,\n                fontSize: 9.5,", 'studio helper text')

s = replace_once(s, "color: const Color(0xFF17171C),\n      borderRadius: BorderRadius.circular(20),\n      border: Border.all(color: Colors.white.withValues(alpha: .08)),", "color: _panel,\n      borderRadius: BorderRadius.circular(20),\n      border: Border.all(color: _hairline),", 'studio notice')
s = replace_once(s, "color: Colors.white,\n              fontSize: 11,", "color: _ink,\n              fontSize: 11,", 'studio notice text')
s = replace_once(s, "color: const Color(0xFF17171C),\n        borderRadius: BorderRadius.circular(18),\n        border: Border.all(color: Colors.white.withValues(alpha: .07)),", "color: _panel,\n        borderRadius: BorderRadius.circular(18),\n        border: Border.all(color: _hairline),", 'studio focus bg')
s = replace_once(s, "color: Colors.white,\n              fontSize: 10,", "color: _ink,\n              fontSize: 10,", 'studio focus title')

s = replace_once(s, """            color: selected\n                ? _pink.withValues(alpha: .14)\n                : const Color(0xFF17171C),""", """            color: selected\n                ? _pink.withValues(alpha: _isLight ? .10 : .14)\n                : _panel,""", 'studio template bg')
s = replace_once(s, "color: selected ? _pink : Colors.white.withValues(alpha: .07),", "color: selected ? _pink : _hairline,", 'studio template border')
s = replace_once(s, "color: selected ? _pink : const Color(0xFF24242B),", "color: selected ? _pink : _panelRaised,", 'studio template icon bg')
s = replace_once(s, """                child: Icon(\n                  _styleIcon(template),\n                  color: Colors.white,""", """                child: Icon(\n                  _styleIcon(template),\n                  color: selected ? Colors.white : _ink,""", 'studio template icon ink')
s = replace_once(s, "color: Colors.white,\n                        fontSize: 12,", "color: _ink,\n                        fontSize: 12,", 'studio template title')
s = replace_once(s, "color: const Color(0xFF9999A3),\n                        fontSize: 9.5,", "color: _muted,\n                        fontSize: 9.5,", 'studio template description')
s = replace_once(s, "color: const Color(0xFFC9C9D0),\n                          fontSize: 9,", "color: _muted,\n                          fontSize: 9,", 'studio soundtrack label')

s = replace_once(s, "backgroundColor: const Color(0xFF17171C),\n      selectedColor: _pink,", "backgroundColor: _panel,\n      selectedColor: _pink,", 'studio sound bg')
s = replace_once(s, "color: selected ? _pink : Colors.white.withValues(alpha: .08),", "color: selected ? _pink : _hairline,", 'studio sound border')
s = replace_once(s, "color: Colors.white,\n        fontSize: 9.5,", "color: selected ? Colors.white : _ink,\n        fontSize: 9.5,", 'studio sound text')
s = replace_once(s, "color: const Color(0xFF9B9BA5),\n      fontSize: 10,", "color: _muted,\n      fontSize: 10,", 'studio section title')
write(p, s)


# ---------------------------------------------------------------------------
# Verification workflow must cover BOTH renderers. The browser wrapper used to
# change without the MP4 smoke test noticing it.
# ---------------------------------------------------------------------------
p = '.github/workflows/verify-studio-photo-video.yml'
s = read(p)
if "      - 'api/studio-render-client.js'\n" not in s:
    s = s.replace("      - 'api/studio-render.js'\n", "      - 'api/studio-render.js'\n      - 'api/studio-render-client.js'\n", 1)
if 'node --check api/studio-render-client.js' not in s:
    s = s.replace(
        "      - name: Check Studio renderer syntax\n        run: node --check api/studio-render.js\n",
        "      - name: Check Studio renderer syntax\n        run: |\n          node --check api/studio-render.js\n          node --check api/studio-render-client.js\n",
        1,
    )
write(p, s)

print('white-theme + Studio UI patch applied')
