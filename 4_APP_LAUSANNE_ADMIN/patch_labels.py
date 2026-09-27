import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix labels
content = content.replace(">CRIANCA</button>", ">CRIANÇA</button>")
content = content.replace("ONLINE\n                </button>", "ONLINE / QR</button>")
content = content.replace(">ONLINE</button>", ">ONLINE / QR</button>")

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Labels fixed.")
