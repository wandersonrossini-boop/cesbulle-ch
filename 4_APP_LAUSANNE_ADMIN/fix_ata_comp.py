import re

with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()

pattern = re.compile(r'html \+= `\n\s*<div style="display:flex; gap:15px; margin-bottom:15px; background:#1e293b; padding:15px; border-radius:12px; border-left:3px solid \$\{color\};">.*?</div>\n\s*`;', re.DOTALL)

new_ata_comp = """// Simplify description
                        let shortDesc = d.descricao;
                        if(shortDesc.includes("foi registrado(a) pela primeira vez no sistema")) {
                            let nome = shortDesc.split(" foi ")[0];
                            nome = nome.charAt(0).toUpperCase() + nome.slice(1);
                            shortDesc = `${nome} entrou`;
                        } else if (shortDesc.includes("publicou uma nova escala")) {
                            let partes = shortDesc.split("nova escala de culto: ");
                            if (partes.length > 1) {
                                shortDesc = `Escala criada: ${partes[1].split(" para ")[0]}`;
                            }
                        }

                        let timeStr = dateObj.toLocaleTimeString('pt-BR', {hour: '2-digit', minute:'2-digit'});
                        let dateStr = dateObj.toLocaleDateString('pt-BR').substring(0,5);

                        html += `
                            <div style="padding:12px 0; border-bottom:1px solid rgba(255,255,255,0.03); display:flex; gap:15px; align-items:baseline;">
                                <div style="color:var(--text-dim); font-size:0.85rem; min-width:85px; font-variant-numeric: tabular-nums;">${dateStr} &middot; ${timeStr}</div>
                                <div style="font-size:0.9rem; color:#cbd5e1;">${shortDesc}</div>
                            </div>
                        `;"""

# We only want to replace it INSIDE loadAtaDigitalCompleta
# Let's find loadAtaDigitalCompleta
start_idx = content.find('async function loadAtaDigitalCompleta() {')
if start_idx != -1:
    end_idx = content.find('} catch(e) {', start_idx)
    sub_content = content[start_idx:end_idx]
    sub_content = re.sub(pattern, new_ata_comp, sub_content)
    content = content[:start_idx] + sub_content + content[end_idx:]

with open('gabinete.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Ata Digital Completa simplified.")
