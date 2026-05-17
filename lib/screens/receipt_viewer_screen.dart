import 'dart:io';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../main.dart';

class ReceiptViewerScreen extends StatelessWidget {
  final String imagePath;
  final VoidCallback? onDelete;

  const ReceiptViewerScreen({
    super.key,
    required this.imagePath,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (_, isSpanish, __) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(
              isSpanish ? 'Recibo adjunto' : 'Attached Receipt',
            ),
            actions: [
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Colors.redAccent),
                  tooltip: isSpanish ? 'Eliminar foto' : 'Delete photo',
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (d) => AlertDialog(
                        title:
                            Text(isSpanish ? 'Eliminar foto' : 'Delete photo'),
                        content: Text(isSpanish
                            ? '¿Eliminar esta foto del recibo?'
                            : 'Delete this receipt photo?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(d, false),
                            child: Text(isSpanish ? 'Cancelar' : 'Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(d, true),
                            child: Text(
                              isSpanish ? 'Eliminar' : 'Delete',
                              style: const TextStyle(color: AppTheme.dangerRed),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      onDelete!();
                      if (context.mounted) Navigator.of(context).pop();
                    }
                  },
                ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Image.file(
                File(imagePath),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.broken_image_rounded,
                        color: Colors.white54, size: 64),
                    const SizedBox(height: 12),
                    Text(
                      isSpanish
                          ? 'No se pudo cargar la imagen'
                          : 'Could not load image',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
