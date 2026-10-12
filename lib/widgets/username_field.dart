import 'dart:async';

import 'package:flutter/material.dart';
import '../services/auth_service.dart';

enum _NameStatus { idle, checking, available, taken }

/// Username input with a live "available / taken" check (used at sign-up and
/// when a Google user picks their username).
class UsernameField extends StatefulWidget {
  const UsernameField({super.key, required this.controller, this.textInputAction, this.onSubmitted});
  final TextEditingController controller;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<UsernameField> createState() => _UsernameFieldState();
}

class _UsernameFieldState extends State<UsernameField> {
  final _auth = AuthService();
  Timer? _debounce;
  _NameStatus _status = _NameStatus.idle;

  @override
  void initState() {
    super.initState();
    if (widget.controller.text.isNotEmpty) _onChanged(widget.controller.text); // prefilled suggestion
  }

  /// Checks availability shortly after the user stops typing.
  void _onChanged(String value) {
    _debounce?.cancel();
    if (!AuthService.usernamePattern.hasMatch(value)) {
      setState(() => _status = _NameStatus.idle);
      return;
    }
    setState(() => _status = _NameStatus.checking);
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final free = await _auth.isUsernameAvailable(value);
        if (!mounted || widget.controller.text != value) return; // user kept typing
        setState(() => _status = free ? _NameStatus.available : _NameStatus.taken);
      } catch (_) {
        if (mounted) setState(() => _status = _NameStatus.idle); // submitting will check again
      }
    });
  }

  Widget? _suffix() => switch (_status) {
        _NameStatus.idle => null,
        _NameStatus.checking => const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        _NameStatus.available => const Icon(Icons.check_circle, color: Color(0xFF4CAF84)),
        _NameStatus.taken => Icon(Icons.cancel, color: Colors.red.shade400),
      };

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: widget.textInputAction,
      autofillHints: const [AutofillHints.newUsername],
      onChanged: _onChanged,
      onFieldSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: 'Username',
        prefixText: '@',
        helperText: 'Unique. 3-20 letters, numbers or _',
        suffixIcon: _suffix(),
      ),
      validator: (v) {
        final name = v?.trim() ?? '';
        if (!AuthService.usernamePattern.hasMatch(name)) return 'Use 3-20 letters, numbers or _';
        if (_status == _NameStatus.taken) return 'That username is already taken';
        return null;
      },
    );
  }
}
