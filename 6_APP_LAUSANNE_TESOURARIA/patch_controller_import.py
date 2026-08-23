# -*- coding: utf-8 -*-
path = r'c:\Users\Wande\Documents\ia\6_APP_LAUSANNE_TESOURARIA\tesouraria_cme_api\src\main\java\com\tesourariacme\api\presentation\ContributorController.java'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

import_str = """import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import com.tesourariacme.api.infrastructure.EnvelopeRepository;
"""
content = content.replace("import com.tesourariacme.api.application.ContributorService;", import_str + "import com.tesourariacme.api.application.ContributorService;")

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
