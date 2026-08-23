# -*- coding: utf-8 -*-
path = r'c:\Users\Wande\Documents\ia\6_APP_LAUSANNE_TESOURARIA\tesouraria_cme_app\lib\presentation\pages\closing_detail_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Remove delete icon button
start_actions = content.find('actions: [')
if start_actions != -1:
    end_actions = content.find('],', start_actions)
    if end_actions != -1:
        new_actions = "actions: [\n          IconButton(\n            icon: const Icon(Icons.share),\n            tooltip: 'Compartilhar Relatório',\n            onPressed: () {\n              final state = context.read<HistoryBloc>().state;\n              if (state is HistoryDetailLoaded) {\n                _shareClosingDetails(state.detail);\n              }\n            },\n          ),\n        "
        content = content[:start_actions] + new_actions + content[end_actions:]

# Wrap SingleChildScrollView
old_scroll = "return SingleChildScrollView("
new_scroll = """return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: SingleChildScrollView("""
content = content.replace(old_scroll, new_scroll)

# Add missing parenthesis to close Center/ConstrainedBox
old_child = """                  _buildSummarySection(detail),
                ],
              ),
            );"""
new_child = """                  _buildSummarySection(detail),
                ],
              ),
            )));"""
content = content.replace(old_child, new_child)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Patched closing_detail_page.dart!")
