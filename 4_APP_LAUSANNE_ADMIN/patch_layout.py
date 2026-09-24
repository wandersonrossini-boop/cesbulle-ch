import re

filepath = 'recepcao_v2.html'
with open(filepath, 'r', encoding='utf-8') as f:
    html = f.read()

# Fix switchCheckinMode overly greedy selector
html = html.replace("#tab-checkin .segment-btn", "#tab-checkin > .segmented-control .segment-btn")

# Reduce visual weight of the visitor toggle segment (NOVO/JÁ VISITOU)
# It's an inner segmented-control, let's add a specific style to it to make it thinner
inner_segment_regex = r'<div class="segmented-control "\s*style="margin-bottom:15px;">\s*<button class="segment-btn'
replacement = r'<div class="segmented-control" style="margin-bottom:15px; background: #f8fafc; border-radius: 4px; border: 1px solid #e2e8f0; height: auto;">\n                        <button class="segment-btn'
html = re.sub(inner_segment_regex, replacement, html)

# The user mentioned: "O dourado está sendo utilizado em excesso".
# Let's check btn-gold usage inside visitor-sub-new and visitor-sub-exist.
html = html.replace('btn-gold" style="width:100%; font-size:1.05rem; font-weight:700; padding:16px; margin-bottom:18px; border-radius:8px; display:flex; justify-content:space-between; align-items:center; background:#9e793e; color:#fff;"', 'btn-gold" style="width:100%; font-size:1rem; font-weight:600; padding:12px; margin-bottom:18px; border-radius:4px; display:flex; justify-content:space-between; align-items:center; background:#0f172a; color:#fff;"')
# Changed background to dark blue/black (identity) instead of gold!

# Also fix the "Enter?" button badge background
html = html.replace('background:rgba(255,255,255,0.15)', 'background:rgba(255,255,255,0.2)')

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(html)
print("Applied fixes")
