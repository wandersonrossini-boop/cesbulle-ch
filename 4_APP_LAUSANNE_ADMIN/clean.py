import sys
import re

def clean_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        html = f.read()

    # Change fonts to more classic ones
    html = html.replace("--font-body: 'Outfit', -apple-system, BlinkMacSystemFont, sans-serif;", "--font-body: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;")
    html = html.replace("--gold: #9e793e;", "--gold: #a68a56;")
    html = html.replace("--gold-hover: #86642d;", "--gold-hover: #8b7348;")
    html = html.replace("box-shadow: 0 0 50px rgba(255, 179, 0, 0.15);", "box-shadow: none;")
    html = html.replace("box-shadow: 0 4px 20px rgba(255, 179, 0, 0.05);", "box-shadow: none;")
    html = html.replace("box-shadow: 0 10px 30px rgba(0, 0, 0, 0.8);", "box-shadow: 0 4px 12px rgba(0,0,0,0.1);")
    html = html.replace("box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);", "box-shadow: none; border: 1px solid #e5e7eb;")
    html = html.replace("box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);", "box-shadow: none; border-color: #d1d5db;")
    html = html.replace("background: linear-gradient(135deg, #7c3aed 0%, #3b82f6 100%);", "background: #3b82f6;")
    
    # Remove emojis from inline HTML
    html = re.sub(r'🇨🇭|🇵🇹|🇪🇸|🇫🇷|🇮🇹|🇩🇪|🇬🇧|🇧🇷', '', html)

    # Adjust gold buttons
    html = html.replace("background: #9e793e !important;", "background: #a68a56 !important;")
    html = html.replace("border: 1px solid #86642d !important;", "border: none !important;")
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(html)
    print("Cleaned successfully")

clean_file('recepcao_v2.html')
