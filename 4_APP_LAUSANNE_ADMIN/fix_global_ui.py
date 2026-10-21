import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Fix Segmented Controls Background
# We want to remove the `#F1F5F9 !important` and make it dark.
old_seg_css = '''        .segmented-control {
            display: flex !important;
            background: #F1F5F9 !important;
            border-radius: 4px !important;
            padding: 3px !important;
            border: 1px solid var(--border-color) !important;
            gap: 4px !important;
            margin-bottom: 20px !important;
        }'''
        
new_seg_css = '''        .segmented-control {
            display: flex !important;
            background: #111827 !important;
            border-radius: 6px !important;
            padding: 4px !important;
            border: 1px solid #1F2937 !important;
            gap: 4px !important;
            margin-bottom: 20px !important;
        }'''
content = content.replace(old_seg_css, new_seg_css)

# Also fix the general segmented-control without !important at line 439
old_seg2_css = '''        .segmented-control {
            display: flex;
            background: var(--bg-dark-element);
            border-radius: 4px;
            padding: 4px;
            margin-bottom: 20px;
            border: 1px solid var(--border-dark);
            gap: 4px;
        }'''
new_seg2_css = '''        .segmented-control {
            display: flex;
            background: #111827;
            border-radius: 6px;
            padding: 4px;
            margin-bottom: 20px;
            border: 1px solid #1F2937;
            gap: 4px;
        }'''
content = content.replace(old_seg2_css, new_seg2_css)

# Fix segmented control buttons
old_btn_css = '''        .segment-btn {
            flex: 1 !important;
            padding: 10px 14px !important;
            font-size: 0.85rem !important;
            font-weight: 600 !important;
            color: var(--text-muted) !important;
            border: none !important;
            border-radius: 4px !important;
            background: transparent !important;
            cursor: pointer !important;
            text-align: center !important;
        }
        .segment-btn.active {
            background: var(--navy-main) !important;
            color: #FFFFFF !important;
        }'''
        
new_btn_css = '''        .segment-btn {
            flex: 1 !important;
            padding: 10px 14px !important;
            font-size: 0.85rem !important;
            font-weight: 600 !important;
            color: #94A3B8 !important;
            border: none !important;
            border-radius: 4px !important;
            background: transparent !important;
            cursor: pointer !important;
            text-align: center !important;
            transition: all 0.2s;
        }
        .segment-btn.active {
            background: #1F2937 !important;
            color: #F8FAFC !important;
            box-shadow: 0 1px 3px rgba(0,0,0,0.2) !important;
        }'''
content = content.replace(old_btn_css, new_btn_css)

# 2. Fix the Ministry Cards (Servir)
# Look for .ministry-card
old_min_css = '''                .ministry-card {
                    background: #f8f9fa;
                    border: 2px solid #e9ecef;
                    border-radius: 4px;
                    padding: 10px;
                    /* Reduced padding */
                    text-align: center;
                    cursor: pointer;
                    transition: all 0.2s;
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    justify-content: center;
                }

                .ministry-card:active {
                    transform: scale(0.98);
                }

                .ministry-card.selected {
                    background: var(--navy-card);
                    border-color: var(--text-light);
                    box-shadow: 0 4px 10px rgba(255, 199, 44, 0.2);
                }

                .ministry-card i {
                    font-size: 1.2rem;
                    /* Reduced icon */
                    color: #adb5bd;
                    margin-bottom: 5px;
                    display: block;
                }

                .ministry-card.selected i {
                    color: #DA291C;
                }

                .ministry-card span {
                    font-weight: 600;
                    color: #495057;
                    font-size: 0.75rem;
                    /* Reduced font */
                    line-height: 1.1;
                }

                .ministry-card.selected span {
                    color: #212529;
                }'''
                
new_min_css = '''                .ministry-card {
                    background: #111827;
                    border: 1px solid #1F2937;
                    border-radius: 6px;
                    padding: 12px;
                    text-align: center;
                    cursor: pointer;
                    transition: all 0.2s;
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    justify-content: center;
                }

                .ministry-card:active {
                    transform: scale(0.98);
                }

                .ministry-card.selected {
                    background: #1F2937;
                    border-color: var(--gold-main);
                    box-shadow: 0 4px 10px rgba(201, 160, 80, 0.1);
                }

                .ministry-card i {
                    font-size: 1.2rem;
                    color: #64748B;
                    margin-bottom: 5px;
                    display: block;
                }

                .ministry-card.selected i {
                    color: var(--gold-main);
                }

                .ministry-card span {
                    font-weight: 600;
                    color: #94A3B8;
                    font-size: 0.8rem;
                    line-height: 1.1;
                }

                .ministry-card.selected span {
                    color: #F8FAFC;
                }'''
content = content.replace(old_min_css, new_min_css)

# Also fix the "Seus Dados" header below Servir which has color:#444
content = content.replace('color:#444; margin-bottom:15px; font-weight:700;">Seus Dados</h4>', 'color:#F8FAFC; margin-bottom:15px; font-weight:700;">SEUS DADOS</h4>')

# Let's bump the version in index.html as well while we are at it.
with open('index.html', 'r', encoding='utf-8') as idx:
    idx_content = idx.read()
idx_content = idx_content.replace('70.3.88', '70.3.89')
with open('index.html', 'w', encoding='utf-8') as idx:
    idx.write(idx_content)

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Applied dark theme normalizations to recepcao_v2.html")
