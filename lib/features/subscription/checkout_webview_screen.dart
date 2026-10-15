import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../models/checkout_session.dart';
import 'checkout_launcher.dart';

/// The payment provider's hosted checkout page. Card and wallet details are
/// typed into the provider's page, never into the app. The screen closes by
/// itself when the provider redirects to the session's return URL.
class CheckoutWebViewScreen extends StatefulWidget {
  const CheckoutWebViewScreen({super.key, required this.session});

  final CheckoutSession session;

  @override
  State<CheckoutWebViewScreen> createState() => _CheckoutWebViewScreenState();
}

class _CheckoutWebViewScreenState extends State<CheckoutWebViewScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // The app's background, so there is no white flash while the page loads.
      ..setBackgroundColor(AppColors.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onNavigationRequest: (request) => _handleUrl(request.url)
              ? NavigationDecision.prevent
              : NavigationDecision.navigate,
          // A redirect after a form POST does not always pass through
          // onNavigationRequest on Android, so watch page starts too.
          onPageStarted: _handleUrl,
          onUrlChange: (change) {
            if (change.url != null) _handleUrl(change.url!);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.session.checkoutUrl!));
  }

  /// Closes the screen when [url] is the return URL. Returns whether it did.
  bool _handleUrl(String url) {
    final returnUrl = Uri.parse(widget.session.returnUrl);
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.origin != returnUrl.origin ||
        uri.path != returnUrl.path) {
      return false;
    }
    if (!_closed) {
      _closed = true;
      Navigator.of(context).pop(
        uri.queryParameters['canceled'] == '1'
            ? CheckoutReturn.canceled
            : CheckoutReturn.returned,
      );
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          tooltip: 'Close checkout',
          icon: const Icon(Icons.close_rounded),
          onPressed: () =>
              Navigator.of(context).pop(CheckoutReturn.dismissed),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded, size: 16),
            const SizedBox(width: 6),
            Text(
              'Secure checkout · ${widget.session.amount.formatted}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _progress / 100,
                  minHeight: 2,
                ),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
