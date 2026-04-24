import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/pin_lock_service.dart';

class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  final PinLockService _pinLockService = PinLockService.instance;

  String _pin = '';
  String? _errorText;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pinFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
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
    _pinFocusNode.requestFocus();
  }

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final filled = i < _pin.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
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
                  _buildPinDots(),
                  const SizedBox(height: 16),
                  Opacity(
                    opacity: 0,
                    child: TextField(
                      controller: _pinController,
                      focusNode: _pinFocusNode,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _pin = value;
                          _errorText = null;
                        });
                        if (value.length == 4) {
                          _tryUnlock(value);
                        }
                      },
                    ),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (_verifying)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    TextButton(
                      onPressed: () => _pinFocusNode.requestFocus(),
                      child: const Text('Tap to enter PIN'),
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
