import re

with open('index.html', 'r', encoding='utf-8') as f:
    html = f.read()

# Extract the body part where cards are
match = re.search(r'(<!-- SECTION 1: OPERAÇÃO DO CULTO.*?)\n\s*<!-- Footer Bar', html, re.DOTALL | re.IGNORECASE)
if match:
    print("=== HTML DOS CARDS ===")
    print(match.group(1))

# Extract selectRole function
match2 = re.search(r'(function selectRole\(role\).*?)\n\s*function toggleLoginMethod', html, re.DOTALL | re.IGNORECASE)
if match2:
    print("\n=== JS selectRole ===")
    print(match2.group(1))

