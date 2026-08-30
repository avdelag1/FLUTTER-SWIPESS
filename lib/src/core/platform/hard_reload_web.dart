import 'dart:html' as html;

Future<void> hardReloadApp() async {
  html.window.location.reload();
}
