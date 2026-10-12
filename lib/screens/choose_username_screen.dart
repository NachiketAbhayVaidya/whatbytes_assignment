import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/username_field.dart';

/// Shown to signed-in users who have no username yet (new Google users, and
/// accounts created before usernames existed).
class ChooseUsernameScreen extends StatefulWidget {
  const ChooseUsernameScreen({super.key, required this.user});
  final User user;

  @override
  State<ChooseUsernameScreen> createState() => _ChooseUsernameScreenState();
}

class _ChooseUsernameScreenState extends State<ChooseUsernameScreen> {
  final _form = GlobalKey<FormState>();
  late final _username = TextEditingController(text: AuthService.suggestUsername(widget.user.email));
  final _auth = AuthService();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.claimUsername(widget.user, _username.text.trim());
      // The profile stream now reports the username and the gate moves on to Home.
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = AuthService.message(e);
        });
      }
    }
  }

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.alternate_email, size: 56, color: kPrimary),
                    const SizedBox(height: 20),
                    Text('Choose your username',
                        textAlign: TextAlign.center, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(
                      'Signed in as ${widget.user.email ?? widget.user.displayName ?? 'your account'}.\n'
                      'Pick a unique @username to finish setting up.',
                      textAlign: TextAlign.center,
                      style: t.bodyMedium?.copyWith(color: context.c.muted),
                    ),
                    const SizedBox(height: 28),
                    UsernameField(controller: _username, onSubmitted: (_) => _submit()),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Text('Continue'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _auth.signOut,
                      child: Text('Use a different account', style: TextStyle(color: context.c.muted)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
