import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'choose_username_screen.dart';
import 'home_screen.dart';

/// Sends a signed-in user to the home screen once they have a username,
/// and to the "choose a username" screen if they don't.
class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key, required this.user});
  final User user;

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _profile = AuthService().profile(widget.user.uid);
  Timer? _giveUp;
  bool _timedOut = false;

  bool get _hasPassword => widget.user.providerData.any((p) => p.providerId == 'password');

  @override
  void initState() {
    super.initState();
    // If the server can't be reached we don't block the user from their tasks.
    _giveUp = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _giveUp?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _profile,
      builder: (context, snap) {
        final doc = snap.data;
        final username = doc?.data()?['username'] as String?;
        if (doc != null && doc.exists && username != null) {
          return HomeScreen(
              key: ValueKey(widget.user.uid), user: widget.user, username: username, canChangePassword: _hasPassword);
        }
        // Only a confirmed-by-server "no profile" means the user must pick a username.
        if (doc != null && !doc.exists && !doc.metadata.isFromCache) {
          return ChooseUsernameScreen(user: widget.user);
        }
        if (snap.hasError || _timedOut) {
          return HomeScreen(key: ValueKey(widget.user.uid), user: widget.user, canChangePassword: _hasPassword);
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator.adaptive()));
      },
    );
  }
}
