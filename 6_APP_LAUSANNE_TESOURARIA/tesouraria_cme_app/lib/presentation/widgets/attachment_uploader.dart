import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AttachmentUploader extends StatefulWidget {
  final String entityType; // 'despesas' or 'fechamentos'
  final String entityId;
  final VoidCallback onUploadSuccess;

  const AttachmentUploader({
    Key? key,
    required this.entityType,
    required this.entityId,
    required this.onUploadSuccess,
  }) : super(key: key);

  @override
  State<AttachmentUploader> createState() => _AttachmentUploaderState();
}

class _AttachmentUploaderState extends State<AttachmentUploader> {
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _upload(List<int> bytes, String fileName, String mimeType) async {
    setState(() { _isUploading = true; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://tesouraria-cme-api.onrender.com/api');
      
      var uri = Uri.parse('$baseUrl/${widget.entityType}/${widget.entityId}/attachments');
      var request = http.MultipartRequest('POST', uri);
      
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      
      request.fields['documentType'] = 'RECEIPT'; // Default
      
      request.files.add(http.MultipartFile.fromBytes(
        'file', 
        bytes,
        filename: fileName,
      ));

      var response = await request.send();
      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Anexo salvo com sucesso!')));
        widget.onUploadSuccess();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro no upload: ${response.statusCode}'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() { _isUploading = false; });
      }
    }
  }

  Future<void> _pickFile() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.gallery);
    if (photo != null) {
      final bytes = await photo.readAsBytes();
      await _upload(bytes, photo.name, 'image/jpeg');
    }
  }

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      final bytes = await photo.readAsBytes();
      await _upload(bytes, photo.name, 'image/jpeg');
    }
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tirar Foto (Mobile)'),
              onTap: () {
                Navigator.pop(ctx);
                _takePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('Escolher Arquivo (PDF/Imagem)'),
              onTap: () {
                Navigator.pop(ctx);
                _pickFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isUploading) {
      return const SizedBox(
        height: 48,
        width: 48,
        child: CircularProgressIndicator(),
      );
    }
    return IconButton(
      icon: const Icon(Icons.upload_file),
      color: Colors.blue,
      tooltip: 'Anexar Documento',
      onPressed: _showOptions,
    );
  }
}
