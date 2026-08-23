import os

files = [
    r"c:\Users\Wande\Documents\ia\6_APP_LAUSANNE_TESOURARIA\tesouraria_cme_api\src\main\java\com\tesourariacme\api\presentation\ContributorController.java",
    r"c:\Users\Wande\Documents\ia\6_APP_LAUSANNE_TESOURARIA\tesouraria_cme_api\src\main\java\com\tesourariacme\api\application\SubmitServiceClosingUseCase.java"
]

for file in files:
    with open(file, 'r', encoding='utf-8-sig') as f:
        content = f.read()
    with open(file, 'w', encoding='utf-8') as f:
        f.write(content)
