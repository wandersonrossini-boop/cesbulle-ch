import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Remove global centering from .app-main
target_app_main = '''@media(min-width: 900px) {
    .app-main {
        justify-content: center; /* Center vertically on large screens */
        padding-top: 2vh !important; /* Push it down a bit */
    }
}'''
replacement_app_main = '''@media(min-width: 900px) {
    .app-main {
        justify-content: flex-start; /* Do not push down all modules */
        padding-top: 0 !important;
    }
}'''
content = content.replace(target_app_main, replacement_app_main)

# 2. Clean up old rules FIRST
content = re.sub(r'\.global-top-nav\s*\{[^}]*\}', '', content)
content = re.sub(r'\.top-nav-btn\s*\{[^}]*\}', '', content)
content = re.sub(r'\.top-nav-btn\.active\s*\{[^}]*\}', '', content)
content = re.sub(r'\.top-nav-btn\.active::after\s*\{[^}]*\}', '', content)
content = re.sub(r'#tab-checkin > \.segmented-control\s*\{[^}]*\}', '', content)

# 3. Add reception-specific vertical positioning and center SECOND
css_reception = '''
        /* RECEPTION ISOLATED CENTERING AND SPACING */
        #tab-checkin {
            max-width: 700px;
            margin: 6vh auto 0 auto !important;
            width: 100%;
        }

        #tab-checkin > .segmented-control {
            display: flex !important;
            justify-content: center !important;
            background: transparent !important;
            border: none !important;
            padding: 0 20px !important;
            gap: 40px !important;
            margin-bottom: 4vh !important;
            max-width: 700px !important;
        }

        #tab-checkin > .segmented-control .segment-btn {
            background: transparent !important;
            border: none !important;
            color: var(--text-muted) !important;
            font-size: 0.95rem !important;
            font-weight: 600 !important;
            padding: 10px 10px !important;
            cursor: pointer !important;
            text-transform: uppercase !important;
            position: relative !important;
            transition: color 0.2s !important;
            border-radius: 0 !important;
            box-shadow: none !important;
        }

        #tab-checkin > .segmented-control .segment-btn.active {
            color: var(--gold-main) !important;
            background: transparent !important;
        }

        #tab-checkin > .segmented-control .segment-btn.active::after {
            content: '' !important;
            position: absolute !important;
            bottom: -5px !important;
            left: 0 !important;
            right: 0 !important;
            height: 2px !important;
            background: var(--gold-main) !important;
        }
'''

content = content.replace('/* INJECTED DARK THEME */', '/* INJECTED DARK THEME */\n' + css_reception)

# Fix labels
content = content.replace(">CRIANCA</button>", ">CRIANÇA</button>")
content = content.replace("ONLINE\n                </button>", "ONLINE / QR</button>")
content = content.replace(">ONLINE</button>", ">ONLINE / QR</button>")

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Reverted to clean state and applied scoped rules correctly.")
