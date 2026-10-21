with open('old_gabinete.html', 'r', encoding='utf-8') as f:
    old_content = f.read()

end_esc = old_content.find('<!-- PAGE: NOVA ESCALA (Wizard View) -->')
end_nova = old_content.find('<!-- OTHER PAGES PLACEHOLDERS -->')
print("End esc:", end_esc)
print("End nova:", end_nova)
