import 'dart:io';

void main() {
  var file = File('lib/src/features/events/presentation/screens/events_screen.dart');
  var content = file.readAsStringSync();

  var oldVideo = '''
          if (ready)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: player.value.size.width,
                height: player.value.size.height,
                child: VideoPlayer(player),
              ),
            )''';
  var newVideo = '''
          if (ready)
            AnimatedScale(
              scale: widget.chromeVisible ? 1.0 : 1.06,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: player.value.size.width,
                  height: player.value.size.height,
                  child: VideoPlayer(player),
                ),
              ),
            )''';
            
  if (content.contains(oldVideo)) {
    content = content.replaceAll(oldVideo, newVideo);
  } else {
    print("Could not replace video scale.");
  }
  
  var oldImage = '''
          else if (image.isNotEmpty)
            Image.network(
              image,
              fit: BoxFit.cover,
              cacheWidth: (MediaQuery.sizeOf(context).width * 2)
                  .round()
                  .clamp(640, 1800),
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: Color(0xFF16161C)),
            )''';
  var newImage = '''
          else if (image.isNotEmpty)
            AnimatedScale(
              scale: widget.chromeVisible ? 1.0 : 1.06,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              child: Image.network(
                image,
                fit: BoxFit.cover,
                cacheWidth: (MediaQuery.sizeOf(context).width * 2)
                    .round()
                    .clamp(640, 1800),
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: Color(0xFF16161C)),
              ),
            )''';
            
  if (content.contains(oldImage)) {
    content = content.replaceAll(oldImage, newImage);
  }
  
  file.writeAsStringSync(content);
}
