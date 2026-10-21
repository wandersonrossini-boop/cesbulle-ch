import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Fix LATEST ENTRIES MODULE (Replace 3 divs with 2 divs)
target1 = '''                        </details>
                        </div> <!-- END pc-column-right -->
                    
                    </div> <!-- END pc-visitor-grid -->
                    
                    </div>
</div>
</div>'''
replace1 = '''                        </details>
                        </div> <!-- END pc-column-right -->
                    
                    </div> <!-- END pc-visitor-grid -->
                    
                </div> <!-- END card-floating -->
            </div> <!-- END mode-visitor -->'''
if target1 in content:
    content = content.replace(target1, replace1)
    print("Fixed target1")
else:
    print("Could not find target1")

# 2. Fix TAB SCHEDULE end (Replace 4 divs with 3 divs)
target2 = '''    </style>
                </div>
            </div>

        </div>
    </div>

    <script>'''
replace2 = '''    </style>
                </div> <!-- END card-floating -->
            </div> <!-- END sched-mode-member -->

        </div> <!-- END tab-schedule -->

    <script>'''
if target2 in content:
    content = content.replace(target2, replace2)
    print("Fixed target2")
else:
    print("Could not find target2")

# 3. Add closing tag for container before </main>
target3 = '''    <!-- External Logic - Loaded LAST -->
    

    </main></div>'''
replace3 = '''    <!-- External Logic - Loaded LAST -->
    
    </div> <!-- END container -->
    </main></div>'''
if target3 in content:
    content = content.replace(target3, replace3)
    print("Fixed target3")
else:
    print("Could not find target3")

# 4. Fix Eventos Margin
target4 = '<div id="tab-events" class="tab-section" style="display:none; height: 85vh;">'
replace4 = '<div id="tab-events" class="tab-section" style="display:none; height: 85vh; margin-top: -40px;">'
if target4 in content:
    content = content.replace(target4, replace4)
    print("Fixed target4")

# 5. Remove Servir Margin Hack
target5 = '''<div id="tab-services" class="tab-section" style="display:none;">

        <div style="text-align:center; margin-bottom:20px; margin-top:-220px;">'''
replace5 = '''<div id="tab-services" class="tab-section" style="display:none;">

        <div style="text-align:center; margin-bottom:20px;">'''
if target5 in content:
    content = content.replace(target5, replace5)
    print("Fixed target5")

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
