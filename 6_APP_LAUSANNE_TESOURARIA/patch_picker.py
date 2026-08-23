# -*- coding: utf-8 -*-
import sys

path = r'c:\Users\Wande\Documents\ia\6_APP_LAUSANNE_TESOURARIA\tesouraria_cme_app\lib\presentation\widgets\attachment_uploader.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace file_picker import with image_picker
content = content.replace("import 'package:file_picker/file_picker.dart';", "import 'package:image_picker/image_picker.dart';")

# Replace the _pickFile method
start_idx = content.find('Future<void> _pickFile() async {')
if start_idx != -1:
    end_idx = content.find('Future<void> _uploadAttachment', start_idx)
    if end_idx != -1:
        new_pick_file = """Future<void> _pickFile() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        setState(() {
          _selectedFileName = image.name;
        });
        
        final bytes = await image.readAsBytes();
        
        if (widget.onFileSelected != null) {
          widget.onFileSelected!(bytes, _selectedFileName!);
        } else {
          await _uploadAttachment(bytes, _selectedFileName!);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao selecionar arquivo: $e')));
      }
    }
  }

  """
        content = content[:start_idx] + new_pick_file + content[end_idx:]
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)
        print("Patched AttachmentUploader successfully!")
    else:
        print("End index not found")
else:
    print("Start index not found")
