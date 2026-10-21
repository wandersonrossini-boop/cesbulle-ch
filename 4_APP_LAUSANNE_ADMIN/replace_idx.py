import re

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Define start and end markers
start_marker = "<!-- SECTION 1: OPERA"
end_marker = "<!-- Bottom Status Footer -->"

# Find indices
start_idx = content.find(start_marker)
end_idx = content.find(end_marker)

if start_idx != -1 and end_idx != -1:
    new_html = """<!-- SELECTION MODULES -->
                <div style="margin-bottom: 20px;">
                    <div class="operational-grid">

                        <!-- PASTORAL -->
                        <div class="op-card" style="background-image: url('assets/card_altar.jpg');" onclick="selectRole('gabinete')">
                            <div class="op-card-content">
                                <h3 class="op-title">PASTORAL</h3>
                                <div class="op-action">
                                    <span class="op-action-text">Acessar</span>
                                    <div class="op-action-icon"><i class="fas fa-arrow-right"></i></div>
                                </div>
                            </div>
                        </div>

                        <!-- RECEP\u00c7\u00c3O -->
                        <div class="op-card" style="background-image: url('assets/card_recepcao.png');" onclick="selectRole('reception')">
                            <div class="op-card-content">
                                <h3 class="op-title">RECEP\u00c7\u00c3O / SECRETARIA</h3>
                                <div class="op-action">
                                    <span class="op-action-text">Acessar</span>
                                    <div class="op-action-icon"><i class="fas fa-arrow-right"></i></div>
                                </div>
                            </div>
                        </div>
                        
                        <!-- ALTAR -->
                        <div class="op-card" style="background-image: url('assets/card_altar.jpg');" onclick="selectRole('altar')">
                            <div class="op-card-content">
                                <h3 class="op-title">ALTAR</h3>
                                <div class="op-action">
                                    <span class="op-action-text">Acessar</span>
                                    <div class="op-action-icon"><i class="fas fa-arrow-right"></i></div>
                                </div>
                            </div>
                        </div>

                    </div>
                </div>

                """
    
    # We need to make sure we don't accidentally cut out too much or too little.
    # Let's inspect the exact lines around start and end markers
    content = content[:start_idx] + new_html + content[end_idx:]
    
    with open('index.html', 'w', encoding='utf-8') as f:
        f.write(content)
    print("Replaced index.html modules successfully.")
else:
    print("Could not find markers.")
