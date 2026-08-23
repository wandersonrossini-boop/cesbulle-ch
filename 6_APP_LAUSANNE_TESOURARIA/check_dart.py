# -*- coding: utf-8 -*-
path = r'c:\Users\Wande\Documents\ia\6_APP_LAUSANNE_TESOURARIA\tesouraria_cme_app\lib\presentation\pages\closing_detail_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# I will just revert my previous python regex mess and do it cleanly.
# Wait, actually, let me just check the raw file.
print(content[content.find('body: BlocConsumer'):content.find('Widget _buildHeader')])
