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
content = content.replace(target1, replace1)

# 2. Fix TAB SCHEDULE end
target2 = '''    </style>
                </div>
            </div>

        </div>
    </div>

    <script>
        window.db = window.db || (typeof firebase !== 'undefined' ? firebase.firestore() : null);'''

replace2 = '''    </style>
        </div> <!-- END sched-mode-member -->
    </div> <!-- END tab-schedule -->

    <script>
        window.db = window.db || (typeof firebase !== 'undefined' ? firebase.firestore() : null);'''
content = content.replace(target2, replace2)

# 3. Add closing tag for container before </main>
target3 = '''    </main></div>'''
replace3 = '''    </div> <!-- END container -->
    </main></div>'''
content = content.replace(target3, replace3)

with open('recepcao_v2.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fix applied!")
