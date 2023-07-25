import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'assets/colors.dart';
import 'helper/enums.dart';

class WebViewMain extends StatefulWidget {
  const WebViewMain({super.key});

  @override
  State<WebViewMain> createState() => _WebViewMainState();
}

class _WebViewMainState extends State<WebViewMain> {
  late final WebViewController _controller;
  late var _loadingPercentage = 0;
  late final _urlBase = 'https://ansinsuranceservices.com/';

  @override
  void initState() {
    super.initState();

    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(CustomColors.background)
      ..setNavigationDelegate(
        NavigationDelegate(onProgress: (int progress) {
          setState(() {
            _loadingPercentage = progress;
          });
        }, onPageStarted: (String url) {
          setState(() {
            _loadingPercentage = 0;
          });
        }, onPageFinished: (String url) {
          setState(() {
            _loadingPercentage = 100;
          });
        }, onWebResourceError: (WebResourceError error) {
          debugPrint('''Page resource error:
              code: ${error.errorCode}
              description: ${error.description}
              errorType: ${error.errorType}
              isForMainFrame: ${error.isForMainFrame}''');
        }, onNavigationRequest: (NavigationRequest request) {
          final url = request.url;
          if (url.startsWith('tel:')) {
            _makePhoneCall(url);
            return NavigationDecision.prevent;
          } else if (_isSomeSocialNetwork(url)) {
            _launchNativeApp(url);
            return NavigationDecision.prevent;
          } else if (!url.contains(_urlBase)) {
            _launchUniversalLink(
                Uri.parse(url), LaunchMode.externalNonBrowserApplication);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        }, onUrlChange: (UrlChange change) {
          debugPrint('url change to ${change.url}');
        }),
      )
      ..addJavaScriptChannel(
        'Toaster',
        onMessageReceived: (JavaScriptMessage message) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message.message)),
          );
        },
      )
      ..loadRequest(Uri.parse(_urlBase));

    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    _controller = controller;
    //_controller.clearLocalStorage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        drawerScrimColor: CustomColors.background,
        backgroundColor: CustomColors.background,
        extendBody: true,
        body: WillPopScope(
            onWillPop: () async {
              return _isFinishOfApp();
            },
            child: Stack(children: [
              SafeArea(child: WebViewWidget(controller: _controller)),
              if (_loadingPercentage < 100)
                Center(
                    child: CircularProgressIndicator(
                  backgroundColor: CustomColors.secondary,
                  color: Colors.white,
                  value: _loadingPercentage / 100.0,
                ))
            ])));
  }

  Future<bool> _isFinishOfApp() async {
    String? currentUrl = await _controller.currentUrl();
    if (currentUrl.toString() == _urlBase) {
      return true;
    }
    if (await _controller.canGoBack()) {
      _controller.goBack();
      return false;
    } else {
      /*ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No back history item')),
      );*/
      return true;
    }
  }

  Future<void> _makePhoneCall(String url) async {
    final phoneNumber = url.replaceFirst("tel:", "");
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    await launchUrl(launchUri);
  }

  bool _isSomeSocialNetwork(String url) {
    String pattern =
        '(${SocialNetworksBaseUrl.values.map((element) => element.value).join('|')})';
    RegExp regex = RegExp(pattern, caseSensitive: false);
    return regex.hasMatch(url);
  }

  void _launchNativeApp(String url) {
    dynamic uri;

    if (url.contains(SocialNetworksBaseUrl.instagram.value)) {
      final username =
          _getUsernameExtracted(url, SocialNetworksBaseUrl.instagram.value);
      uri = Uri.parse("instagram://user?username=$username");
    } else if (url.contains(SocialNetworksBaseUrl.facebook.value)) {
      final username =
          _getUsernameExtracted(url, SocialNetworksBaseUrl.facebook.value);
      uri = Uri.parse("fb://profile/$username");
    } else if (url.contains(SocialNetworksBaseUrl.fb.value)) {
      final username =
          _getUsernameExtracted(url, SocialNetworksBaseUrl.fb.value);
      uri = Uri.parse("fb://profile/$username");
    } else if (url.contains(SocialNetworksBaseUrl.youtube.value)) {
      uri = Uri.parse(url);
    }
    if (uri != null) {
      _launchUniversalLink(uri, LaunchMode.externalNonBrowserApplication);
    }
  }

  String _getUsernameExtracted(String url, String toSplit) {
    final splitUrl = url.split(toSplit);
    final username = splitUrl[1].replaceAll(RegExp(r'/'), '').trim();
    return username;
  }

  Future<void> _launchUniversalLink(Uri url, LaunchMode launchMode) async {
    final bool nativeAppLaunchSucceeded = await launchUrl(
      url,
      mode: launchMode,
    );
    if (!nativeAppLaunchSucceeded) {
      await launchUrl(
        url,
        mode: LaunchMode.inAppWebView,
      );
    }
  }
}
