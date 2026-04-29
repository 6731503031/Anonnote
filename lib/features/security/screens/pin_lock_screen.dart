import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/pin_lock_service.dart';

class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key, required this.onUnlocked, this.onForgotPin});

  final VoidCallback onUnlocked;
  final VoidCallback? onForgotPin;

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  final PinLockService _pinLockService = PinLockService.instance;

  String _pin = '';
  String? _errorText;
  bool _verifying = false;
  bool _focusRequested = false;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: -8,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -8,
          end: 8,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 8,
          end: -6,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -6,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
    ]).animate(_shakeController);
    _scheduleFocus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleFocus();
  }

  void _scheduleFocus() {
    if (_focusRequested) return;
    _focusRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_pinFocusNode);
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  Future<void> _tryUnlock(String pin) async {
    if (_verifying || pin.length != 4) return;
    setState(() {
      _verifying = true;
      _errorText = null;
    });

    final ok = await _pinLockService.verifyPin(pin);
    if (!mounted) return;

    if (ok) {
      widget.onUnlocked();
      return;
    }

    setState(() {
      _verifying = false;
      _pin = '';
      _pinController.clear();
      _errorText = 'Incorrect PIN. Try again.';
    });
    _shakeController.forward(from: 0);
    HapticFeedback.lightImpact();
    _pinFocusNode.requestFocus();
  }

  void _resetError() {
    if (_errorText == null) return;
    setState(() => _errorText = null);
  }

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final filled = i < _pin.length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: filled ? 16 : 14,
          height: filled ? 16 : 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withAlpha(80),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Enter PIN',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Unlock AnonNote',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value, 0),
                        child: child,
                      );
                    },
                    child: _buildPinDots(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pinController,
                    focusNode: _pinFocusNode,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    showCursor: false,
                    style: const TextStyle(color: Colors.transparent),
                    cursorColor: Colors.transparent,
                    enableInteractiveSelection: false,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    onTap: () =>
                        FocusScope.of(context).requestFocus(_pinFocusNode),
                    onChanged: (value) {
                      setState(() {
                        _pin = value;
                      });
                      _resetError();
                      if (value.length == 4) {
                        _tryUnlock(value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: _errorText == null
                        ? const SizedBox(height: 22)
                        : Text(
                            _errorText!,
                            key: ValueKey(_errorText),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: _verifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Column(
                            children: [
                              TextButton(
                                onPressed: () => _pinFocusNode.requestFocus(),
                                child: const Text('Tap to enter PIN'),
                              ),
                              if (widget.onForgotPin != null)
                                TextButton(
                                  onPressed: widget.onForgotPin,
                                  child: const Text('Forgot PIN?'),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
