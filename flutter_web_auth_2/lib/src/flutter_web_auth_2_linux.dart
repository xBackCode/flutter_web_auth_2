import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2_platform_interface/flutter_web_auth_2_platform_interface.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_to_front/window_to_front.dart';

/// HTML code that generates a nice callback page.
const html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Access Granted</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    html, body { margin: 0; padding: 0; }

    main {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      font-family: -apple-system,BlinkMacSystemFont,Segoe UI,Helvetica,Arial,sans-serif,Apple Color Emoji,Segoe UI Emoji,Segoe UI Symbol;
    }

    #text {
      padding: 2em;
      text-align: center;
      font-size: 2rem;
    }
  </style>
</head>
<body>
  <main>
    <div id="text">You may now close this page</div>
  </main>
</body>
</html>
''';

/// Implements the plugin interface for Windows.
class FlutterWebAuth2LinuxPlugin extends FlutterWebAuth2Platform {
  HttpServer? _server;
  Timer? _authTimeout;

  /// Registers the Windows implementation.
  static void registerWith() {
    FlutterWebAuth2Platform.instance = FlutterWebAuth2LinuxPlugin();
  }

  @override
  Future<String> authenticate({
    required String url,
    required String callbackUrlScheme,
    required bool preferEphemeral,
    String? redirectOriginOverride,
    List contextArgs = const [],
  }) async {
    // Validate callback url
    final callbackUri = Uri.parse(callbackUrlScheme);

    if (callbackUri.scheme != 'http' ||
        (callbackUri.host != 'localhost' && callbackUri.host != '127.0.0.1') ||
        !callbackUri.hasPort) {
      throw ArgumentError(
        'Callback url scheme must start with http://localhost:{port}',
      );
    }

    await _server?.close(force: true);

    _server = await HttpServer.bind('127.0.0.1', callbackUri.port);
    String? result;

    _authTimeout?.cancel();
    _authTimeout = Timer(const Duration(seconds: 90), () {
      _server?.close();
    });

    await launchUrl(Uri.parse(url));

    await _server!.listen((req) async {
      req.response.headers.add('Content-Type', 'text/html');
      req.response.write(html);
      await req.response.close();

      result = req.requestedUri.toString();
      await _server?.close();
      _server = null;
    }).asFuture();

    await _server?.close(force: true);
    _authTimeout?.cancel();

    if (result != null) {
      await WindowToFront.activate();
      return result!;
    }
    throw PlatformException(message: 'User canceled login', code: 'CANCELED');
  }

  @override
  Future clearAllDanglingCalls() async {
    await _server?.close(force: true);
  }
}
