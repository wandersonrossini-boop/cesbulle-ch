with open('old_gabinete.html', 'r', encoding='utf-8') as f:
    old_content = f.read()

end_nova = old_content.find('<!-- OTHER PAGES PLACEHOLDERS -->')
print(old_content[end_nova-500:end_nova])
