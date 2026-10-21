import re

with open('old_gabinete.html', 'r', encoding='utf-8') as f:
    old_content = f.read()

# Extract page-escalas
start_esc = old_content.find('<!-- PAGE: ESCALAS (List View) -->')
end_esc = old_content.find('<!-- PAGE: NOVA ESCALA (Wizard View) -->')
page_escalas = old_content[start_esc:end_esc]

# Extract page-nova-escala
start_nova = end_esc
end_nova = old_content.find('<!-- OTHER PAGES PLACEHOLDERS -->')
page_nova = old_content[start_nova:end_nova]

with open('gabinete.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Inject them back before OTHER PAGES PLACEHOLDERS
target = '<!-- OTHER PAGES PLACEHOLDERS -->'
insertion = page_escalas + page_nova + target

content = content.replace(target, insertion)

# Also fix the JS error that crashed the app at startup: `document.getElementById('kpi-lideres').innerText = leaders;`
# Since I removed the KPIs, loadKPIs() shouldn't try to update them.
old_kpi_func = """        async function loadKPIs() {
            try {
                // Lideres from config/notification_leaders
                const doc = await db.collection('config').doc('notification_leaders').get();
                let leaders = 0;
                if (doc.exists && doc.data().leaders) {
                    leaders = doc.data().leaders.length;
                }
                document.getElementById('kpi-lideres').innerText = leaders;

                // Ministerios from ministerios_list
                const mSnap = await db.collection('ministerios_list').get();
                document.getElementById('kpi-ministerios').innerText = mSnap.size;

                // Igreja from admin config
                const adminDoc = await db.collection('config').doc('admin_dashboard').get();
                if (adminDoc.exists && adminDoc.data().igreja_count) {
                    document.getElementById('kpi-igreja').innerText = adminDoc.data().igreja_count;
                } else {
                    document.getElementById('kpi-igreja').innerText = '0';
                }
            } catch(e) {
                console.error("Error loading KPIs", e);
            }
        }"""
        
new_kpi_func = """        async function loadKPIs() {
            // KPIs removidos do painel principal, função desativada temporariamente.
        }"""
content = content.replace(old_kpi_func, new_kpi_func)

with open('gabinete.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Restored page-escalas and page-nova-escala, disabled loadKPIs")
