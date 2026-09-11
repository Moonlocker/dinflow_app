import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../repositories/storage_repository.dart';

/// Campo de upload de mídia (imagem/vídeo) para o painel administrativo.
class AdminMediaUpload extends StatefulWidget {
  const AdminMediaUpload({
    super.key,
    required this.label,
    required this.bucket,
    required this.pathPrefix,
    required this.currentUrl,
    required this.onChanged,
    this.onRemove,
    this.acceptVideo = false,
    this.allowRemove = true,
  });

  final String label;
  final String bucket;
  final String pathPrefix;
  final String? currentUrl;
  final void Function(String url, String mediaType) onChanged;
  final VoidCallback? onRemove;
  final bool acceptVideo;
  final bool allowRemove;

  @override
  State<AdminMediaUpload> createState() => _AdminMediaUploadState();
}

class _AdminMediaUploadState extends State<AdminMediaUpload> {
  final _storage = StorageRepository();
  bool _uploading = false;

  Future<void> _pick() async {
    final picker = ImagePicker();
    final XFile? picked = widget.acceptVideo
        ? await picker.pickMedia()
        : await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final extension = picked.name.contains('.')
          ? picked.name.split('.').last.toLowerCase()
          : 'png';
      final isVideo = ['mp4', 'webm', 'mov', 'avi', 'mkv'].contains(extension);
      final contentType = isVideo
          ? 'video/$extension'
          : 'image/${extension == 'jpg' ? 'jpeg' : extension}';
      final path =
          '${widget.pathPrefix}-${DateTime.now().millisecondsSinceEpoch}.$extension';
      final url = await _storage.uploadPublic(
        bucket: widget.bucket,
        path: path,
        bytes: bytes,
        contentType: contentType,
      );
      if (!mounted) return;
      widget.onChanged(url, isVideo ? 'video' : 'image');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload concluído.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao enviar o arquivo.')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = widget.currentUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 110,
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          alignment: Alignment.center,
          clipBehavior: Clip.antiAlias,
          child: url == null || url.isEmpty
              ? Icon(Icons.image_outlined, color: theme.colorScheme.onSurfaceVariant)
              : (url.contains('.mp4') || url.contains('.webm'))
                  ? const Icon(Icons.videocam_outlined, size: 36)
                  : Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image_outlined, size: 32),
                    ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _uploading ? null : _pick,
              icon: _uploading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_outlined, size: 18),
              label: const Text('Enviar'),
            ),
            if (widget.allowRemove && url != null && url.isNotEmpty) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: _uploading ? null : widget.onRemove,
                child: Text(
                  'Remover',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
