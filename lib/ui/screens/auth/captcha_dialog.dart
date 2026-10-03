import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class CaptchaDialog extends StatefulWidget {
  final String? captchaImageBase64;
  final ValueChanged<String> onSubmit;
  final VoidCallback onCancel;

  const CaptchaDialog({
    super.key,
    required this.captchaImageBase64,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  State<CaptchaDialog> createState() => _CaptchaDialogState();
}

class _CaptchaDialogState extends State<CaptchaDialog> {
  final _controller = TextEditingController();

  Uint8List? _decodeImage() {
    if (widget.captchaImageBase64 == null) return null;
    try {
      var base64Str = widget.captchaImageBase64!;
      if (base64Str.contains(',')) {
        base64Str = base64Str.split(',')[1];
      }
      base64Str = base64Str.trim();
      final pad = 4 - (base64Str.length % 4);
      if (pad < 4) {
        base64Str += '=' * pad;
      }

      final rawBytes = base64Decode(base64Str);
      // Find JPEG EOI (0xFF, 0xD9) to strip trailing HTML from server
      for (int i = 0; i < rawBytes.length - 1; i++) {
        if (rawBytes[i] == 0xFF && rawBytes[i + 1] == 0xD9) {
          return Uint8List.fromList(rawBytes.sublist(0, i + 2));
        }
      }
      return rawBytes;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageBytes = _decodeImage();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.security_rounded, size: 22),
          SizedBox(width: 8),
          Text('Enter Security Captcha', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'SSO auto-solver required manual confirmation. Enter the characters shown below:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Container(
              height: 70,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF232328) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              alignment: Alignment.center,
              child: imageBytes != null
                  ? Image.memory(
                      imageBytes,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    )
                  : const Text('Captcha Image Unavailable', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Type characters here',
                filled: true,
                fillColor: isDark ? const Color(0xFF1E2024) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  widget.onSubmit(val.trim());
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_controller.text.trim().isNotEmpty) {
              widget.onSubmit(_controller.text.trim());
            }
          },
          child: const Text('Verify & Continue'),
        ),
      ],
    );
  }
}
