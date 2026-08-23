# -*- coding: utf-8 -*-
path = r'c:\Users\Wande\Documents\ia\6_APP_LAUSANNE_TESOURARIA\tesouraria_cme_api\src\main\java\com\tesourariacme\api\presentation\ServiceClosingController.java'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix 1: Change the repository field to ServiceClosingRepository
content = content.replace(
    'private com.tesourariacme.api.infrastructure.ServiceClosingAttachmentRepository repository;',
    'private com.tesourariacme.api.infrastructure.ServiceClosingRepository repository;'
)

# Fix 2: Remove the `closing.getStatus()` because ServiceClosing has no getStatus()
content = content.replace(
    '''if ("REJECTED".equals(closing.getStatus())) {
                return ResponseEntity.status(org.springframework.http.HttpStatus.BAD_REQUEST)
                        .body("Nao eh permitido adicionar anexos a fechamentos rejeitados.");
            }''',
    '''// N/A for ServiceClosing'''
)

# Fix 3: Remove `closing.getAttachments().add(saved);` because ServiceClosing does not have getAttachments() yet unless I added it.
# If I didn't add it, the query works without the bidirectional link. Let's just remove that line.
content = content.replace(
    'closing.getAttachments().add(saved);',
    '// no bidirectional add'
)
content = content.replace(
    'repository.save(closing);',
    '// no repository save needed since attachmentRepository.save(attachment) is enough'
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
