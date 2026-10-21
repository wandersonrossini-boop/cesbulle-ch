import re

with open('recepcao_v2.html', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Fix LATEST ENTRIES MODULE
target1 = '''                        </details>
                        </div> <!-- END pc-column-right -->
                    
                    </div> <!-- END pc-visitor-grid -->
                    
                    </div>
</div>
</div>'''
replace1 = '''                        </details>
                        </div> <!-- END pc-column-right -->
                    
                    </div> <!-- END pc-visitor-grid -->'''
if target1 in content:
    content = content.replace(target1, replace1)
    print("Fixed target1")
else:
    print("Could not find target1")

# 2. Fix TAB SCHEDULE end
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

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)
