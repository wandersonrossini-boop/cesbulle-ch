import re

with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add media query to the end of CSS
target_css = '''@media print {
                            body {
                                background-color: #b3d2be !important;
                                -webkit-print-color-adjust: exact;
                                print-color-adjust: exact;
                            }
                        }
                    </style>'''

replacement_css = '''@media print {
                            body {
                                background-color: #b3d2be !important;
                                -webkit-print-color-adjust: exact;
                                print-color-adjust: exact;
                            }
                        }

                        /* MOBILE RESPONSIVENESS */
                        @media (max-width: 900px) {
                            .topbar {
                                flex-direction: column;
                                align-items: flex-start;
                                gap: 20px;
                                padding: 25px 20px;
                            }
                            .stats-row {
                                width: 100%;
                                flex-wrap: wrap;
                                justify-content: space-between;
                                gap: 10px;
                            }
                            .stat-btn {
                                min-width: unset;
                                flex: 1 1 calc(33.333% - 10px);
                                padding: 12px 10px;
                            }
                            .stat-btn span {
                                font-size: 0.65rem;
                            }
                            .stat-btn .val {
                                font-size: 2rem;
                            }
                            #btn-e {
                                display: none !important;
                            }
                            .mobile-escala-trigger {
                                display: flex !important;
                                width: 100%;
                                background: rgba(201, 160, 80, 0.08);
                                border: 1px solid var(--border-gold, rgba(201, 160, 80, 0.3));
                                color: var(--gold);
                                padding: 14px;
                                border-radius: 12px;
                                justify-content: center;
                                align-items: center;
                                gap: 10px;
                                font-size: 0.85rem;
                                font-weight: 700;
                                text-transform: uppercase;
                                letter-spacing: 1px;
                                cursor: pointer;
                                transition: 0.2s;
                            }
                            .mobile-escala-trigger:active {
                                background: rgba(201, 160, 80, 0.15);
                            }
                        }
                        .mobile-escala-trigger {
                            display: none;
                        }
                    </style>'''

content = content.replace(target_css, replacement_css)

# 2. Add the mobile trigger button in HTML
target_html = '''                <div class="stat-btn" id="btn-c" onclick="setTab('c')">
                    <span>Celebrações</span>
                    <div class="val" id="val-c">0</div>
                </div>
            </div>
        </div>'''

replacement_html = '''                <div class="stat-btn" id="btn-c" onclick="setTab('c')">
                    <span>Celebrações</span>
                    <div class="val" id="val-c">0</div>
                </div>
            </div>
            
            <!-- Mobile Escala Trigger -->
            <div class="mobile-escala-trigger" onclick="setTab('e')">
                <i class="fas fa-list-ul"></i> Escala de Culto
            </div>
        </div>'''

content = content.replace(target_html, replacement_html)

with open('altar_final.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("altar_final.html updated")
