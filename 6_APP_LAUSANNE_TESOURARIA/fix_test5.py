# -*- coding: utf-8 -*-
path = r'c:\Users\Wande\Documents\ia\6_APP_LAUSANNE_TESOURARIA\tesouraria_cme_api\src\test\java\com\tesourariacme\api\presentation\ServiceClosingControllerTest.java'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('@MockBean', '')

# add mock in setUp
setup_insert = """
        attachmentRepository = mock(com.tesourariacme.api.infrastructure.ServiceClosingAttachmentRepository.class);
        storageService = mock(com.tesourariacme.api.infrastructure.StorageService.class);
        serviceClosingRepository = mock(com.tesourariacme.api.infrastructure.ServiceClosingRepository.class);
"""

content = content.replace(
    'useCase = mock(SubmitServiceClosingUseCase.class);',
    'useCase = mock(SubmitServiceClosingUseCase.class);\n' + setup_insert
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
