  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter &&
            !HardwareKeyboard.instance.isShiftPressed) {
          _submit();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
    );
    _loadPrivacy();
    _loadSaved();
    final seed = widget.initialQuery.trim();
    if (seed.isNotEmpty) _privacyAccepted = true;
    if (seed.isNotEmpty) {
      _controller.text = seed;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _bootstrapped) return;
        _bootstrapped = true;
        _submit(seed);
      });
    }
  }
