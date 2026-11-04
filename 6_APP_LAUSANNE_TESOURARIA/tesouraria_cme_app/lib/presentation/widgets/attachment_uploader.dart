import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../utils/file_download_helper.dart';

class AttachmentUploader extends StatefulWidget {
  final String entityType; // 'despesas' or 'fechamento-culto'
  final String entityId;
  final VoidCallback onUploadSuccess;
  final String defaultDocumentType;

  const AttachmentUploader({
    super.key,
    required this.entityType,
    required this.entityId,
    required this.onUploadSuccess,
    this.defaultDocumentType = 'RECEIPT',
  });

  @override
  State<AttachmentUploader> createState() => _AttachmentUploaderState();
}

class _AttachmentUploaderState extends State<AttachmentUploader> {
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _upload(Uint8List bytes, String fileName, String mimeType) async {
    // 1. Client-side Size Validation (Max 5MB)
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tamanho máximo permitido é 5MB.'),
            backgroundColor: AppTheme.excludeRed,
          ),
        );
      }
      return;
    }

    // 2. Client-side Extension & Mime Validation
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    final isValidExt = ['pdf', 'jpg', 'jpeg', 'png'].contains(ext);
    if (!isValidExt) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Formato não suportado. Apenas PDF, JPG, JPEG e PNG.'),
            backgroundColor: AppTheme.excludeRed,
          ),
        );
      }
      return;
    }

    setState(() { _isUploading = true; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://tesouraria-cme-api.onrender.com/api');

      final uri = Uri.parse('$baseUrl/${widget.entityType}/${widget.entityId}/attachments');
      final request = http.MultipartRequest('POST', uri);

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['documentType'] = widget.defaultDocumentType;

      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Documento "$fileName" anexado com sucesso!'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
        widget.onUploadSuccess();
      } else {
        String err = response.body;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao anexar ($err)'),
            backgroundColor: AppTheme.excludeRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppTheme.excludeRed),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isUploading = false; });
      }
    }
  }

  Future<void> _pickDocumentPdfOrAny() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        final ext = file.extension?.toLowerCase() ?? '';
        final mime = ext == 'pdf' ? 'application/pdf' : 'image/$ext';
        await _upload(bytes, file.name, mime);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar arquivo: $e'), backgroundColor: AppTheme.excludeRed),
        );
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.gallery);
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        await _upload(bytes, photo.name, 'image/jpeg');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir galeria: $e'), backgroundColor: AppTheme.excludeRed),
        );
      }
    }
  }

  Future<void> _takePhotoWithCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        await _upload(bytes, photo.name, 'image/jpeg');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao acessar câmera: $e'), backgroundColor: AppTheme.excludeRed),
        );
      }
    }
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text(
                  'Adicionar Documento / Anexo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.excludeRed),
                title: const Text('Selecionar Documento PDF'),
                subtitle: const Text('Faturas, comprovantes ou contratos em PDF'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickDocumentPdfOrAny();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppTheme.institutionalBlue),
                title: const Text('Galeria de Imagens (JPG / PNG)'),
                subtitle: const Text('Selecione fotos do recibo da sua galeria'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImageFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryGreen),
                title: const Text('Fotografar pela Câmera'),
                subtitle: const Text('Tire uma foto imediata do comprovante'),
                onTap: () {
                  Navigator.pop(ctx);
                  _takePhotoWithCamera();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isUploading) {
      return const SizedBox(
        height: 36,
        width: 36,
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: _showOptions,
      icon: const Icon(Icons.attach_file, size: 16),
      label: const Text('Anexar Documento', style: TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.institutionalBlue,
        side: const BorderSide(color: Color(0xFFCBD5E1)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}
