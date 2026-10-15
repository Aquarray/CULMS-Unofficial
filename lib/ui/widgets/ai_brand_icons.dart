import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../data/models/app_settings.dart';

/// Reusable vector icons for Google Gemini and OpenAI / ChatGPT.
class GeminiIcon extends StatelessWidget {
  final double size;
  final Color? color;
  final bool useGradient;

  const GeminiIcon({
    super.key,
    this.size = 20,
    this.color,
    this.useGradient = false,
  });

  static const String _geminiGradientSvg = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="geminiGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#1B72E8"/>
      <stop offset="50%" stop-color="#8E24AA"/>
      <stop offset="100%" stop-color="#D96570"/>
    </linearGradient>
  </defs>
  <path d="M11.04 19.32Q12 21.51 12 24q0-2.49.93-4.68.96-2.19 2.58-3.81t3.81-2.55Q21.51 12 24 12q-2.49 0-4.68-.93a12.3 12.3 0 0 1-3.81-2.58 12.3 12.3 0 0 1-2.58-3.81Q12 2.49 12 0q0 2.49-.96 4.68-.93 2.19-2.55 3.81a12.3 12.3 0 0 1-3.81 2.58Q2.49 12 0 12q2.49 0 4.68.96 2.19.93 3.81 2.55t2.55 3.81" fill="url(#geminiGrad)"/>
</svg>
''';

  static const String _geminiMonochromeSvg = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M11.04 19.32Q12 21.51 12 24q0-2.49.93-4.68.96-2.19 2.58-3.81t3.81-2.55Q21.51 12 24 12q-2.49 0-4.68-.93a12.3 12.3 0 0 1-3.81-2.58 12.3 12.3 0 0 1-2.58-3.81Q12 2.49 12 0q0 2.49-.96 4.68-.93 2.19-2.55 3.81a12.3 12.3 0 0 1-3.81 2.58Q2.49 12 0 12q2.49 0 4.68.96 2.19.93 3.81 2.55t2.55 3.81" fill="currentColor"/>
</svg>
''';

  @override
  Widget build(BuildContext context) {
    if (useGradient && color == null) {
      return SvgPicture.string(
        _geminiGradientSvg,
        width: size,
        height: size,
      );
    }

    final targetColor = color ?? const Color(0xFF6366F1);
    return SvgPicture.string(
      _geminiMonochromeSvg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(targetColor, BlendMode.srcIn),
    );
  }
}

/// Official OpenAI / ChatGPT rosette logo.
class OpenAiIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const OpenAiIcon({
    super.key,
    this.size = 20,
    this.color,
  });

  static const String _openAiSvg = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M22.2819 9.8211a5.9847 5.9847 0 0 0-.5157-4.9108 6.0462 6.0462 0 0 0-6.5098-2.9A6.0651 6.0651 0 0 0 4.9807 4.1818a5.9847 5.9847 0 0 0-3.9977 2.9 6.0462 6.0462 0 0 0 .7427 7.0966 5.98 5.98 0 0 0 .511 4.9107 6.051 6.051 0 0 0 6.5146 2.9001A5.9847 5.9847 0 0 0 13.2599 24a6.0557 6.0557 0 0 0 5.7718-4.2058 5.9894 5.9894 0 0 0 3.9977-2.9001 6.0557 6.0557 0 0 0-.7475-7.0729zm-9.022 12.6081a4.4755 4.4755 0 0 1-2.8764-1.0408l.1419-.0804 4.7783-2.7582a.7948.7948 0 0 0 .3927-.6813v-6.7369l2.02 1.1686a.071.071 0 0 1 .038.052v5.5826a4.504 4.504 0 0 1-4.4945 4.4944zm-9.6607-4.1254a4.4708 4.4708 0 0 1-.5346-3.0137l.142.0852 4.783 2.7582a.7712.7712 0 0 0 .7806 0l5.8428-3.3685v2.3324a.0804.0804 0 0 1-.0332.0615L9.74 19.9502a4.4992 4.4992 0 0 1-6.1408-1.6464zM2.3408 7.8956a4.485 4.485 0 0 1 2.3655-1.9728V11.6a.7664.7664 0 0 0 .3879.6765l5.8144 3.3543-2.0201 1.1685a.0757.0757 0 0 1-.071 0l-4.8303-2.7865A4.504 4.504 0 0 1 2.3408 7.872zm16.5963 3.8558L13.1038 8.364 15.1192 7.2a.0757.0757 0 0 1 .071 0l4.8303 2.7913a4.4944 4.4944 0 0 1-.6765 8.1042v-5.6772a.79.79 0 0 0-.407-.667zm2.0107-3.0231l-.142-.0852-4.7735-2.7818a.7759.7759 0 0 0-.7854 0L9.409 9.2297V6.8974a.0662.0662 0 0 1 .0284-.0615l4.8303-2.7866a4.4992 4.4992 0 0 1 6.6802 4.66zM8.3065 12.863l-2.02-1.1638a.0804.0804 0 0 1-.038-.0567V6.0742a4.4992 4.4992 0 0 1 7.3757-3.4537l-.142.0805L8.704 5.459a.7948.7948 0 0 0-.3927.6813zm1.0976-2.3654l2.602-1.4998 2.6069 1.4998v2.9994l-2.5974 1.4997-2.6067-1.4997Z" fill="currentColor"/>
</svg>
''';

  @override
  Widget build(BuildContext context) {
    final targetColor = color ?? const Color(0xFF10A37F);
    return SvgPicture.string(
      _openAiSvg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(targetColor, BlendMode.srcIn),
    );
  }
}

/// Selector widget that shows either the Google Gemini or OpenAI logo based on the provider.
class AiBrandIcon extends StatelessWidget {
  final QuizAiProvider provider;
  final double size;
  final Color? color;
  final bool useGradient;

  const AiBrandIcon({
    super.key,
    required this.provider,
    this.size = 20,
    this.color,
    this.useGradient = false,
  });

  @override
  Widget build(BuildContext context) {
    if (provider == QuizAiProvider.gemini) {
      return GeminiIcon(
        size: size,
        color: color,
        useGradient: useGradient,
      );
    } else {
      return OpenAiIcon(
        size: size,
        color: color,
      );
    }
  }
}
