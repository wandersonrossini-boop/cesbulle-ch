# -*- coding: utf-8 -*-
path = r'c:\Users\Wande\Documents\ia\6_APP_LAUSANNE_TESOURARIA\tesouraria_cme_api\src\test\java\com\tesourariacme\api\presentation\ServiceClosingControllerTest.java'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

if 'import org.springframework.boot.test.mock.mockito.MockBean;' not in content:
    content = content.replace(
        'import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;',
        'import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;\nimport org.springframework.boot.test.mock.mockito.MockBean;'
    )

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
