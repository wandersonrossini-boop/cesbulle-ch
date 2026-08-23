# -*- coding: utf-8 -*-
path = r'c:\Users\Wande\Documents\ia\6_APP_LAUSANNE_TESOURARIA\tesouraria_cme_api\src\test\java\com\tesourariacme\api\presentation\ContributorControllerTest.java'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    'import com.tesourariacme.api.application.ContributorService;',
    'import com.tesourariacme.api.application.ContributorService;\nimport com.tesourariacme.api.infrastructure.EnvelopeRepository;'
)
content = content.replace(
    'private ContributorService service;',
    'private ContributorService service;\n    private EnvelopeRepository envelopeRepository;'
)
content = content.replace(
    'controller = new ContributorController(service, attestationService, auditLogService);',
    'envelopeRepository = mock(EnvelopeRepository.class);\n        controller = new ContributorController(envelopeRepository, service, attestationService, auditLogService);'
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
