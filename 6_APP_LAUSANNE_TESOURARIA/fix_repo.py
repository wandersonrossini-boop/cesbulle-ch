# -*- coding: utf-8 -*-
path = r'c:\Users\Wande\Documents\ia\6_APP_LAUSANNE_TESOURARIA\tesouraria_cme_api\src\main\java\com\tesourariacme\api\infrastructure\ServiceClosingAttachmentRepository.java'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

if '@Repository' not in content:
    content = content.replace(
        'import org.springframework.data.jpa.repository.JpaRepository;',
        'import org.springframework.data.jpa.repository.JpaRepository;\nimport org.springframework.stereotype.Repository;'
    )
    content = content.replace(
        'public interface ServiceClosingAttachmentRepository',
        '@Repository\npublic interface ServiceClosingAttachmentRepository'
    )
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
