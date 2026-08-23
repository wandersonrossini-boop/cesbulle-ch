# -*- coding: utf-8 -*-
import sys

path = r'c:\Users\Wande\Documents\ia\6_APP_LAUSANNE_TESOURARIA\tesouraria_cme_app\lib\presentation\widgets\attachment_uploader.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace file_picker import with image_picker
content = content.replace("import 'package:file_picker/file_picker.dart';", "import 'package:image_picker/image_picker.dart';")

start_idx = content.find('  Future<void> _pickFile() async {')
end_idx = content.find('  Future<void> _takePhoto() async {')

if start_idx != -1 and end_idx != -1:
    new_pick = """  Future<void> _pickFile() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.gallery);
    if (photo != null) {
      final bytes = await photo.readAsBytes();
      await _upload(bytes, photo.name, 'image/jpeg');
    }
  }

"""
    content = content[:start_idx] + new_pick + content[end_idx:]
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Patched successfully!")
else:
    print("Indices not found")
