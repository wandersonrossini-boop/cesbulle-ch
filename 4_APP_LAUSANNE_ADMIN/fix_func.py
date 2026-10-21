import re
with open('js/reception_kids_logic.js', 'r', encoding='utf-8') as f:
    content = f.read()

# Let's extract the whole appendKidToMural function and replace it.
start = content.find('window.appendKidToMural = function(id, data) {')
end = content.find('function checkMuralEmpty()')

new_func = """window.appendKidToMural = function(id, data) {
    const container = document.getElementById('mural-kids-container');
    if (!container) return;
    
    if(container.innerHTML.includes('Aguardando atualizações') || container.innerHTML.includes('Nenhuma criança') || container.innerHTML.includes('Erro ao carregar')) {
        container.innerHTML = '';
    }

    const div = document.createElement('div');
    div.style.cssText = "background:#111827; border:1px solid #1F2937; padding:18px; border-radius:12px; display:flex; justify-content:space-between; align-items:center; margin-bottom:12px; box-shadow:0 2px 8px rgba(0,0,0,0.1);";
    div.innerHTML = `
        <div style="flex:1;">
            <strong style="font-size:1.15rem; display:block; color:#F8FAFC; margin-bottom:4px;">${data.name || 'Criança'}</strong>
            <div style='font-size:0.85rem; color:#94A3B8;'>Resp: <b style="color:#CBD5E1;">${data.parent_name || data.parent || 'Não informado'}</b></div>
        </div>
        <div style="text-align:right; display:flex; flex-direction:column; align-items:flex-end; gap:6px;">
            <div style="font-size:0.85rem; color:#94A3B8; font-weight:600;">${data.age_group || ''}</div>
            <div style="font-size:0.75rem; color:#10B981; font-weight:700; display:flex; align-items:center; gap:4px;"><span style="display:block; width:6px; height:6px; background:#10B981; border-radius:50%;"></span> Entregue</div>
        </div>
    `;
    container.appendChild(div);
}

"""

if start != -1 and end != -1:
    content = content[:start] + new_func + content[end:]
    with open('js/reception_kids_logic.js', 'w', encoding='utf-8') as f:
        f.write(content)
    print("Fixed function appendKidToMural!")
else:
    print("Function not found!")
