import 'dart:io';

void main() {
  var file = File('lib/src/features/map/presentation/screens/web_discovery_map_screen_v8.dart');
  var content = file.readAsStringSync();

  // 1. Change Positioned(left: 12, right: 12) to Positioned(left: 0, right: 0)
  var positionedStr = '''
            Positioned(
              top: pad.top + 8,
              left: 12,
              right: 12,
              child: _Header(''';
  var newPositionedStr = '''
            Positioned(
              top: pad.top + 8,
              left: 0,
              right: 0,
              child: _Header(''';
  content = content.replaceAll(positionedStr, newPositionedStr);

  // 2. Add Padding to the Row in _Header
  var headerRowStr = '''
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Row(''';
  var newHeaderRowStr = '''
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(''';
  content = content.replaceAll(headerRowStr, newHeaderRowStr);
  
  // Close the Padding around the Row
  var rowEndStr = '''
                _HeaderCircle(
                  label: 'Search map',
                  icon: searchOpen ? Icons.close_rounded : Icons.search_rounded,
                  onTap: onSearchToggle,
                ),
              ],
            ),
          ),
        ),''';
  var newRowEndStr = '''
                _HeaderCircle(
                  label: 'Search map',
                  icon: searchOpen ? Icons.close_rounded : Icons.search_rounded,
                  onTap: onSearchToggle,
                ),
              ],
            ),
            ),
          ),
        ),''';
  content = content.replaceAll(rowEndStr, newRowEndStr);

  // 3. Add Padding to Search bar
  var searchBarStr = '''
        if (searchOpen) ...[
          const SizedBox(height: 7),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(''';
  var newSearchBarStr = '''
        if (searchOpen) ...[
          const SizedBox(height: 7),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(''';
  content = content.replaceAll(searchBarStr, newSearchBarStr);

  // Close Padding around search bar
  var searchBarEndStr = '''
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
          ),
        ],''';
  var newSearchBarEndStr = '''
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              ),
            ),
          ),
        ],''';
  content = content.replaceAll(searchBarEndStr, newSearchBarEndStr);

  // 4. Update the ListView for filters
  var listViewStr = '''
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {''';
  var newListViewStr = '''
        SizedBox(
          height: 34,
          child: ShaderMask(
            shaderCallback: (Rect bounds) {
              return const LinearGradient(
                colors: [
                  Color(0x00000000),
                  Color(0xFFFFFFFF),
                  Color(0xFFFFFFFF),
                  Color(0x00000000),
                ],
                stops: [0.0, 0.06, 0.94, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {''';
  content = content.replaceAll(listViewStr, newListViewStr);
  
  // Close ShaderMask
  var listViewEndStr = '''
                  ),
                ),
              );
            },
          ),
        ),''';
  var newListViewEndStr = '''
                  ),
                ),
              );
            },
            ),
          ),
        ),''';
  content = content.replaceAll(listViewEndStr, newListViewEndStr);

  // Now, fix the circle layer radius so it's more visible.
  // Original: color: Colors.transparent, borderColor: const Color(0x30147DFF), borderStrokeWidth: 1,
  var circleStr = '''
                      color: Colors.transparent,
                      borderColor: const Color(0x30147DFF),
                      borderStrokeWidth: 1,
                    ),''';
  var newCircleStr = '''
                      color: const Color(0x10147DFF),
                      borderColor: const Color(0x40147DFF),
                      borderStrokeWidth: 1.5,
                    ),''';
  content = content.replaceAll(circleStr, newCircleStr);

  file.writeAsStringSync(content);
}
