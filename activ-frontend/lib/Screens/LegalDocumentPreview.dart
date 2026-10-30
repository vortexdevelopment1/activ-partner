import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

/// Uses uploaded/restored bytes so previews work without a device file path.
class LegalDocumentPreview extends StatefulWidget {
  const LegalDocumentPreview({super.key, required this.bytes});

  final Uint8List bytes;

  static bool isPdf(Uint8List bytes) =>
      bytes.length >= 5 && String.fromCharCodes(bytes.sublist(0, 5)) == '%PDF-';

  static Future<void> open(
      BuildContext context, Uint8List bytes, String title) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Row(children: [
            const SizedBox(width: 16),
            Expanded(
                child: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700))),
            IconButton(
                tooltip: 'Close preview',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close)),
          ]),
          Expanded(child: LegalDocumentPreview(bytes: bytes)),
        ]),
      ),
    );
  }

  @override
  State<LegalDocumentPreview> createState() => _LegalDocumentPreviewState();
}

class _LegalDocumentPreviewState extends State<LegalDocumentPreview> {
  PdfControllerPinch? _controller;

  @override
  void initState() {
    super.initState();
    _openPdf();
  }

  void _openPdf() {
    if (LegalDocumentPreview.isPdf(widget.bytes)) {
      _controller =
          PdfControllerPinch(document: PdfDocument.openData(widget.bytes));
    }
  }

  @override
  void didUpdateWidget(covariant LegalDocumentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes)) {
      _controller?.dispose();
      _controller = null;
      _openPdf();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Colors.white,
        child: _controller != null
            ? PdfViewPinch(
                controller: _controller!,
                builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
                  options: const DefaultBuilderOptions(),
                  documentLoaderBuilder: (_) =>
                      const Center(child: CircularProgressIndicator()),
                  errorBuilder: (_, error) => const Center(
                      child: Text(
                          'Unable to preview this PDF. Please upload a valid PDF.')),
                ),
              )
            : InteractiveViewer(
                maxScale: 5,
                child: Center(
                    child: Image.memory(widget.bytes,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Text('Unable to preview this document.'))),
              ),
      );
}
