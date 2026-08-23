# -*- coding: utf-8 -*-
path = r'c:\Users\Wande\Documents\ia\6_APP_LAUSANNE_TESOURARIA\tesouraria_cme_api\src\test\java\com\tesourariacme\api\presentation\ServiceClosingControllerTest.java'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    'private SubmitServiceClosingUseCase useCase;',
    'private SubmitServiceClosingUseCase useCase;\n\n    @MockBean\n    private com.tesourariacme.api.infrastructure.ServiceClosingAttachmentRepository attachmentRepository;\n\n    @MockBean\n    private com.tesourariacme.api.infrastructure.StorageService storageService;\n\n    @MockBean\n    private com.tesourariacme.api.infrastructure.ServiceClosingRepository serviceClosingRepository;'
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
