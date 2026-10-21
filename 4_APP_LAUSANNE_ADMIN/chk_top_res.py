with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()
if "CME LAUSANNE" in content and "letter-spacing:2px" in content:
    print("Top header was replaced successfully.")
else:
    print("Regex failed to match top header.")
