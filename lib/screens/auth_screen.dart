import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/username_field.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthService();
  bool _isLogin = true;
  bool _hide = true;
  bool _busy = false;
  bool _googleBusy = false;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isLogin) {
        await _auth.signIn(_email.text, _password.text);
      } else {
        await _auth.register(_email.text, _password.text, _username.text.trim());
      }
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    setState(() {
      _googleBusy = true;
      _error = null;
    });
    try {
      await _auth.signInWithGoogle();
    } catch (e) {
      // Closing the account picker isn't an error.
      if (mounted && !AuthService.isCancelled(e)) setState(() => _error = AuthService.message(e));
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Enter your email above, then tap "Forgot password?".');
      return;
    }
    setState(() => _error = null);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _auth.sendPasswordReset(email);
      messenger.showSnackBar(SnackBar(content: Text('Password reset link sent to $email')));
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.message(e));
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.c;
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
                    Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: kPrimary,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(color: kPrimary.withValues(alpha: .35), blurRadius: 24, offset: const Offset(0, 10)),
                          ],
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 52),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(_isLogin ? 'Welcome back!' : "Let's get started!",
                        textAlign: TextAlign.center, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text('Manage your gigs, get things done.',
                        textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: c.muted)),
                    const SizedBox(height: 32),
                    if (!_isLogin) ...[
                      UsernameField(controller: _username, textInputAction: TextInputAction.next),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Email address'),
                      validator: (v) => (v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()))
                          ? 'Enter a valid email'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _hide,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _hide = !_hide),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
                    ),
                    if (_isLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _forgotPassword,
                          child: const Text('Forgot password?', style: TextStyle(color: kPrimary, fontSize: 12)),
                        ),
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: TextStyle(color: Colors.red.shade800, fontSize: 13))),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: (_busy || _googleBusy) ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : Text(_isLogin ? 'Log in' : 'Sign up'),
                    ),
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(child: Divider(color: c.border)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or', style: TextStyle(color: c.muted, fontSize: 12)),
                      ),
                      Expanded(child: Divider(color: c.border)),
                    ]),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: (_busy || _googleBusy) ? null : _google,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        foregroundColor: c.ink,
                        side: BorderSide(color: c.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: _googleBusy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.g_mobiledata, size: 32, color: Color(0xFFDB4437)),
                      label: const Text('Continue with Google', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 20),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(_isLogin ? "Don't have an account? " : 'Already have an account? ',
                          style: TextStyle(color: c.muted, fontSize: 13)),
                      GestureDetector(
                        onTap: () => setState(() {
                          _isLogin = !_isLogin;
                          _error = null;
                          _username.clear();
                        }),
                        child: Text(_isLogin ? 'Get started!' : 'Log in',
                            style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ]),
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
