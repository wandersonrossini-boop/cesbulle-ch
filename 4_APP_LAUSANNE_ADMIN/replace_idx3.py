import re

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

start_idx = content.find("<!-- SECTION 1:")
end_idx = content.find("<!-- Footer Bar -->")

if start_idx != -1 and end_idx != -1:
    # Need to keep the closing </div> of portal-layout which is right before Footer Bar
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
                                <h3 class="op-title">RECEP\u00c7\u00c3O</h3>
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

            </div>

            """
    content = content[:start_idx] + new_html + content[end_idx:]
    with open('index.html', 'w', encoding='utf-8') as f:
        f.write(content)
    print("Replaced index.html modules successfully.")
else:
    print("Not found")
