import re

with open('altar_final.html', 'r', encoding='utf-8') as f:
    content = f.read()

# CSS additions
css_additions = '''
        /* MODAL MAIS */
        .modal-mais {
            position: fixed;
            top: 0; left: 0; width: 100%; height: 100%;
            background: rgba(0,0,0,0.6);
            backdrop-filter: blur(8px);
            -webkit-backdrop-filter: blur(8px);
            z-index: 2000;
            display: none;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        .modal-mais-content {
            background: #121418;
            border: 1px solid var(--border);
            border-radius: 16px;
            width: 100%;
            max-width: 320px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.5);
            overflow: hidden;
            animation: slideUp 0.3s cubic-bezier(0.16, 1, 0.3, 1);
        }
        .modal-mais-header {
            padding: 15px 20px;
            display: flex;
            justify-content: flex-end;
        }
        .modal-mais-btn {
            padding: 16px 25px;
            color: #E2E8F0;
            font-size: 0.95rem;
            font-weight: 500;
            cursor: pointer;
            transition: 0.2s;
        }
        .modal-mais-btn:active { background: rgba(255,255,255,0.05); }
        .modal-mais-btn.gold { color: var(--gold); }
        .modal-mais-divider { height: 1px; background: rgba(255,255,255,0.05); margin: 5px 20px; }

        @media (max-width: 900px) {
            #col-e.active {
                position: fixed;
                top: 0; left: 0; width: 100%; height: 100%;
                background: var(--bg-dark);
                z-index: 1000;
                overflow-y: auto;
                padding: 0;
            }
            .mobile-escala-header {
                display: flex !important;
                align-items: center;
                gap: 15px;
                padding: 20px;
                background: rgba(255,255,255,0.02);
                border-bottom: 1px solid var(--border);
                position: sticky; top: 0; z-index: 10;
                backdrop-filter: blur(10px);
            }
            #col-e .col-list { padding: 20px; }
            #col-e .col-header { display: none !important; }
        }
        .mobile-escala-header { display: none; }
'''
content = content.replace('/* MODAL NEW */', css_additions + '\n        /* MODAL NEW */')

if '/* MODAL MAIS */' not in content:
    content = content.replace('</style>', css_additions + '\n    </style>')

with open('altar_final.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("CSS additions injected")
