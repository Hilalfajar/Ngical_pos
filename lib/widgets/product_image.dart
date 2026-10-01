import 'dart:io';
import 'package:flutter/material.dart';
import '../services/product_image_cache.dart';

/// Tampilkan foto produk offline-first:
/// 1. Path lokal yang ada → Image.file
/// 2. URL http(s) → download ke cache lalu Image.file
/// 3. Gagal / kosong → placeholder
class ProductImage extends StatefulWidget {
  final String? foto;
  final int? produkId;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;

  const ProductImage({
    super.key,
    this.foto,
    this.produkId,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
  });

  @override
  State<ProductImage> createState() => _ProductImageState();
}

class _ProductImageState extends State<ProductImage> {
  String? _localPath;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ProductImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.foto != widget.foto || oldWidget.produkId != widget.produkId) {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final foto = widget.foto;
    if (foto == null || foto.trim().isEmpty) {
      if (mounted) setState(() { _localPath = null; _loading = false; });
      return;
    }

    // Path lokal langsung
    final cache = ProductImageCache.i;
    if (cache.isLocalPath(foto)) {
      if (mounted) setState(() { _localPath = foto.trim(); _loading = false; });
      return;
    }

    if (!cache.isNetworkUrl(foto)) {
      if (mounted) setState(() { _localPath = null; _loading = false; });
      return;
    }

    if (mounted) setState(() => _loading = true);
    final path = await cache.resolveLocalPath(foto, produkId: widget.produkId);
    if (!mounted) return;
    setState(() {
      _localPath = path;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (_localPath != null) {
      child = Image.file(
        File(_localPath!),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    } else if (_loading) {
      child = SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else {
      child = _placeholder();
    }

    if (widget.borderRadius != null) {
      return ClipRRect(borderRadius: widget.borderRadius!, child: child);
    }
    return child;
  }

  Widget _placeholder() {
    if (widget.placeholder != null) return widget.placeholder!;
    return Container(
      width: widget.width,
      height: widget.height,
      color: const Color(0xFFE8F0FE),
      child: Icon(
        Icons.inventory_2_outlined,
        size: (widget.width != null && widget.height != null)
            ? (widget.width! < widget.height! ? widget.width! : widget.height!) * 0.4
            : 28,
        color: const Color(0xFF5B8DEF),
      ),
    );
  }
}
