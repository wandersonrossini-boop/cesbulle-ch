import sys

def patch_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        html = f.read()

    css_cards = '''
        .desktop-bottom-cards { display: none; }
        @media (min-width: 900px) {
            .desktop-bottom-cards {
                display: grid;
                grid-template-columns: repeat(4, 1fr);
                gap: 20px;
                margin-top: 30px;
            }
            .quick-card {
                background: #ffffff;
                border: 1px solid #e2e8f0;
                border-radius: 12px;
                padding: 24px 15px;
                text-align: center;
                cursor: pointer;
                transition: all 0.2s ease;
                box-shadow: 0 2px 8px rgba(0, 0, 0, 0.02);
            }
            .quick-card:hover {
                border-color: var(--gold);
                transform: translateY(-2px);
                box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
            }
            .quick-card h4 { margin: 0 0 5px 0; font-size: 1.1rem; color: #1e293b; font-weight: 700; }
            .quick-card p { margin: 0; font-size: 0.85rem; color: #64748b; }
        }
    '''
    
    html_cards = '''
                    </div> <!-- END pc-visitor-grid -->
                    
                    <div class="desktop-bottom-cards">
                        <div class="quick-card" onclick="switchCheckinMode('child')">
                            <h4>Criança</h4>
                            <p>Check-in infantil</p>
                        </div>
                        <div class="quick-card" onclick="setTab('events')">
                            <h4>Eventos</h4>
                            <p>Check-in de eventos</p>
                        </div>
                        <div class="quick-card" onclick="switchCheckinMode('online')">
                            <h4>Online / QR</h4>
                            <p>Código de check-in</p>
                        </div>
                        <div class="quick-card" onclick="switchCheckinMode('mural')">
                            <h4>Mural</h4>
                            <p>Comunicados</p>
                        </div>
                    </div>
    '''
    
    if '.desktop-bottom-cards {' not in html:
        html = html.replace('</style>', css_cards + '\n    </style>')
        html = html.replace('</div> <!-- END pc-visitor-grid -->', html_cards)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(html)
    print("Patched cards successfully")

patch_file('recepcao_v2.html')
