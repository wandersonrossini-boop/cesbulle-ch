import re

path = r'c:\Users\Wande\Documents\ia\6_APP_LAUSANNE_TESOURARIA\tesouraria_cme_app\lib\presentation\pages\expenses_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_func = re.search(r'void _showRecurringExpensesManager\(\).*?Future<void> _viewAttachment', content, flags=re.DOTALL)
if old_func:
    func_text = old_func.group(0)
    print("Found! Length:", len(func_text))
else:
    print("Not found.")
