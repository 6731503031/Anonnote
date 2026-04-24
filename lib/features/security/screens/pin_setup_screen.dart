import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/pin_lock_service.dart';

enum _PinSetupStep { verifyCurrent, enterNew, confirmNew }

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key, required this.isChanging});

  final bool isChanging;

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  final PinLockService _pinLockService = PinLockService.instance;

  late _PinSetupStep _step;
  String _pin = '';
  String? _firstPin;
  String? _errorText;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _step = widget.isChanging
        ? _PinSetupStep.verifyCurrent
        : _PinSetupStep.enterNew;
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

  String get _title {
    switch (_step) {
      case _PinSetupStep.verifyCurrent:
        return 'Verify current PIN';
      case _PinSetupStep.enterNew:
        return widget.isChanging ? 'Enter new PIN' : 'Set a 4-digit PIN';
      case _PinSetupStep.confirmNew:
        return 'Confirm new PIN';
    }
  }

  String get _subtitle {
    switch (_step) {
      case _PinSetupStep.verifyCurrent:
        return 'Enter your current PIN';
      case _PinSetupStep.enterNew:
        return 'Choose a 4-digit PIN';
      case _PinSetupStep.confirmNew:
        return 'Re-enter your new PIN';
    }
  }

  void _resetInput({String? error}) {
    setState(() {
      _pin = '';
      _errorText = error;
      _pinController.clear();
    });
    _pinFocusNode.requestFocus();
  }

  Future<void> _handlePinComplete(String pin) async {
    if (_processing || pin.length != 4) return;

    setState(() {
      _processing = true;
      _errorText = null;
    });

    switch (_step) {
      case _PinSetupStep.verifyCurrent:
        final ok = await _pinLockService.verifyPin(pin);
        if (!mounted) return;
        if (!ok) {
          setState(() => _processing = false);
          _resetInput(error: 'Incorrect PIN');
          return;
        }
        setState(() {
          _processing = false;
          _step = _PinSetupStep.enterNew;
        });
        _resetInput();
        return;

      case _PinSetupStep.enterNew:
        setState(() {
          _processing = false;
          _firstPin = pin;
          _step = _PinSetupStep.confirmNew;
        });
        _resetInput();
        return;

      case _PinSetupStep.confirmNew:
        if (_firstPin != pin) {
          setState(() {
            _processing = false;
            _step = _PinSetupStep.enterNew;
            _firstPin = null;
          });
          _resetInput(error: 'PIN mismatch. Try again.');
          return;
        }
        await _pinLockService.setPin(pin);
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
    }
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
      appBar: AppBar(title: Text(widget.isChanging ? 'Change PIN' : 'Set PIN')),
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
                    Icons.pin_outlined,
                    size: 36,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(_title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(_subtitle),
                  const SizedBox(height: 22),
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
                          _handlePinComplete(value);
                        }
                      },
                    ),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (_processing)
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
