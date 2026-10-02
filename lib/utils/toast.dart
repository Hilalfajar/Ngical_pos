import 'package:flutter/material.dart';
import '../theme.dart';

enum ToastType { success, error, info, warning }

class AppToast {
  static OverlayEntry? _current;

  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
    String? title,
  }) {
    // Tutup toast sebelumnya
    _current?.remove();
    _current = null;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _ToastWidget(
        message: message,
        title: title,
        type: type,
        onDismiss: () {
          entry.remove();
          if (_current == entry) _current = null;
        },
      ),
    );

    _current = entry;
    overlay.insert(entry);

    // Auto dismiss
    Future.delayed(duration, () {
      if (entry.mounted) {
        entry.remove();
        if (_current == entry) _current = null;
      }
    });
  }

  static void success(BuildContext context, String message, {String? title}) =>
      show(context, message, type: ToastType.success, title: title);

  static void error(BuildContext context, String message, {String? title}) =>
      show(context, message,
          type: ToastType.error,
          title: title,
          duration: const Duration(seconds: 5));

  static void info(BuildContext context, String message, {String? title}) =>
      show(context, message, type: ToastType.info, title: title);

  static void warning(BuildContext context, String message, {String? title}) =>
      show(context, message, type: ToastType.warning, title: title);
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final String? title;
  final ToastType type;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
    this.title,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _bg {
    switch (widget.type) {
      case ToastType.success:
        return const Color(0xFFECFDF5);
      case ToastType.error:
        return const Color(0xFFFEF2F2);
      case ToastType.warning:
        return const Color(0xFFFFFBEB);
      case ToastType.info:
        return const Color(0xFFEFF6FF);
    }
  }

  Color get _border {
    switch (widget.type) {
      case ToastType.success:
        return const Color(0xFF86EFAC);
      case ToastType.error:
        return const Color(0xFFFCA5A5);
      case ToastType.warning:
        return const Color(0xFFFDE68A);
      case ToastType.info:
        return const Color(0xFF93C5FD);
    }
  }

  Color get _iconColor {
    switch (widget.type) {
      case ToastType.success:
        return C.success;
      case ToastType.error:
        return C.danger;
      case ToastType.warning:
        return C.warning;
      case ToastType.info:
        return C.brand;
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case ToastType.success:
        return Icons.check_circle_rounded;
      case ToastType.error:
        return Icons.cancel_rounded;
      case ToastType.warning:
        return Icons.warning_rounded;
      case ToastType.info:
        return Icons.info_rounded;
    }
  }

  String get _defaultTitle {
    switch (widget.type) {
      case ToastType.success:
        return 'Berhasil';
      case ToastType.error:
        return 'Gagal';
      case ToastType.warning:
        return 'Perhatian';
      case ToastType.info:
        return 'Info';
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final isPc = MediaQuery.of(context).size.width >= 1100;

    // Di PC: pojok kanan bawah, lebar 360, tidak menghalangi konten utama
    // Di HP: atas full width seperti biasa
    if (isPc) {
      return Positioned(
        bottom: 32,
        right: 24,
        width: 360,
        child: Material(
          color: Colors.transparent,
          child: FadeTransition(
            opacity: _opacity,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.3, 0),
                end: Offset.zero,
              ).animate(
                  CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic)),
              child: GestureDetector(
                onTap: widget.onDismiss,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _border, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: _iconColor.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _iconColor.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_icon, color: _iconColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title ?? _defaultTitle,
                              style: TextStyle(
                                color: _iconColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.message,
                              style: TextStyle(
                                color: _iconColor.withOpacity(0.85),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onDismiss,
                        child: Icon(Icons.close_rounded,
                            size: 18, color: _iconColor.withOpacity(0.6)),
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

    return Positioned(
      top: topPad + 12,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _opacity,
          child: SlideTransition(
            position: _slide,
            child: GestureDetector(
              onTap: widget.onDismiss,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: _iconColor.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _iconColor.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_icon, color: _iconColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title ?? _defaultTitle,
                            style: TextStyle(
                              color: _iconColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.message,
                            style: TextStyle(
                              color: _iconColor.withOpacity(0.85),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onDismiss,
                      child: Icon(Icons.close_rounded,
                          size: 18, color: _iconColor.withOpacity(0.6)),
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
