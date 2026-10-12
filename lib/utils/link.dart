import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Turns user input into a valid http(s) link, adding https:// when missing.
/// Returns null when the text is empty or not a usable web address.
Uri? parseLink(String? input) {
  var s = input?.trim() ?? '';
  if (s.isEmpty || s.contains(RegExp(r'\s'))) return null;
  if (!s.contains('://')) s = 'https://$s';
  final uri = Uri.tryParse(s);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return null;
  if (!uri.host.contains('.')) return null;
  return uri;
}

/// Short display text for a link, e.g. "upwork.com".
String linkHost(String link) {
  final host = parseLink(link)?.host ?? link;
  return host.startsWith('www.') ? host.substring(4) : host;
}

Future<void> openLink(BuildContext context, String link) async {
  final uri = parseLink(link);
  final messenger = ScaffoldMessenger.of(context);
  var ok = false;
  if (uri != null) {
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
  if (!ok) messenger.showSnackBar(const SnackBar(content: Text('Could not open this link.')));
}
