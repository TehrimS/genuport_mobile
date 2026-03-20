import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'screens/browser_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _appLinks = AppLinks();
  String? _initialUrl;
  StreamSubscription? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    // Handle initial deep link (when app is closed)
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        setState(() {
          _initialUrl = uri.toString();
        });
      }
    } catch (e) {
      print('Error getting initial link: $e');
    }

    // Handle deep links when app is already running
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      if (uri != null) {
        setState(() {
          _initialUrl = uri.toString();
        });
      }
    }, onError: (err) {
      print('Error listening to link stream: $err');
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BrowserPage(initialUrl: _initialUrl),
    );
  }
}