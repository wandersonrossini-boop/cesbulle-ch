import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../utils/file_download_helper.dart';

class AttachmentViewerModal {
  static Future<void> viewAttachment({
    required BuildContext context,
    required String entityType,
    required String entityId,
    required String attachmentId,
    required String fileName,
    String? contentType,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://tesouraria-cme-api.onrender.com/api');

      final response = await http.get(
        Uri.parse('$baseUrl/$entityType/$entityId/attachments/$attachmentId'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (context.mounted) {
        Navigator.pop(context); // Fechar loading
      }

      if (response.statusCode == 200) {
        final Uint8List bytes = response.bodyBytes;
        final isPdf = fileName.toLowerCase().endsWith('.pdf') ||
            (contentType != null && contentType.contains('pdf'));

        if (!context.mounted) return;

        showDialog(
          context: context,
          builder: (dialogCtx) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            insetPadding: const EdgeInsets.all(20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                              color: isPdf ? AppTheme.excludeRed : AppTheme.institutionalBlue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                fileName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(dialogCtx),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: isPdf
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.picture_as_pdf_rounded, size: 64, color: AppTheme.excludeRed),
                                const SizedBox(height: 16),
                                Text(
                                  fileName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Documento PDF pronto para download ou impressão.',
                                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    downloadFile(bytes, fileName);
                                  },
                                  icon: const Icon(Icons.download_rounded),
                                  label: const Text('Baixar Arquivo PDF'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.institutionalBlue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : InteractiveViewer(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                bytes,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Text(
                                      'Não foi possível renderizar a imagem: $fileName',
                                      style: const TextStyle(color: Color(0xFF64748B)),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          downloadFile(bytes, fileName);
                        },
                        icon: const Icon(Icons.file_download_outlined, size: 18),
                        label: const Text('Baixar Arquivo'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: const Text('Fechar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        throw Exception('Status ${response.statusCode}');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao abrir anexo: $e'), backgroundColor: AppTheme.excludeRed),
        );
      }
    }
  }
}
