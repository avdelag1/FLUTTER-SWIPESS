import 'dart:html' as html;

int _holders = 0;
html.EventListener? _listener;

void acquireContextMenuBlock() {
  _holders++;
  if (_holders > 1) return;
  _listener = (html.Event event) {
    event.preventDefault();
  };
  html.document.addEventListener('contextmenu', _listener);
}

void releaseContextMenuBlock() {
  if (_holders == 0) return;
  _holders--;
  if (_holders > 0) return;
  final listener = _listener;
  if (listener != null) {
    html.document.removeEventListener('contextmenu', listener);
  }
  _listener = null;
}
