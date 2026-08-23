# -*- coding: utf-8 -*-
path = r'c:\Users\Wande\Documents\ia\6_APP_LAUSANNE_TESOURARIA\tesouraria_cme_api\src\test\java\com\tesourariacme\api\FinancialLifecycleIntegrationTest.java'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    '@MockBean\n    private ExpenseAttachmentRepository expenseAttachmentRepository;',
    '@MockBean\n    private ExpenseAttachmentRepository expenseAttachmentRepository;\n\n    @MockBean\n    private com.tesourariacme.api.infrastructure.ServiceClosingAttachmentRepository serviceClosingAttachmentRepository;'
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
