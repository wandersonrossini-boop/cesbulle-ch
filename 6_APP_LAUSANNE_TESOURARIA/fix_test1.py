# -*- coding: utf-8 -*-
path = r'c:\Users\Wande\Documents\ia\6_APP_LAUSANNE_TESOURARIA\tesouraria_cme_api\src\test\java\com\tesourariacme\api\application\ContributorServiceTest.java'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    'import com.tesourariacme.api.infrastructure.ContributorRepository;',
    'import com.tesourariacme.api.infrastructure.ContributorRepository;\nimport com.tesourariacme.api.infrastructure.EnvelopeRepository;'
)
content = content.replace(
    'private ContributorRepository repository;',
    'private ContributorRepository repository;\n    private EnvelopeRepository envelopeRepository;'
)
content = content.replace(
    'service = new ContributorService(repository);',
    'envelopeRepository = mock(EnvelopeRepository.class);\n        service = new ContributorService(repository, envelopeRepository);'
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
