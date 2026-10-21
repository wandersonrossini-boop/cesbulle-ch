import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

toast_css = '''
        /* TEMPORARY TOAST */
        .toast-notification {
            position: fixed;
            top: 20px;
            left: 50%;
            transform: translateX(-50%) translateY(-20px);
            background: #121418;
            border: 1px solid var(--gold);
            color: #fff;
            padding: 12px 24px;
            border-radius: 8px;
            font-size: 0.95rem;
            font-weight: 500;
            box-shadow: 0 10px 25px rgba(0,0,0,0.5);
            z-index: 9999;
            opacity: 0;
            transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1);
            pointer-events: none;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .toast-notification.show {
            transform: translateX(-50%) translateY(0);
            opacity: 1;
        }
'''

content = content.replace('</style>', toast_css + '\n    </style>')

toast_html = '''
    <!-- Toast Notification -->
    <div id="toast-notification" class="toast-notification">
        <i class="fas fa-check-circle" style="color: var(--gold);"></i>
        <span id="toast-message">Mensagem enviada com sucesso</span>
    </div>
'''

content = content.replace('</body>', toast_html + '\n</body>')

toast_js = '''
        function showToast(message) {
            const toast = document.getElementById('toast-notification');
            const msgEl = document.getElementById('toast-message');
            if (toast && msgEl) {
                msgEl.innerText = message || "Mensagem enviada com sucesso";
                toast.classList.add('show');
                setTimeout(() => {
                    toast.classList.remove('show');
                }, 3000);
            }
        }
'''

content = content.replace('</script>\n</body>', toast_js + '\n</script>\n</body>')

# Replace all alert("Enviada com sucesso!"); with showToast("Mensagem enviada com sucesso");
content = content.replace('alert("Enviada com sucesso!");', 'showToast("Mensagem enviada com sucesso");')

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Toast added and alerts replaced in recepcao_v2.html")
