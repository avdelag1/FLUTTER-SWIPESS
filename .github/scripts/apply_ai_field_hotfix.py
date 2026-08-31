from pathlib import Path
import subprocess


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'{label} not found')
    return text.replace(old, new, 1)


dashboard = Path('lib/src/core/widgets/glow_search_bar.dart')
text = dashboard.read_text()

old = """  Future<void> _toggleVoice() async {
    if (!_isEditableSearch) {
      widget.onTap?.call();
      return;
    }
    if (_inlineAiLoading) return;

    if (_micSessionActive || _voiceActive || _voice.isOwnedBy(this)) {
      await _endContinuousSession();
      return;
    }

    _micSessionActive = true;
    await _startLiveListening(animatePop: true);
  }
"""
new = """  Future<void> _toggleVoice() async {
    if (!_isEditableSearch) {
      widget.onTap?.call();
      return;
    }
    if (_inlineAiLoading) return;

    if (_micSessionActive || _voiceActive || _voice.isOwnedBy(this)) {
      await _endContinuousSession();
      return;
    }

    // Every idle mic tap starts a completely new request. Clear the previous
    // question and result before voice recognition starts so new speech can
    // never be appended to the last conversation.
    final controller = widget.controller;
    if (controller != null && controller.text.isNotEmpty) {
      controller.clear();
      widget.onChanged?.call('');
    }
    if (_inlineQuestion != null ||
        _inlineAnswer != null ||
        _inlineLocalBrain.isNotEmpty ||
        _inlineProfiles.isNotEmpty ||
        _inlineListings.isNotEmpty) {
      _dismissInlineAi();
    }
    _liveTranscript = '';
    _pendingVoiceSubmit = null;
    _speechResumedWithoutText = false;
    _speechResumeBaseline = '';

    _micSessionActive = true;
    await _startLiveListening(animatePop: true);
  }
"""
text = replace_once(text, old, new, 'dashboard toggle block')

old = """      var answer = clean.isNotEmpty
          ? clean
          : fallback.isNotEmpty
          ? fallback
          : 'I heard you. Try asking in a different way or tap Continue in chat.';
      if (brain.isNotEmpty && declined) {
        final name = brain.first['name']?.toString().trim();
        answer = name != null && name.isNotEmpty
            ? 'Best match: $name.'
            : 'I found a trusted local contact for you.';
      }
"""
new = """      // Never put the raw provider response on screen as a fallback. Parsed
      // structured transport data must stay internal even if a provider returns
      // malformed tags or base64 payloads.
      var answer = clean.isNotEmpty
          ? clean
          : 'I found results, but the answer needs a cleaner response. Try again.';

      // Curated contact results use deterministic dashboard copy. This prevents
      // the model from replacing a valid Local Brain match with unrelated prose.
      if (brain.isNotEmpty) {
        final name = brain.first['name']?.toString().trim();
        answer = name != null && name.isNotEmpty
            ? 'Best match: $name.'
            : 'I found a trusted local contact for you.';
      } else if (declined && parsed.profiles.isNotEmpty) {
        answer = 'I found matching people for you.';
      }
"""
text = replace_once(text, old, new, 'dashboard answer block')
text = replace_once(
    text,
    "final description = _first(['recommendation_note', 'description']);",
    "final description = _first(['description']);",
    'private dashboard recommendation note',
)
dashboard.write_text(text)

intel = Path('lib/src/features/dashboard/presentation/widgets/intel_core_sheet.dart')
text = intel.read_text()
old = """    if (_voice.isOwnedBy(this) || _recording) {
      _cancelCountdown();
      await _voice.cancel(owner: this);
      if (mounted) {
        setState(() {
          _recording = false;
          _voiceLevel = 0;
        });
      }
      return;
    }

    unawaited(AppHaptics.voiceStart());
"""
new = """    if (_voice.isOwnedBy(this) || _recording) {
      _cancelCountdown();
      await _voice.cancel(owner: this);
      if (mounted) {
        setState(() {
          _recording = false;
          _voiceLevel = 0;
        });
      }
      return;
    }

    // A fresh mic tap is a fresh request, never an append to old input.
    _cancelCountdown();
    _controller.clear();

    unawaited(AppHaptics.voiceStart());
"""
intel.write_text(replace_once(text, old, new, 'Intel Core toggle block'))

edge = Path('supabase/functions/ai-concierge/index.ts')
text = edge.read_text()
text = replace_once(
    text,
    '    recommendation_note: entry.recommendation_note ?? null,\n',
    '',
    'Local Brain private recommendation_note payload',
)
old = """  const intro = aiDeclinedContactMatch(text)
    ? (ctx.compactDashboard
      ? `Best match: ${first?.name || \"this contact\"}.`
      : `I found a trusted local match: ${first?.name || \"this contact\"}.`)
    : text.trim();
"""
new = """  const intro = ctx.compactDashboard
    ? `Best match: ${first?.name || \"this contact\"}.`
    : aiDeclinedContactMatch(text)
      ? `I found a trusted local match: ${first?.name || \"this contact\"}.`
      : text.trim();
"""
edge.write_text(replace_once(text, old, new, 'Local Brain deterministic intro'))

# Restore the normal CI workflow from the commit immediately before the
# temporary hotfix workflow, then remove this one-time script.
original_workflow = subprocess.check_output(
    ['git', 'show', 'HEAD^:.github/workflows/flutter_checks.yml'], text=True
)
Path('.github/workflows/flutter_checks.yml').write_text(original_workflow)
Path('.github/scripts/apply_ai_field_hotfix.py').unlink()
