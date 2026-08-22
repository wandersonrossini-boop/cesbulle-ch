// CES Diaconia - Main Application Controller (SPA)

const App = {
    // --- STATE MANAGEMENT ---
    currentUser: null,       // Logged in user object
    activeSectorId: null,    // Selected sector for member view (e.g., 'limpeza')
    memberActiveTab: 'escala', // Active tab in member portal ('escala', 'reposicao', 'avisos', 'perfil')
    memberPeriod: 'week',     // 'week' or 'month' view in member portal
    memberCurrentDate: new Date(), // Selected date for member scales view
    adminActiveTab: 'dashboard',  // Active tab in admin portal
    adminCurrentDate: new Date(),  // For admin scales filter
    adminSelectedCultoId: null,
    cultosData: [],
    openAccordions: {},
    showingMonthlyCalendar: false,
    
    // Static lists for Sectors and their Roles
    // Definição centralizada em js/config/sectorsData.js (Fase 4 - Etapa 2)
    sectorsData,

    // --- SETOR CONFIG HELPERS ---
    getSectorConfig(sectorId) {
        return this.sectorsData[sectorId] || null;
    },

    sectorHasCapability(sectorId, capability) {
        const config = this.getSectorConfig(sectorId);
        return config ? !!config[capability] : false;
    },

    getSectorMemberLabel(sectorId, plural = false) {
        const config = this.getSectorConfig(sectorId);
        if (!config) return plural ? 'Membros' : 'Membro';
        return plural ? config.labelMembroPlural : config.labelMembroSingular;
    },

    isOperationalSector(sectorId) {
        if (!sectorId) return false;
        // Fallback hardcoded para as coleções de produção que ainda não possuem o campo "categoria"
        if (sectorId === 'limpeza' || sectorId === 'manutencao' || sectorId === 'limpeza_manutencao' || sectorId === 'limpeza_conservacao' || sectorId === 'manutencao_predial' || sectorId === 'prestadores_servico' || sectorId === 'prestadores_de_servico' || sectorId === 'prestadores' || sectorId === 'prestador_servico' || sectorId === 'prestadores_servicos') {
            return true;
        }
        // Validação principal via campo "categoria" (futuro/novos setores operacionais)
        return this.sectorsData[sectorId]?.categoria === 'operacional';
    },

    getSectorFunctions(sectorId, cultoTipo = null, modeloEscala = null) {
        if (this.adminSelectedCultoId) {
            const c = this.cultosData.find(item => item.id === this.adminSelectedCultoId);
            if (c) {
                if (!cultoTipo) cultoTipo = c.tipo;
                if (!modeloEscala) modeloEscala = c.modeloEscala || 'Manter Existente';
            }
        }
        
        if (modeloEscala === 'Culto Menor') {
            // No Culto Menor, apenas Check-in e Acolhimento sao escalados
            if (sectorId === 'check_in' || sectorId === 'acolhimento') {
                const sector = this.sectorsData[sectorId];
                return sector ? sector.funcoes : [];
            }
            return [];
        }

        if (modeloEscala === 'Escala Livre') {
            if (sectorId === 'escala_livre') {
                return ["Escala Livre"];
            }
        }

        // Para os demais modelos, nao exibir o setor virtual escala_livre
        if (sectorId === 'escala_livre') {
            return [];
        }
        
        const sector = this.sectorsData[sectorId];
        return sector ? sector.funcoes : [];
    },

    isExclusiveContinuousMember(user) {
        if (!user) return false;
        
        let userSectors = [];
        if (Array.isArray(user.setores)) {
            userSectors = user.setores;
        } else if (user.setor) {
            userSectors = [user.setor];
        }
        
        if (userSectors.length === 0) return false;
        
        // Verifica se TODOS os setores válidos deste usuário são de operação contínua
        let hasAnySector = false;
        const isExclusive = userSectors.every(sId => {
            if (!sId) return true; // ignora vazios
            
            // Normalização para valores legados (ex: "Limpeza " -> "limpeza")
            let normalizedId = String(sId).trim().toLowerCase();
            normalizedId = normalizedId.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
            
            const config = this.sectorsData[normalizedId];
            if (!config) return false; // Se o setor não existe no dicionário, assumimos culto por segurança
            
            hasAnySector = true;
            return config.tipoOperacao === 'continua';
        });
        
        return hasAnySector && isExclusive;
    },

    adjustEscalaFormFields() {
        const sectorId = document.getElementById('escala-setor').value;
        const funcao = document.getElementById('escala-funcao').value;
        
        const dataInput = document.getElementById('escala-data');
        const horaInInput = document.getElementById('escala-horainicio');
        const horaFimInput = document.getElementById('escala-horafim');
        
        const c = this.cultosData.find(item => item.id === this.adminSelectedCultoId);
        const cultoTipo = c ? c.tipo : 'regular';
        
        let isOutsideCulto = false;
        isOutsideCulto = (funcao === 'Integração');
        
        if (c) {
            if (isOutsideCulto) {
                dataInput.disabled = false;
                horaInInput.disabled = false;
                horaFimInput.disabled = false;
            } else {
                dataInput.value = c.data;
                dataInput.disabled = true;
                horaInInput.value = c.horarioInicio;
                horaInInput.disabled = true;
                horaFimInput.value = c.horarioFim;
                horaFimInput.disabled = true;
            }
        } else {
            dataInput.disabled = false;
            horaInInput.disabled = false;
            horaFimInput.disabled = false;
        }
    },

    // --- INITIALIZATION ---

    /**
     * Aguarda o Firebase Auth estar estável (token propagado).
     * Resolve com o user autenticado anonimamente, garantindo que
     * qualquer operação Firestore posterior encontre request.auth != null.
     */
    waitForAuth() {
        return new Promise((resolve, reject) => {
            const unsubscribe = firebase.auth().onAuthStateChanged(async (user) => {
                unsubscribe(); // escuta apenas uma vez
                if (user) {
                    resolve(user);
                } else {
                    try {
                        console.log("[Auth] Iniciando sessão anônima...");
                        const result = await firebase.auth().signInAnonymously();
                        resolve(result.user);
                    } catch (err) {
                        console.warn("[Auth] Falha na sessão anônima:", err);
                        reject(err);
                    }
                }
            });
        });
    },

    async init() {
        console.log("Initializing App...");
        
        // Wait for Firebase database to run first verification/seeding
        if (typeof DbService !== 'undefined') {
            // Garantir que o token de auth está propagado ANTES de qualquer operação Firestore
            try {
                await this.waitForAuth();
                console.log("[Auth] Sessão anônima estável. Iniciando banco...");
            } catch (authErr) {
                console.warn("[Auth] Não foi possível garantir sessão anônima:", authErr);
            }

            // Executar semeação inicial
            try {
                await DbService.checkAndSeedDatabase();
            } catch (e) {
                console.error("Erro na semeação do banco de dados:", e);
            }
            
            // Ensure compatibility migration for legacy products
            try {
                const prodSnap = await db.collection('produtos').get();
                const promises = [];
                prodSnap.forEach(doc => {
                    const data = doc.data();
                    const updates = {};
                    let needsUpdate = false;
                    
                    if (!data.setorId) {
                        updates.setorId = 'limpeza';
                        needsUpdate = true;
                    }
                    if (data.quantidade === undefined) {
                        updates.quantidade = 10;
                        needsUpdate = true;
                    }
                    
                    if (needsUpdate) {
                        promises.push(db.collection('produtos').doc(doc.id).update(updates));
                    }
                });
                if (promises.length > 0) {
                    await Promise.all(promises);
                    console.log(`Migrated ${promises.length} legacy products to default sector/quantity.`);
                }
            } catch (e) {
                console.log("Could not run product migration:", e);
            }

            // Sincronizar novos setores no Firestore
            try {
                for (const [id, sec] of Object.entries(this.sectorsData)) {
                    await db.collection('setores').doc(id).set({
                        id: id,
                        nome: sec.nome,
                        funcoes: sec.funcoes,
                        cor: sec.cor
                    }, { merge: true });
                }
                console.log("Setores sincronizados com o Firestore com sucesso!");
            } catch (e) {
                console.log("Erro ao sincronizar setores no Firestore:", e);
            }

            // Reativar membros com afastamento expirado
            try {
                await this.checkAndReactivateReturnedMembers();
            } catch (e) {
                console.error("Erro ao reativar membros no início:", e);
            }
            // Checar e criar postagens automáticas do mural
            try {
                await this.checkAndCreateAutomatedPosts();
            } catch (e) {
                console.error("Erro ao verificar posts automáticos:", e);
            }
        } else {
            console.error("DbService not loaded!");
        }

        // Set date strings in Admin Top Bar
        this.updateDateIndicators();
        
        // Document click listener to close profile dropdown (v3.6.5)
        document.addEventListener('click', (e) => {
            const menu = document.getElementById('profile-dropdown-menu');
            if (menu && menu.style.display === 'block') {
                const profileArea = document.querySelector('.selector-header-pill');
                if (profileArea && !profileArea.contains(e.target)) {
                    menu.style.display = 'none';
                }
            }
        });
        
        // Setup autocomplete event listener for standard services (culto-nome)
        const cultoNomeInput = document.getElementById('culto-nome');
        if (cultoNomeInput) {
            cultoNomeInput.addEventListener('input', () => {
                const val = cultoNomeInput.value.trim();
                const templates = {
                    "Celebração das Primícias": { inicio: "10:00", fim: "12:30", tipo: "regular" },
                    "Celebração das Famílias": { inicio: "10:00", fim: "12:30", tipo: "regular" },
                    "Celebração da Ceia do Senhor": { inicio: "10:00", fim: "12:30", tipo: "regular" },
                    "Celebração Missionária": { inicio: "10:00", fim: "12:30", tipo: "regular" },
                    "Celebração do Fortalecimento": { inicio: "10:00", fim: "12:30", tipo: "regular" },
                    "Celebração do Natal": { inicio: "10:00", fim: "12:30", tipo: "regular" },
                    "Rede de Homens": { inicio: "17:00", fim: "19:30", tipo: "regular" },
                    "Rede de Mulheres": { inicio: "17:00", fim: "19:30", tipo: "regular" },
                    "Conexão / Batismos": { inicio: "17:00", fim: "19:30", tipo: "regular" },
                    "Conexão Rede de Jovens e Adolescentes": { inicio: "17:00", fim: "19:30", tipo: "regular" },
                    "Louvorzão com Grupo de Louvor": { inicio: "17:00", fim: "19:30", tipo: "regular" },
                    "Culto Alicerce": { inicio: "19:30", fim: "21:30", tipo: "regular" },
                    "Atualiza (Treinamento)": { inicio: "19:30", fim: "21:30", tipo: "regular" },
                    "Atualiza": { inicio: "19:30", fim: "21:30", tipo: "regular" },
                    "Conectadas (Mulheres)": { inicio: "19:30", fim: "21:30", tipo: "regular" },
                    "Conectadas": { inicio: "19:30", fim: "21:30", tipo: "regular" },
                    "Flamme (Jovens)": { inicio: "19:00", fim: "21:30", tipo: "regular" },
                    "Flamme": { inicio: "19:00", fim: "21:30", tipo: "regular" },
                    "Revisão (GD / Diretoria)": { inicio: "14:00", fim: "16:30", tipo: "especial" },
                    "Revisão": { inicio: "14:00", fim: "16:30", tipo: "especial" },
                    "Ministério de Intercessão em Ação": { inicio: "09:30", fim: "11:30", tipo: "regular" },
                    "Culto da Virada": { inicio: "21:30", fim: "00:30", tipo: "regular" }
                };
                
                if (templates[val]) {
                    document.getElementById('culto-horainicio').value = templates[val].inicio;
                    document.getElementById('culto-horafim').value = templates[val].fim;
                    document.getElementById('culto-tipo').value = templates[val].tipo;
                    this.updateCultoFormLabels();
                }
            });
        }
        
        // Check for saved login session
        await this.checkSession();
    },

    updateDateIndicators() {
        const options = { weekday: 'long', day: 'numeric', month: 'long' };
        const dateStr = new Date().toLocaleDateString('pt-BR', options);
        const el = document.getElementById('admin-date-indicator');
        if (el) el.innerText = dateStr.charAt(0).toUpperCase() + dateStr.slice(1);
    },

    async checkSession() {
        // Sempre mostra o login primeiro enquanto valida a sessão
        this.navigateTo('view-login');
        // Limpa os campos manualmente para evitar que o browser reinsira via autocomplete
        const emailField = document.getElementById('login-email');
        const passField  = document.getElementById('login-password');
        if (emailField) emailField.value = '';
        if (passField)  passField.value  = '';

        const localSession    = localStorage.getItem('diaconia_user_session');
        const sessionOnly     = sessionStorage.getItem('diaconia_user_session');
        const savedSession    = localSession || sessionOnly;

        if (!savedSession) return; // Tela de login já está ativa

        try {
            const sessionData = JSON.parse(savedSession);

            // Sessões do localStorage precisam ter _expiresAt (adicionado a partir desta versão).
            // Sessões antigas sem _expiresAt (ex: Adelino) são descartadas automaticamente.
            if (localSession) {
                if (!sessionData._expiresAt || Date.now() > sessionData._expiresAt) {
                    console.log('[Sessão] Expirada ou formato antigo. Exigindo novo login.');
                    localStorage.removeItem('diaconia_user_session');
                    return; // Login já visível
                }
            }

            // Valida se o usuário ainda está ativo no Firestore
            // Aguarda o Firebase Auth estar estável antes de ler o Firestore
            try {
                await this.waitForAuth();
                const userDoc = await db.collection('membros').doc(sessionData.id).get();
                if (!userDoc.exists || userDoc.data().status !== 'ativo') {
                    console.log('[Sessão] Usuário não encontrado ou inativo. Exigindo novo login.');
                    localStorage.removeItem('diaconia_user_session');
                    sessionStorage.removeItem('diaconia_user_session');
                    return;
                }
            } catch (netErr) {
                // Sem conexão — mantém sessão em cache para modo offline
                console.warn('[Sessão] Sem conexão. Usando sessão em cache.', netErr);
            }

            // Sessão válida — restaura e navega
            this.currentUser = sessionData;
            console.log('[Sessão] Restaurada:', this.currentUser.nome);
            this.onUserLoggedIn();

        } catch (e) {
            console.error('[Sessão] Erro ao restaurar:', e);
            localStorage.removeItem('diaconia_user_session');
            sessionStorage.removeItem('diaconia_user_session');
            // Login já visível
        }
    },

    // --- NAVIGATION ROUTER ---
    navigateTo(viewId) {
        console.log("DEBUG: navigateTo called with viewId:", viewId, "showingMonthlyCalendar:", this.showingMonthlyCalendar);
        
        // Validação rígida de segurança para o Painel Administrativo
        if (viewId === 'view-admin') {
            const isAdmin = this.currentUser && this.currentUser.perfil === 'admin';
            if (!isAdmin) {
                console.warn('[Segurança] Tentativa de acesso não autorizado à área de administração. Usuário:', this.currentUser ? this.currentUser.nome : 'Nulo');
                this.showToast('Acesso negado. Esta é uma área administrativa restrita.', 'danger');
                // Redireciona de volta com segurança
                setTimeout(() => this.navigateTo('view-setor-select'), 100);
                return;
            }
        }

        if (viewId !== 'view-member') {
            this.showingMonthlyCalendar = false;
            this.forceShowFullScales = false;
        }
        document.querySelectorAll('.view-section').forEach(section => {
            section.classList.remove('active');
        });
        
        const target = document.getElementById(viewId);
        if (target) {
            target.classList.add('active');
            
            // Toggle body class for side nav triggers visibility
            if (viewId === 'view-member' || viewId === 'view-setor-select') {
                document.body.classList.add('member-view-active');
            } else {
                document.body.classList.remove('member-view-active');
            }

            // Controle da visibilidade da barra de navegação global
            const mainNav = document.getElementById('main-bottom-nav');
            if (mainNav) {
                if (viewId === 'view-login' || viewId === 'view-member') {
                    mainNav.style.setProperty('display', 'none', 'important');
                } else {
                    mainNav.style.setProperty('display', 'flex', 'important');
                }
            }

            // Trigger specific view updates
            if (viewId === 'view-setor-select') {
                this.renderSectorSelectionScreen();
            } else if (viewId === 'view-member') {
                this.loadAndRenderMemberPortal();
            } else if (viewId === 'view-admin') {
                this.loadAndRenderAdminPortal();
            }
        }
    },
    navigateToNextService(escalaId, dataStr, cultoId, horarioInicio, setorId, funcao, observacoes) {

        // Build and select the event key so the organograma focuses on this specific culto
        const eventKey = `${dataStr}_${cultoId || 'sem-culto'}_${horarioInicio || '00:00'}`;
        this.memberSelectedEventKey = eventKey;
        
        // Update member date to match scale date
        const dateParts = dataStr.split('-');
        this.memberCurrentDate = new Date(dateParts[0], dateParts[1] - 1, dateParts[2]);

        // Map sector and function to area detail nodeId to automatically open the detail page
        let nodeId = null;
        if (setorId === 'escala_livre') {
            nodeId = 'escala_livre';
        } else if (setorId === 'acolhimento') {
            nodeId = 'acolhimento';
        } else if (setorId === 'entrada' || setorId === 'check_in') {
            nodeId = 'recepcao';
        } else if (setorId === 'apoio_templo_ronda_dir' || setorId === 'apoio_templo_ronda_esq') {
            const funcLower = (funcao || '').toLowerCase();
            if (funcLower.includes('ronda')) {
                nodeId = 'ronda';
            } else {
                nodeId = 'templo';
            }
        }

        if (setorId) {
            this.activeSectorId = setorId;
        }

        if (nodeId) {
            this.pendingOpenAreaDetailNodeId = nodeId;
        } else {
            this.pendingHighlightScaleId = escalaId;
        }

        this.navigateTo('view-member');
    },



    // --- AUTHENTICATION FLOWS ---
    async handleLogin(event) {
        console.log("[Auth-Diag] handleLogin disparado. Prevenindo submit padrão.");
        event.preventDefault();
        const nomeInput = document.getElementById('login-email').value;
        const password = document.getElementById('login-password').value;
        const remember = document.getElementById('login-remember').checked;
        const submitBtn = document.getElementById('btn-login-submit');

        console.log(`[Auth-Diag] Input capturado. Nome fornecido: "${nomeInput}"`);

        submitBtn.disabled = true;
        submitBtn.innerHTML = `<span>Entrando...</span> <i class="fa-solid fa-spinner fa-spin"></i>`;

        try {
            console.log("[Auth-Diag] Chamando DbService.authenticateUser antes da execução...");
            const res = await DbService.authenticateUser(nomeInput, password);
            console.log(`[Auth-Diag] Retorno de authenticateUser recebido. success: ${res.success}`);

            if (res.success) {
                this.currentUser = res.user;
                // Adiciona expiração de 30 dias para sessões "Lembrar-me"
                const expiresAt = Date.now() + (30 * 24 * 60 * 60 * 1000);
                const sessionData = { ...res.user, _expiresAt: expiresAt, _savedAt: Date.now() };
                const sessionStr = JSON.stringify(sessionData);

                if (remember) {
                    localStorage.setItem('diaconia_user_session', sessionStr);
                } else {
                    // sessionStorage expira naturalmente ao fechar a aba
                    sessionStorage.setItem('diaconia_user_session', JSON.stringify(res.user));
                }

                this.showToast(`Bem-vindo, ${res.user.nome}!`, 'success');
                this.onUserLoggedIn();
            } else {
                console.log(`[Auth-Diag] Falha estrutural no login. Erro: ${res.error}`);
                this.showAlert(res.error, 'Erro de Acesso');
            }
        } catch (e) {
            console.error(`[Auth-Diag] EXCEÇÃO GLOBAL em handleLogin! Code: ${e.code}, Message: ${e.message}`, e);
            this.showAlert("Erro inesperado durante a tentativa de login.", 'Erro de Acesso');
        }

        submitBtn.disabled = false;
        submitBtn.innerHTML = `<span>Entrar</span> <i class="fa-solid fa-right-to-bracket"></i>`;
    },

    onUserLoggedIn() {
        const isAdmin = this.currentUser && this.currentUser.perfil === 'admin';
        
        // Exibir ou ocultar botões administrativos com segurança no DOM
        const adminBtn = document.getElementById('btn-admin-panel');
        if (adminBtn) {
            adminBtn.style.setProperty('display', isAdmin ? 'flex' : 'none', 'important');
        }

        const userSectors = this.currentUser ? (Array.isArray(this.currentUser.setores) ? this.currentUser.setores : (this.currentUser.setor ? [this.currentUser.setor] : [])) : [];
        const hasOnlyOpSectors = userSectors.length > 0 && userSectors.every(s => this.isOperationalSector(s));

        // If user is Admin, they can access anything
        if (isAdmin) {
            document.getElementById('admin-shortcut-container').style.display = 'block';
            document.getElementById('admin-profile-name-footer').innerText = this.currentUser.nome;
            this.navigateTo('view-setor-select');
        } else {
            document.getElementById('admin-shortcut-container').style.display = 'none';
            this.navigateTo('view-setor-select');
        }

        // Construir barra inferior dinamicamente
        this.buildBottomNav();

        // ── Notificações Push ────────────────────────────────────
        this.setupNotifications();
    },

    // ── SISTEMA DE NOTIFICAÇÕES ──────────────────────────────────────

    buildBottomNav() {
        const isAdmin = this.currentUser && this.currentUser.perfil === 'admin';
        const isRepositor = this.currentUser && this.currentUser.eRepositor === true;
        
        const userSectors = this.currentUser ? (Array.isArray(this.currentUser.setores) ? this.currentUser.setores : (this.currentUser.setor ? [this.currentUser.setor] : [])) : [];
        const hasOnlyOpSectors = userSectors.length > 0 && userSectors.every(s => this.isOperationalSector(s));
        
        const btnPainel = document.getElementById('nav-btn-painel');
        const btnServicos = document.getElementById('nav-btn-servicos');
        const btnEscalas = document.getElementById('nav-btn-escalas');
        
        if (btnPainel) btnPainel.style.display = 'none';
        if (btnServicos) btnServicos.style.display = 'none';
        if (btnEscalas) btnEscalas.style.display = 'flex'; // Padrão visível

        if (isAdmin) {
            if (btnPainel) btnPainel.style.display = 'flex';
            if (btnEscalas) btnEscalas.style.display = 'none';
        }
        
        if (hasOnlyOpSectors && !isAdmin) {
            if (btnEscalas) btnEscalas.style.display = 'none';
        }
        
        if (isRepositor || isAdmin) {
            if (btnServicos) btnServicos.style.display = 'flex';
        }
    },

    toggleBottomNav(show) {
        const nav = document.getElementById('main-bottom-nav');
        if (nav) {
            if (show) {
                nav.classList.remove('bottom-nav-hidden');
            } else {
                nav.classList.add('bottom-nav-hidden');
            }
        }
    },

    _notificationInterval: null,   // Reference to the setInterval for reminders
    _swRegistration: null,          // Service Worker registration reference

    isIOS() {
        return /iPad|iPhone|iPod/.test(navigator.userAgent) && !window.MSStream;
    },

    showIOSNotificationInstructions() {
        const html = `
            <div style="text-align: center;">
                <div style="width: 60px; height: 60px; background: rgba(217,167,82,0.15); border: 1.5px solid rgba(217,167,82,0.3); border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 16px; font-size: 1.8rem; color: #D9A752;">
                    <i class="fa-brands fa-apple"></i>
                </div>
                <h4 style="margin-bottom: 12px; color: #ffffff;">Notificações no iPhone (iOS)</h4>
                <p style="color: #8AA6A3; font-size: 0.85rem; margin-bottom: 20px; line-height: 1.5; text-align: left;">
                    Para receber alertas de escala no iPhone (iOS), o sistema da Apple exige que o aplicativo seja adicionado à sua tela inicial:
                </p>
                <ol style="color: #8AA6A3; font-size: 0.85rem; margin-bottom: 20px; line-height: 1.6; text-align: left; padding-left: 20px;">
                    <li>Toque no botão de <strong>Compartilhar</strong> (ícone com seta para cima <i class="fa-solid fa-share-from-square"></i> no Safari).</li>
                    <li>Role para baixo e toque em <strong>"Adicionar à Tela de Início"</strong>.</li>
                    <li>Abra o aplicativo através do novo ícone na sua tela inicial e ative as notificações.</li>
                </ol>
                <button class="btn-primary" onclick="App.closeAlert()" style="width: 100%; height: 44px; border-radius: 12px; font-weight: 700; font-size: 0.88rem; background: var(--teal-primary);">
                    Entendi
                </button>
            </div>
        `;
        this.showAlert(html, 'Notificações no iPhone');
    },

    showBackgroundOptimizationGuide() {
        const modal = document.getElementById('modal-guia-bateria');
        if (modal) {
            modal.classList.add('active');
        }
    },

    testNotificationDirectly() {
        if (!('Notification' in window)) {
            if (this.isIOS()) {
                this.showIOSNotificationInstructions();
            } else {
                this.showToast('Navegador não suporta notificações.', 'danger');
            }
            return;
        }

        if (Notification.permission === 'denied') {
            this.showToast('Notificações bloqueadas! Ative nas configurações do aparelho.', 'danger');
            return;
        }

        if (Notification.permission === 'default') {
            this.requestNotificationPermission(true);
            return;
        }

        // If granted, show a test notification
        try {
            if (this._swRegistration) {
                // Try using service worker if active
                this._swRegistration.showNotification('🔔 Teste de Notificação', {
                    body: 'Parabéns! Suas notificações de escala estão configuradas corretamente.',
                    icon: '/assets/logo.png',
                    tag: 'ces-diaconia-test',
                    renotify: true
                });
            } else {
                // Fallback direct
                new Notification('🔔 Teste de Notificação', {
                    body: 'Parabéns! Suas notificações de escala estão configuradas corretamente.',
                    icon: '/assets/logo.png',
                    tag: 'ces-diaconia-test',
                    renotify: true
                });
            }
            this.showToast('Notificação de teste disparada!', 'success');
        } catch (e) {
            console.error("Error triggering test notification:", e);
            try {
                new Notification('🔔 Teste de Notificação', {
                    body: 'Parabéns! Suas notificações de escala estão configuradas corretamente.',
                    icon: '/assets/logo.png',
                    tag: 'ces-diaconia-test',
                    renotify: true
                });
                this.showToast('Notificação de teste disparada!', 'success');
            } catch (err) {
                this.showToast('Erro ao disparar notificação: ' + err.message, 'danger');
            }
        }
    },

    async setupNotifications() {
        if (!('serviceWorker' in navigator)) {
            console.log('[Notificações] Navegador não suporta Service Workers.');
            return;
        }

        // Register Service Worker
        try {
            this._swRegistration = await navigator.serviceWorker.register('/sw-notifications.js?v=3.11.2-PWA', { scope: '/' });
            console.log('[Notificações] Service Worker registrado:', this._swRegistration.scope);
        } catch (err) {
            console.warn('[Notificações] Falha ao registrar Service Worker:', err);
        }

        // Listen for messages from Service Worker (notification click actions)
        navigator.serviceWorker.addEventListener('message', event => {
            const data = event.data;
            if (!data || data.type !== 'NOTIFICATION_ACTION') return;
            this.handleNotificationAction(data.action, data.scaleId);
        });

        // Also handle URL params (when app is opened from a closed state via notification click)
        this.handleNotificationUrlParams();

        // Request permission and start reminder loop
        await this.requestNotificationPermission();
    },

    async requestNotificationPermission() {
        const hasNotificationSupport = 'Notification' in window;
        const isIOSDevice = this.isIOS();

        if (!hasNotificationSupport) {
            if (isIOSDevice) {
                // Show iOS instructions if they requested to trigger it
                this.showIOSNotificationInstructions();
            } else {
                console.log('[Notificações] Navegador não suporta a API Notification.');
            }
            return;
        }

        if (Notification.permission === 'denied') {
            console.log('[Notificações] Permissão negada pelo usuário.');
            return;
        }

        if (Notification.permission !== 'granted') {
            // Show a friendly in-app prompt before asking the browser
            const userWantsNotifications = await new Promise(resolve => {
                const html = `
                    <div style="text-align: center;">
                        <div style="width: 60px; height: 60px; background: rgba(18,115,105,0.15); border: 1.5px solid rgba(18,115,105,0.3); border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 16px; font-size: 1.8rem; color: var(--teal-primary);">
                            <i class="fa-solid fa-bell"></i>
                        </div>
                        <p style="color: #8AA6A3; font-size: 0.85rem; margin-bottom: 20px; line-height: 1.5;">
                            Receba alertas diários de escalas pendentes e lembretes um dia antes dos cultos em que você está confirmado.
                        </p>
                        <div style="display: flex; gap: 10px;">
                            <button class="btn-primary" onclick="App._resolveNotifPrompt(true)" style="flex:1; height: 44px; border-radius: 12px; font-weight: 700; font-size: 0.88rem;">
                                <i class="fa-solid fa-bell"></i> Ativar Notificações
                            </button>
                            <button class="btn-secondary" onclick="App._resolveNotifPrompt(false)" style="width: 80px; height: 44px; border-radius: 12px; border: 1px solid rgba(255,255,255,0.1); background: transparent; color: #8AA6A3; font-size: 0.85rem;">
                                Agora não
                            </button>
                        </div>
                    </div>
                `;
                this._notifPromptResolve = resolve;
                this.showAlert(html, 'Notificações de Escala');
            });

            if (!userWantsNotifications) return;

            const permission = await Notification.requestPermission();
            if (permission !== 'granted') {
                this.showToast('Notificações bloqueadas. Ative nas configurações do navegador.', 'warning');
                return;
            }
        }

        // Permission granted — init FCM
        this.showToast('🔔 Notificações ativadas!', 'success');
        this.initializeFCM();
    },

    _resolveNotifPrompt(value) {
        this.closeAlert();
        if (this._notifPromptResolve) {
            this._notifPromptResolve(value);
            this._notifPromptResolve = null;
        }
    },

    async initializeFCM() {
        try {
            const messaging = firebase.messaging();
            
            // Request token
            const currentToken = await messaging.getToken({
                vapidKey: 'BMeN5X-yiVCJSxpM44Q1IApiVZh21LBHJdKxLKNJptKwE0evVyySa-pN9xpMyleYnTYpuYJmKXd8wG67o8QXZbQ',
                serviceWorkerRegistration: this._swRegistration
            });

            if (currentToken) {
                console.log('[FCM] Token gerado:', currentToken);
                await this.saveTokenToFirestore(currentToken);
            } else {
                console.warn('[FCM] Nenhum token gerado.');
            }

            // Foreground listener
            messaging.onMessage((payload) => {
                console.log('[FCM] Mensagem em foreground:', payload);
                const notificationTitle = payload.notification?.title || 'Aviso';
                const notificationOptions = {
                    body: payload.notification?.body,
                    icon: '/assets/logo.png',
                    data: payload.data
                };
                const notif = new Notification(notificationTitle, notificationOptions);
                notif.onclick = () => {
                    window.focus();
                    notif.close();
                    if(payload.data && payload.data.scaleId) {
                         this.handleNotificationAction('view', payload.data.scaleId);
                    } else {
                         this.activeSectorId = 'entrada';
                         this.navigateTo('view-member');
                    }
                };
            });

            // Handle token refresh
            messaging.onTokenRefresh(async () => {
                try {
                    const refreshedToken = await messaging.getToken({ vapidKey: 'BMeN5X-yiVCJSxpM44Q1IApiVZh21LBHJdKxLKNJptKwE0evVyySa-pN9xpMyleYnTYpuYJmKXd8wG67o8QXZbQ' });
                    console.log('[FCM] Token atualizado:', refreshedToken);
                    await this.saveTokenToFirestore(refreshedToken);
                } catch (err) {
                    console.error('[FCM] Erro ao atualizar token:', err);
                }
            });

        } catch (error) {
            console.error('[FCM] Erro ao inicializar Messaging:', error);
        }
    },

    async saveTokenToFirestore(token) {
        if (!this.currentUser || !token) return;

        const tokenKey = `fcm_token_atual_${this.currentUser.id}`;
        const savedToken = localStorage.getItem(tokenKey);
        
        if (savedToken === token) {
            return;
        }

        try {
            const memberRef = window.db.collection('membros').doc(this.currentUser.id);
            await memberRef.set({
                fcmTokens: firebase.firestore.FieldValue.arrayUnion(token)
            }, { merge: true });
            
            localStorage.setItem(tokenKey, token);
            console.log('[FCM] Token salvo no membro:', this.currentUser.id);
        } catch (error) {
            console.error('[FCM] Erro ao salvar token no Firestore:', error);
        }
    },

    async removeTokenFromFirestore() {
        if (!this.currentUser) return;
        
        const tokenKey = `fcm_token_atual_${this.currentUser.id}`;
        const token = localStorage.getItem(tokenKey);
        
        if (!token) return;
        
        try {
            const memberRef = window.db.collection('membros').doc(this.currentUser.id);
            await memberRef.update({
                fcmTokens: firebase.firestore.FieldValue.arrayRemove(token)
            });
            localStorage.removeItem(tokenKey);
            console.log('[FCM] Token desvinculado do membro.');
        } catch (error) {
            console.error('[FCM] Erro ao desvincular token:', error);
        }
    },

    async handleNotificationAction(action, scaleId) {
        if (!scaleId) {
            this.activeSectorId = 'entrada';
            this.navigateTo('view-member');
            return;
        }
        if (action === 'confirm') {
            await this.handleConfirmPresenca(scaleId, 'Confirmada');
            this.showToast('✅ Presença confirmada!', 'success');
        } else if (action === 'refuse') {
            await this.handleConfirmPresenca(scaleId, 'Recusada');
            this.showToast('Recusa registrada.', 'info');
        } else if (action === 'view') {
            this.activeSectorId = 'entrada';
            this.navigateTo('view-member');
        }
    },

    handleNotificationUrlParams() {
        const params = new URLSearchParams(window.location.search);
        const action = params.get('action');
        const scaleId = params.get('scaleId');
        if (action && scaleId) {
            window.history.replaceState({}, document.title, '/');
            setTimeout(() => this.handleNotificationAction(action, scaleId), 1500);
        }
    },

    async handleLogout() {
        // Remove FCM token before logging out
        await this.removeTokenFromFirestore();
        
        this.currentUser = null;
        this.activeSectorId = null;
        localStorage.removeItem('diaconia_user_session');
        sessionStorage.removeItem('diaconia_user_session');

        // Reset forms e limpa campos explicitamente
        document.getElementById('login-form').reset();
        const emailField = document.getElementById('login-email');
        const passField  = document.getElementById('login-password');
        if (emailField) emailField.value = '';
        if (passField)  passField.value  = '';

        this.navigateTo('view-login');
        this.showToast('Você saiu do sistema.', 'info');
    },

    // --- VIEW 2: SECTOR SELECTION SCREEN ---
    async renderSectorSelectionScreen() {
        this.markMuralAsRead();
        this.markMuralAsRead();
        

        // Populate user initials and welcome name
        if (this.currentUser) {
            const names = this.currentUser.nome.split(' ');
            const initials = names[0].charAt(0) + (names.length > 1 ? names[names.length - 1].charAt(0) : '');
            
            const selAvatar = document.getElementById('selector-profile-avatar');
            if (selAvatar) {
                const directUrl = this.getDirectPhotoUrl(this.currentUser.fotoUrl);
                if (directUrl) {
                    selAvatar.innerHTML = `<img src="${directUrl}" style="width: 100%; height: 100%; border-radius: 50%; object-fit: cover;">`;
                    selAvatar.innerText = '';
                } else {
                    selAvatar.innerText = initials.toUpperCase();
                }
            }
            
            const welcomeAvatar = document.getElementById('welcome-avatar-initials');
            if (welcomeAvatar) welcomeAvatar.innerText = initials.toUpperCase();
            
            const selName = document.getElementById('selector-profile-name');
            if (selName) {
                selName.innerText = names.length > 1 ? `${names[0]} ${names[names.length - 1]}` : names[0];
            }
            
            const welcomeUserName = document.getElementById('welcome-user-name');
            if (welcomeUserName) welcomeUserName.innerText = names[0];
            
            // Set role display
            const selRole = document.getElementById('selector-profile-role');
            if (selRole) {
                const roleText = this.currentUser.perfil === 'admin' ? 'Administrador' : 'Membro';
                selRole.innerHTML = `${roleText} <i class="fa-solid fa-chevron-down" style="font-size: 0.65rem; margin-left: 2px;"></i>`;
            }
        }

        try {
            // Fetch necessary data in parallel (fetching only selected month's scales)
            const dateRange = this.getStartAndEndDates(this.memberCurrentDate, 'month');
            const [escalas, avisos] = await Promise.all([
                DbService.getEscalas(null, dateRange.start, dateRange.end),
                DbService.getAvisos()
            ]);

            // Update badge counts
            this.updateAvisosBadgesCount(avisos);
            
            // Load and Render the Mural Informativo on Sector Select screen
            this.loadAndRenderSectorSelectMural(escalas, avisos);
            
            // Calculate Next Service
            const now = new Date();
            const ano = now.getFullYear();
            const mes = String(now.getMonth() + 1).padStart(2, '0');
            const dia = String(now.getDate()).padStart(2, '0');
            const hojeStr = `${ano}-${mes}-${dia}`;
            
            const amanha = new Date(now.getTime() + 24 * 60 * 60 * 1000);
            const amanhaStr = `${amanha.getFullYear()}-${String(amanha.getMonth() + 1).padStart(2, '0')}-${String(amanha.getDate()).padStart(2, '0')}`;

            let userScales = [];
            if (this.currentUser) {
                userScales = escalas.filter(e => e.membroId === this.currentUser.id);
                
                const missaoContainer = document.getElementById('missao-primaria-container');
                if (this.currentUser.perfil === 'admin') {
                    if (missaoContainer) missaoContainer.style.display = 'none';
                } else {
                    if (missaoContainer) missaoContainer.style.display = 'block';
                }
            }

            // Next service today or in the future (não finalizado e não recusado)
            const futureScales = userScales.filter(e => e.data >= hojeStr && e.statusServico !== 'Finalizado' && e.statusPresenca !== 'Recusada');
            // Sort chronologically
            futureScales.sort((a, b) => a.data.localeCompare(b.data) || a.horarioInicio.localeCompare(b.horarioInicio));

            // Dynamic Welcome Greeting (v3.10.4B Refined)
            if (this.currentUser) {
                const welcomeGreetingEl = document.getElementById('selector-welcome-greeting');
                const welcomeNameEl = document.getElementById('selector-welcome-name');
                if (welcomeNameEl) {
                    welcomeNameEl.innerHTML = `Olá, ${this.currentUser.nome}`.trim();
                }
                if (welcomeGreetingEl) {
                    welcomeGreetingEl.style.setProperty('display', 'none', 'important');
                }
            }

            // Render Premium Next Service Card
            const premiumNextContainer = document.getElementById('premium-next-scale-container');
            if (premiumNextContainer) {
                if (futureScales.length > 0) {
                    const next = futureScales[0];
                    const parts = next.data.split('-');
                    const y = parseInt(parts[0], 10);
                    const mIdx = parseInt(parts[1], 10) - 1;
                    const dNum = parseInt(parts[2], 10);
                    const dateObj = new Date(y, mIdx, dNum);
                    const monthAbbrev = dateObj.toLocaleDateString('pt-BR', { month: 'short' }).replace('.', '').toUpperCase();
                    const dayNames = ['Domingo','Segunda','Terça','Quarta','Quinta','Sexta','Sábado'];
                    const weekday = dayNames[dateObj.getDay()];

                    const sectorName = this.sectorsData[next.setorId] ? this.sectorsData[next.setorId].nome : next.setorId;
                    const isOp = this.isOperationalSector(next.setorId);
                    
                    const titleEl = document.getElementById('missao-primaria-title');
                    if (titleEl) {
                        titleEl.textContent = isOp ? 'Próximo Expediente' : 'Missão Primária';
                    }

                    const status = next.statusPresenca || "Pendente";
                    
                    let badgeClass = "pending";
                    let statusText = "Pendente";
                    
                    if (status === "Confirmada") {
                        badgeClass = "confirmed";
                        statusText = "Confirmada";
                    } else if (status === "Recusada") {
                        badgeClass = "pending";
                        statusText = "Recusada";
                    }

                    let btnConfirmHtml = '';
                    if (status !== 'Confirmada') {
                        btnConfirmHtml = `
                            <button class="btn-confirm-huge" style="height: 40px !important; font-size: 0.85rem; border-radius: 10px;" onclick="event.stopPropagation(); App.confirmarPresencaDireto('${next.id}', '${next.data}')">
                                <i class="fa-solid fa-circle-check"></i> CONFIRMAR PRESENÇA
                            </button>
                        `;
                    }

                    const eventTitle = isOp ? (next.funcao || 'Plantão') : (next.cultoNome || 'Culto');
                    const funcLabel = isOp ? 'Atividade' : 'Função';

                    let instructionsHtml = '';
                    if (!isOp) {
                        let nodeId = null;
                        const funcLower = (next.funcao || '').toLowerCase();
                        const obsLower = (next.observacoes || '').toLowerCase();
                        if (next.setorId === 'escala_livre' || funcLower.includes('escala livre')) nodeId = 'escala_livre';
                        else if (next.setorId === 'acolhimento' || funcLower.includes('acolhimento')) nodeId = 'acolhimento';
                        else if (next.setorId === 'entrada' || next.setorId === 'check_in' || funcLower.includes('entrada') || funcLower.includes('portaria')) {
                            if (funcLower.includes('check')) nodeId = 'checkin';
                            else nodeId = 'portaria';
                        } else if (next.setorId === 'apoio_templo_ronda_dir' || next.setorId === 'apoio_templo_ronda_esq' || funcLower.includes('apoio')) {
                            const isDir = funcLower.includes('direito') || obsLower.includes('direito') || funcLower.includes('dir');
                            if (funcLower.includes('ronda')) {
                                nodeId = isDir ? 'ronda-direito' : 'ronda-esquerdo';
                            } else {
                                nodeId = isDir ? 'apoio-direito' : 'apoio-esquerdo';
                            }
                        }
                        
                        const staticData = this.areaStaticData[nodeId];
                        if (staticData && staticData.instrucoes) {
                            instructionsHtml = `
                                <div style="margin-top: 12px; padding-top: 12px; border-top: 1px solid rgba(255,255,255,0.1);">
                                    <div style="font-size: 0.75rem; font-weight: 700; color: #6EE7B7; text-transform: uppercase; margin-bottom: 4px; display: flex; align-items: center; gap: 6px;">
                                        <i class="fa-solid fa-circle-info"></i> O que fazer:
                                    </div>
                                    <div style="font-size: 0.85rem; color: #E2E8F0; line-height: 1.4;">
                                        ${staticData.instrucoes}
                                    </div>
                                </div>
                            `;
                        }
                    }

                    premiumNextContainer.innerHTML = `
                        <div class="premium-next-scale-card" onclick="App.navigateToNextService('${next.id}', '${next.data}', '${next.cultoId || 'sem-culto'}', '${next.horarioInicio || '00:00'}', '${next.setorId}', '${(next.funcao || '').replace(/'/g, '\\\'')}');" style="display: flex; flex-direction: column; gap: 8px; padding: 18px 20px; border-radius: 16px; box-shadow: 0 8px 24px rgba(18,115,105,0.25); border: 1px solid rgba(255,255,255,0.15);">
                            <!-- Linha Superior -->
                            <div style="display: flex; justify-content: space-between; align-items: center; width: 100%; margin-bottom: 4px;">
                                <span style="font-size: 0.75rem; color: #E2E8F0; font-weight: 600; display: flex; align-items: center; gap: 6px; text-transform: uppercase; letter-spacing: 0.5px;">
                                    <i class="fa-solid fa-map-marker-alt" style="color: #6EE7B7;"></i> Templo Central
                                </span>
                                <span class="scale-status-badge ${badgeClass}" style="margin: 0; padding: 4px 8px; font-size: 0.7rem; font-weight: 800; text-transform: uppercase; letter-spacing: 0.5px;">${statusText}</span>
                            </div>
                            
                            <!-- Corpo -->
                            <div class="scale-info-row" style="display: flex; align-items: center; gap: 16px; margin-top: 4px;">
                                <!-- Bloco Data Compacto -->
                                <div class="scale-date-badge" style="display: flex; flex-direction: column; align-items: center; justify-content: center; border-radius: 10px; padding: 8px 10px; min-width: 54px; background: rgba(0,0,0,0.25); border: 1px solid rgba(255,255,255,0.1);">
                                    <div class="day" style="font-size: 1.4rem; font-weight: 800; color: #FFFFFF; line-height: 1;">${String(dNum).padStart(2, '0')}</div>
                                    <div class="month" style="font-size: 0.65rem; color: #A7F3D0; font-weight: 700; margin-top: 2px; text-transform: uppercase; letter-spacing: 1px;">${monthAbbrev}</div>
                                </div>
                                
                                <!-- Detalhes da Escala -->
                                <div class="scale-details" style="flex: 1; min-width: 0; text-align: left;">
                                    <h4 style="margin: 0; font-size: 1.15rem; font-weight: 800; color: #FFFFFF; line-height: 1.2; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${eventTitle}</h4>
                                    <p style="margin: 4px 0 0 0; font-size: 0.85rem; color: #A7F3D0; font-weight: 500; display: flex; align-items: center; gap: 6px;"><i class="fa-regular fa-clock"></i> ${next.horarioInicio || '00:00'}</p>
                                    <p style="margin: 6px 0 0 0; font-size: 0.85rem; color: #F8FAFC; line-height: 1.3;">
                                        <span style="font-weight: 500; color: #94A3B8; font-size: 0.75rem; text-transform: uppercase;">${funcLabel}</span><br>
                                        <span style="font-weight: 700; color: #FFFFFF; font-size: 0.95rem;">${isOp ? sectorName : next.funcao}</span> <span style="opacity: 0.7; font-size: 0.8rem;">(${isOp ? next.funcao : sectorName})</span>
                                    </p>
                                </div>
                            </div>
                            
                            ${instructionsHtml}
                            
                            ${btnConfirmHtml ? `<div style="margin-top: 10px;">${btnConfirmHtml}</div>` : ''}
                        </div>
                    `;
                } else {
                    premiumNextContainer.innerHTML = `
                        <div class="premium-next-scale-card" onclick="App.handleMobileNavClick('escala')" style="align-items: center; text-align: center; justify-content: center; padding: 24px; cursor: pointer; border-radius: 16px;">
                            <i class="fa-regular fa-calendar-check" style="font-size: 2rem; opacity: 0.6; margin-bottom: 12px; color: white;"></i>
                            <h4 style="margin: 0; color: white; font-weight: 800; font-size: 1.1rem;">Nenhuma Missão Pendente</h4>
                            <p style="opacity: 0.8; margin: 6px 0 0 0; font-size: 0.85rem; color: #E2E8F0;">Você está com tudo em dia. Toque para ver a escala geral.</p>
                        </div>
                    `;
                }
            }

            // Update pending scales bell badge count and Quick Stats
            let pendingCount = 0;
            let confirmedCount = 0;
            let eventTodayName = "Nenhum";
            if (this.currentUser) {
                const userFuture = futureScales.filter(e => e.membroId === this.currentUser.id);
                pendingCount = userFuture.filter(e => e.statusPresenca === 'Pendente').length;
                confirmedCount = userFuture.filter(e => e.statusPresenca === 'Confirmada').length;
                const todayScale = userFuture.find(e => e.data === hojeStr);
                if (todayScale) eventTodayName = todayScale.cultoNome || "Atividade";
            }
            
            // Remover Indicadores da Home
            const compactStatusBar = document.getElementById('compact-status-bar');
            if (compactStatusBar) {
                compactStatusBar.style.display = 'none';
            }

            const scalesBadge = document.getElementById('btn-scales-badge');
            if (scalesBadge) {
                if (pendingCount > 0) {
                    scalesBadge.style.display = 'block';
                } else {
                    scalesBadge.style.display = 'none';
                }
            }

            // Build events list for the premium date selector banner
            const eventsMap = {};
            escalas.forEach(escala => {
                const dateStr = escala.data;
                const timeStr = escala.horarioInicio || "00:00";
                const cultoId = escala.cultoId || "sem-culto";
                const eventKey = `${dateStr}_${cultoId}_${timeStr}`;

                if (!eventsMap[eventKey]) {
                    eventsMap[eventKey] = {
                        key: eventKey,
                        data: dateStr,
                        cultoId: escala.cultoId || null,
                        cultoNome: escala.cultoNome || (escala.cultoId ? "Culto" : "Escala Diária"),
                        horarioInicio: escala.horarioInicio || "00:00",
                        horarioFim: escala.horarioFim || "00:00",
                        escalas: []
                    };
                }
                eventsMap[eventKey].escalas.push(escala);
            });

            const eventsList = Object.values(eventsMap);
            eventsList.sort((a, b) => {
                if (a.data !== b.data) return a.data.localeCompare(b.data);
                return a.horarioInicio.localeCompare(b.horarioInicio);
            });

            // Cache the sorted events list
            this.memberDiaconiaEventsList = eventsList;

            let activeEventKey = this.memberSelectedEventKey;
            if (eventsList.length > 0) {
                const upcomingEvents = eventsList.filter(e => e.data >= hojeStr);
                if (upcomingEvents.length > 0) {
                    if (!activeEventKey || !upcomingEvents.some(e => e.key === activeEventKey)) {
                        activeEventKey = upcomingEvents[0].key;
                        this.memberSelectedEventKey = activeEventKey;
                    }
                } else {
                    if (!activeEventKey || !eventsMap[activeEventKey]) {
                        activeEventKey = eventsList[eventsList.length - 1].key;
                        this.memberSelectedEventKey = activeEventKey;
                    }
                }
            } else {
                this.memberSelectedEventKey = null;
            }

            const evtActive = activeEventKey ? eventsMap[activeEventKey] : null;

            // Formatar datas para o banner
            let bannerLabel = "";
            if (evtActive) {
                const dateParts = evtActive.data.split('-');
                const d = new Date(dateParts[0], dateParts[1] - 1, dateParts[2]);
                const diaSemanaShort = d.toLocaleDateString('pt-BR', { weekday: 'short' }).replace('.', '').toUpperCase();
                const dataFmt = `${dateParts[2]}/${dateParts[1]}`;
                bannerLabel = `${diaSemanaShort}, ${dateParts[2]}/${dateParts[1]} • ${evtActive.cultoNome}`;
            } else {
                const monthName = this.memberCurrentDate.toLocaleDateString('pt-BR', { month: 'long', year: 'numeric' });
                bannerLabel = `${monthName.toUpperCase()}`;
            }

            // Custom Selector Banner with Prev/Next Navigation and Calendar Button
            let selectorBannerHtml = `
                <div class="org-selector-banner-premium">
                    <button class="org-nav-arrow" onclick="App.navigateOrgEvent(-1)">
                        <i class="fa-solid fa-chevron-left"></i>
                    </button>
                    <div class="org-banner-center" onclick="App.openMonthlyCalendar()">
                        <i class="fa-regular fa-calendar-days" style="color: #127369;"></i>
                        <div class="org-banner-date-info">
                            <span class="org-banner-date-title">${bannerLabel}</span>
                            <span class="org-banner-calendar-btn-label">Calendário do Mês</span>
                        </div>
                    </div>
                    <button class="org-nav-arrow" onclick="App.navigateOrgEvent(1)">
                        <i class="fa-solid fa-chevron-right"></i>
                    </button>
                </div>
            `;

            const dateBannerContainer = document.getElementById('selector-date-banner-container');
            if (dateBannerContainer) {
                dateBannerContainer.innerHTML = selectorBannerHtml;
            }

            // Check if calendar view is scheduled to be shown after reload
            if (this.showCalendarAfterLoading) {
                this.showCalendarAfterLoading = false;
                this.showMonthlyCalendar();
                return;
            }

            // --- ALERTAS GERENCIAIS (Apenas Admin / Repositor) ---
            let alertasHtml = '';
            if (this.currentUser) {
                const isAdminAlerts = this.currentUser.perfil === 'admin';
                const isRepositorAlerts = this.currentUser.eRepositor === true;

                if (isAdminAlerts) {
                    // Contabilizar funções sem voluntário ou recusadas (somente futuras ou de hoje)
                    const funcoesVagas = escalas.filter(e => e.data >= hojeStr && e.statusServico !== 'Finalizado' && (!e.membroId || e.statusPresenca === 'Recusada')).length;
                    
                    if (funcoesVagas > 0) {
                        alertasHtml += `
                            <div class="premium-next-scale-card" onclick="document.getElementById('nav-btn-painel').click()" style="align-items: center; justify-content: space-between; padding: 12px; cursor: pointer; flex-direction: row; border-left: 4px solid #F59E0B;">
                                <div style="display: flex; align-items: center; gap: 12px;">
                                    <div style="background: rgba(245,158,11,0.15); width: 36px; height: 36px; border-radius: 8px; display: flex; align-items: center; justify-content: center;">
                                        <i class="fa-solid fa-clipboard-user" style="font-size: 1.1rem; color: #F59E0B;"></i>
                                    </div>
                                    <div style="text-align: left;">
                                        <h4 style="margin: 0; color: white; font-weight: 700; font-size: 0.85rem;">Escalas Incompletas</h4>
                                        <p style="opacity: 0.8; margin: 2px 0 0 0; font-size: 0.75rem; color: #8AA6A3;">${funcoesVagas} funç${funcoesVagas !== 1 ? 'ões' : 'ão'} precisando de atenção.</p>
                                    </div>
                                </div>
                                <i class="fa-solid fa-chevron-right" style="color: #8AA6A3; font-size: 0.8rem;"></i>
                            </div>
                        `;
                    }
                }

                if (isRepositorAlerts) {
                    // Prepara o container para reposição utilizando um dado em memória, se existir no futuro (sem consultar DB)
                    // Por ora, se app.js implementasse this.cachedReposicoes, pegaria.
                    const reposicoesPendentes = this.cachedReposicoes ? this.cachedReposicoes.filter(r => r.status === 'Pendente').length : 0;
                    if (reposicoesPendentes > 0) {
                        alertasHtml += `
                            <div class="premium-next-scale-card" onclick="document.getElementById('nav-btn-servicos').click()" style="align-items: center; justify-content: space-between; padding: 12px; cursor: pointer; flex-direction: row; border-left: 4px solid #F59E0B;">
                                <div style="display: flex; align-items: center; gap: 12px;">
                                    <div style="background: rgba(245,158,11,0.15); width: 36px; height: 36px; border-radius: 8px; display: flex; align-items: center; justify-content: center;">
                                        <i class="fa-solid fa-box-open" style="font-size: 1.1rem; color: #F59E0B;"></i>
                                    </div>
                                    <div style="text-align: left;">
                                        <h4 style="margin: 0; color: white; font-weight: 700; font-size: 0.85rem;">Estoque e Reposição</h4>
                                        <p style="opacity: 0.8; margin: 2px 0 0 0; font-size: 0.75rem; color: #8AA6A3;">${reposicoesPendentes} item${reposicoesPendentes !== 1 ? 'ns' : ''} aguardando compra.</p>
                                    </div>
                                </div>
                                <i class="fa-solid fa-chevron-right" style="color: #8AA6A3; font-size: 0.8rem;"></i>
                            </div>
                        `;
                    }
                }
            }

            const alertasContainer = document.getElementById('alertas-gerenciais-container');
            const alertasList = document.getElementById('alertas-gerenciais-list');
            if (alertasContainer && alertasList) {
                if (alertasHtml !== '') {
                    alertasList.innerHTML = alertasHtml;
                    alertasContainer.style.display = 'block';
                } else {
                    alertasContainer.style.display = 'none';
                }
            }
            // A renderização dos atalhos de Setores Operacionais foi desativada.
        } catch (e) {
            console.error("Error rendering sector selection screen:", e);
        }
    },

    toggleProfileDropdown(event) {
        if (event) event.stopPropagation();
        const menu = document.getElementById('profile-dropdown-menu');
        if (menu) {
            const isVisible = menu.style.display === 'block';
            menu.style.display = isVisible ? 'none' : 'block';
        }
    },

    handleMobileNavClick(tabName) {
        if (!this.currentUser) return;

        // Avisos abre o sidebar do mural, não o view-member
        if (tabName === 'avisos') {
            this.toggleMuralMobile(true);
            return;
        }
        
        const targetSector = this.activeSectorId || this.currentUser.setor || (Array.isArray(this.currentUser.setores) && this.currentUser.setores[0]) || 'entrada';
        this.activeSectorId = targetSector;
        
        this.navigateTo('view-member');
        this.switchMemberTab(tabName);
    },

    openMobileAnnouncements() {
        this.handleMobileNavClick('avisos');
    },

    toggleMobileMenu() {
        if (confirm("Deseja sair da sua conta?")) {
            this.handleLogout();
        }
    },

    toggleMuralMobile(show) {
        const sidebar = document.getElementById('selector-mural-sidebar');
        const backdrop = document.getElementById('mural-backdrop');
        if (sidebar) {
            if (show) {
                sidebar.classList.add('open');
            } else {
                sidebar.classList.remove('open');
            }
        }
        if (backdrop) {
            if (show) {
                backdrop.classList.add('active');
            } else {
                backdrop.classList.remove('active');
            }
        }

        // When opening the mural, mark notices as read
        if (show) {
            this.markMuralAsRead();
        }
    },

    async markMuralAsRead() {
        try {
            const avisos = await DbService.getAvisos();
            const currentIds = avisos.map(a => a.id);
            localStorage.setItem('diaconia_read_avisos', JSON.stringify(currentIds));
            
            // Refresh badges immediately
            this.updateAvisosBadgesCount(avisos);
        } catch (e) {
            console.error("Error marking mural notices as read:", e);
        }
    },

    async loadAndRenderMemberMural() {
        const container = document.getElementById('member-mural-container');
        const list = document.getElementById('member-mural-list');
        if (!container || !list) return;

        try {
            let avisos = await DbService.getAvisos();
            // Filter out legacy "Escala" and "Culto" announcements from the mural
            avisos = avisos.filter(a => !a.titulo.toLowerCase().includes('escala') && !a.titulo.toLowerCase().includes('culto'));
            
            if (avisos.length === 0) {
                container.style.display = 'none';
                return;
            }

            container.style.display = 'block';
            list.innerHTML = '';

            const readAvisosStr = localStorage.getItem('diaconia_read_mural_avisos');
            const readIds = readAvisosStr ? JSON.parse(readAvisosStr) : [];
            let hasNew = false;

            avisos.forEach(a => {
                const isNew = !readIds.includes(a.id);
                if (isNew) hasNew = true;

                const dt = a.data ? a.data.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit', year: 'numeric' }) : '';
                const item = document.createElement('div');
                item.style.cssText = `
                    background: rgba(255, 255, 255, 0.02);
                    border: 1px solid rgba(138, 166, 163, 0.1);
                    border-radius: 10px;
                    padding: 10px 12px;
                    font-size: 0.85rem;
                    color: #fff;
                    display: flex;
                    flex-direction: column;
                    gap: 4px;
                    position: relative;
                `;
                
                item.innerHTML = `
                    <div style="display: flex; justify-content: space-between; align-items: center; font-size: 0.72rem; color: #8AA6A3;">
                        <span style="font-weight: 700; color: var(--theme-color);"><i class="fa-solid fa-user-tie"></i> ${a.autorNome || 'Supervisor Geral'}</span>
                        <div style="display: flex; align-items: center; gap: 6px;">
                            ${isNew ? '<span style="background: #ef4444; color: #fff; font-size: 0.6rem; padding: 1px 4px; border-radius: 4px; font-weight: 800; text-transform: uppercase;">Novo</span>' : ''}
                            <span>${dt}</span>
                        </div>
                    </div>
                    <div style="font-weight: 700; color: #fff; margin-top: 2px;">${a.titulo}</div>
                    <div style="color: #BFBFBF; font-size: 0.8rem; line-height: 1.3;">${a.conteudo}</div>
                `;
                list.appendChild(item);
            });

            // Mark all as read after display so they won't show "Novo" next time
            const allIds = avisos.map(a => a.id);
            localStorage.setItem('diaconia_read_mural_avisos', JSON.stringify(allIds));

            const badge = document.getElementById('member-mural-badge');
            if (badge) {
                badge.style.display = hasNew ? 'inline-block' : 'none';
            }
        } catch (err) {
            console.error("Error loading member mural:", err);
            container.style.display = 'none';
        }
    },

    async loadAndRenderMemberAvisos() {
        const container = document.getElementById('member-notices-list');
        if (!container) return;
        container.innerHTML = '<div style="text-align: center; padding: 30px;"><i class="fa-solid fa-circle-notch fa-spin" style="font-size: 1.5rem; color: var(--theme-color);"></i><p style="margin-top:10px;">Buscando avisos...</p></div>';
        
        try {
            let noticesHtml = '';
            
            // 1. Fetch personal notifications
            if (this.currentUser) {
                const notificacoes = await DbService.getNotificacoesUsuario(this.currentUser.id);
                
                // Mark notifications as read since user is viewing them
                if (notificacoes.some(n => !n.lida)) {
                    await DbService.marcarNotificacoesComoLidas(this.currentUser.id);
                }

                if (notificacoes.length > 0) {
                    notificacoes.forEach(n => {
                        const dt = n.data ? n.data.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' }) : '';
                        const unreadStyle = !n.lida 
                            ? 'border-left: 4px solid var(--theme-color); background: #FFFBEB;' 
                            : 'border-left: 4px solid var(--slate-gray); background: #FAF5FF;';
                        
                        noticesHtml += `
                            <div class="notice-item" style="${unreadStyle} margin-bottom: 15px; box-shadow: 0 1px 3px rgba(0,0,0,0.05); padding: 15px; border-radius: 8px;">
                                <div class="notice-meta" style="display:flex; justify-content:space-between; margin-bottom:5px; font-size:0.75rem; color:var(--slate-gray);">
                                    <span style="font-weight:700; color:var(--theme-color);"><i class="fa-solid fa-bell"></i> Notificação Pessoal</span>
                                    <span>${dt}</span>
                                </div>
                                <p style="font-size: 0.9rem; color: var(--navy-dark); font-weight: 500; margin: 0;">${n.mensagem}</p>
                            </div>
                        `;
                    });
                }
            }

            // 2. Fetch global notices
            const avisos = await DbService.getAvisos();
            if (avisos.length === 0 && noticesHtml === '') {
                container.innerHTML = '<p style="text-align: center; color: var(--slate-gray); font-size: 0.9rem; padding: 20px;">Nenhum aviso ou notificação.</p>';
                return;
            }
            
            container.innerHTML = noticesHtml;
            
            avisos.forEach(a => {
                const item = document.createElement('div');
                item.className = 'notice-item';
                
                const dt = a.data ? a.data.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit', year: 'numeric' }) : '';
                
                item.innerHTML = `
                    <div class="notice-meta">
                        <span>${a.autorNome || 'Supervisor Geral'}</span>
                        <span>${dt}</span>
                    </div>
                    <h4 style="font-weight: 700; margin-bottom: 5px; color:var(--navy-dark);">${a.titulo}</h4>
                    <p style="font-size: 0.9rem; color: var(--navy-dark);">${a.conteudo}</p>
                `;
                container.appendChild(item);
            });
            
            // Mark all as read since the user is viewing them
            const currentIds = avisos.map(a => a.id);
            localStorage.setItem('diaconia_read_avisos', JSON.stringify(currentIds));
            
            // Refresh badges
            this.updateAvisosBadgesCount(avisos);
        } catch (e) {
            console.error("Error loading member notices:", e);
            container.innerHTML = '<p style="color: red; text-align: center; padding: 20px;">Erro ao carregar avisos.</p>';
        }
    },

    async updateAvisosBadgesCount(cachedAvisos = null) {
        try {
            const avisos = cachedAvisos || await DbService.getAvisos();
            const readAvisosStr = localStorage.getItem('diaconia_read_avisos');
            const readIds = readAvisosStr ? JSON.parse(readAvisosStr) : [];
            let unreadCount = avisos.filter(a => !readIds.includes(a.id)).length;
            
            // Add unread personal notifications count
            if (this.currentUser) {
                const notificationsSnap = await db.collection('notificacoes')
                    .where('paraUsuarioId', '==', this.currentUser.id)
                    .where('lida', '==', false)
                    .get();
                unreadCount += notificationsSnap.size;
            }
            
            const summaryBadge = document.getElementById('summary-unread-badge');
            const mobileBadge = document.getElementById('mobile-bell-badge');
            const selectorNavBadge = document.getElementById('selector-nav-avisos-badge');
            const navAvisosBadge = document.getElementById('nav-avisos-badge');
            const muralMobileBadge = document.getElementById('mural-mobile-badge');
            
            const unreadTextEl = document.getElementById('summary-unread-text');
            const unreadSubEl = document.getElementById('summary-unread-sub');
            
            if (unreadCount > 0) {
                if (summaryBadge) {
                    summaryBadge.style.display = 'flex';
                    summaryBadge.innerText = unreadCount;
                }
                if (mobileBadge) {
                    mobileBadge.style.display = 'flex';
                    mobileBadge.innerText = unreadCount;
                }
                if (selectorNavBadge) {
                    selectorNavBadge.style.display = 'flex';
                    selectorNavBadge.innerText = unreadCount;
                }
                if (navAvisosBadge) {
                    navAvisosBadge.style.display = 'flex';
                    navAvisosBadge.innerText = unreadCount;
                }
                if (muralMobileBadge) {
                    muralMobileBadge.style.display = 'flex';
                    muralMobileBadge.innerText = unreadCount;
                }
                
                if (unreadTextEl) {
                    unreadTextEl.innerText = `Você tem ${unreadCount} aviso${unreadCount > 1 ? 's' : ''}`;
                }
                if (unreadSubEl) {
                    unreadSubEl.innerText = `não lido${unreadCount > 1 ? 's' : ''}`;
                }
            } else {
                if (summaryBadge) summaryBadge.style.display = 'none';
                if (mobileBadge) mobileBadge.style.display = 'none';
                if (selectorNavBadge) selectorNavBadge.style.display = 'none';
                if (navAvisosBadge) navAvisosBadge.style.display = 'none';
                if (muralMobileBadge) muralMobileBadge.style.display = 'none';
                
                if (unreadTextEl) {
                    unreadTextEl.innerText = 'Sem avisos';
                }
                if (unreadSubEl) {
                    unreadSubEl.innerText = 'Tudo atualizado';
                }
            }
        } catch (e) {
            console.error("Error updating notices count:", e);
        }
    },

    // ==========================================================================
    // VIEW 3: MEMBER PORTAL
    // ==========================================================================
    loadAndRenderMemberPortal() {
        
        if (!this.activeSectorId && this.currentUser) {
            const targetSector = this.currentUser.setor || (Array.isArray(this.currentUser.setores) && this.currentUser.setores[0]);
            if (targetSector) {
                this.activeSectorId = targetSector;
                console.log("DEBUG: Auto-recovered activeSectorId:", this.activeSectorId);
            }
        }

        const sector = this.sectorsData[this.activeSectorId];
        if (!sector) {
            console.warn("DEBUG: loadAndRenderMemberPortal aborted - sector not found for:", this.activeSectorId);
            return;
        }

        // Apply dynamic sector theme
        const appContainer = document.getElementById('member-app-container');
        appContainer.className = "member-app-shell " + sector.themeClass;
        
        document.getElementById('member-sector-title').innerText = sector.nome;
        
        // --- Configurar Bottom Nav Dinâmica e Cabeçalho ---
        // Desativado temporariamente para que Limpeza use a Escala padrão e tenha botão de Voltar
        const isOp = false;
        
        // Ensure back button is always visible
        const backBtn = document.querySelector('.member-header-info .btn-icon');
        if (backBtn) {
            backBtn.style.display = 'flex';
        }

        const subtitleEl = document.querySelector('.member-header-subtitle');
        if (subtitleEl) {
            subtitleEl.innerText = 'Minha Escala';
        }
        
        document.querySelectorAll('.bottom-nav-item.tab-op').forEach(el => {
            el.style.display = 'none';
        });
        document.querySelectorAll('.bottom-nav-item.tab-non-op').forEach(el => {
            el.style.display = 'flex';
        });

        const reposicaoTab = document.getElementById('bottom-nav-reposicao');
        if (reposicaoTab) {
            const isComprador = this.currentUser && (this.currentUser.eRepositor === true || this.currentUser.perfil === 'admin');
            reposicaoTab.style.display = isComprador ? 'flex' : 'none';
        }
        // ---------------------------------------------

        // Init initials for profile
        const names = this.currentUser.nome.split(' ');
        const initials = names[0].charAt(0) + (names.length > 1 ? names[names.length - 1].charAt(0) : '');
        document.getElementById('member-profile-initials').innerText = initials.toUpperCase();
        document.getElementById('member-profile-name').innerText = this.currentUser.nome;
        document.getElementById('member-profile-email').innerText = this.currentUser.email;
        document.getElementById('member-profile-role').innerText = `Membro da equipe - ${sector.nome}`;

        // Switch to the default Tab
        this.switchMemberTab(isOp ? 'hoje' : 'escala');
    },

    switchMemberTab(tabName, el = null) {
        this.memberActiveTab = tabName;
        
        // Set nav item active
        if (el) {
            document.querySelectorAll('.bottom-nav-item').forEach(item => item.classList.remove('active'));
            el.classList.add('active');
        } else {
            // Find manually
            document.querySelectorAll('.bottom-nav-item').forEach(item => {
                item.classList.remove('active');
                if ((tabName === 'escala' || tabName === 'hoje') && (item.innerHTML.includes('Minha Escala') || item.innerHTML.includes('Escala') || item.innerHTML.includes('Hoje'))) item.classList.add('active');
                if (tabName === 'tarefas' && item.innerHTML.includes('Tarefas')) item.classList.add('active');
                if ((tabName === 'reposicao' || tabName === 'estoque') && (item.innerHTML.includes('Reposição') || item.innerHTML.includes('Serviços') || item.innerHTML.includes('Estoque'))) item.classList.add('active');
                if (tabName === 'avisos' && item.innerHTML.includes('Avisos')) item.classList.add('active');
                if (tabName === 'perfil' && item.innerHTML.includes('Perfil')) item.classList.add('active');
            });
        }

        // Hide all subviews, show selected
        document.querySelectorAll('.member-subview').forEach(view => view.style.display = 'none');
        
        let targetSubId = tabName;
        if (tabName === 'hoje') targetSubId = 'escala';
        if (tabName === 'estoque') targetSubId = 'reposicao';
        
        const subEl = document.getElementById(`member-sub-${targetSubId}`);
        if (subEl) subEl.style.display = 'block';
        else if (tabName === 'avisos') { this.toggleMuralMobile(true); return; }

        // Load tab data
        if (tabName === 'escala' || tabName === 'hoje') {
            if (this.isOperationalSector(this.activeSectorId)) {
                this.renderOperacionalDashboard();
            } else {
                this.loadAndRenderMemberScales();
            }
        } else if (tabName === 'tarefas') {
            this.loadAndRenderMemberTarefas();
        } else if (tabName === 'reposicao' || tabName === 'estoque') {
            this.loadAndRenderMemberReplenish();
        } else if (tabName === 'avisos') {
            this.loadAndRenderMemberAvisos();
        } else if (tabName === 'perfil') {
            this.loadMemberProfileStats();
        }
    },

    switchMemberPeriod(period, el) {
        this.memberPeriod = period;
        document.querySelectorAll('.segment-item').forEach(item => item.classList.remove('active'));
        el.classList.add('active');
        this.loadAndRenderMemberScales();
    },

    async loadAndRenderMemberTarefas() {
        const container = document.getElementById('member-tarefas-list');
        if (!container) return;
        
        container.innerHTML = `<div style="text-align: center; padding: 20px;"><i class="fa-solid fa-circle-notch fa-spin" style="font-size: 1.5rem; color: var(--theme-color);"></i></div>`;
        
        try {
            const tarefas = await DbService.getTarefas(this.activeSectorId);
            
            let html = '';
            if (tarefas.length === 0) {
                html = `<div style="text-align: center; padding: 30px; color: #8AA6A3;"><i class="fa-solid fa-check-double" style="font-size: 2rem; margin-bottom: 10px; opacity: 0.5;"></i><br>Nenhuma tarefa pendente.</div>`;
            } else {
                html = tarefas.map(t => {
                    let badgeColor = t.prioridade === 'Alta' ? '#EF4444' : (t.prioridade === 'Média' ? '#F59E0B' : '#10B981');
                    let statusColor = t.status === 'Pendente' ? '#6B7280' : (t.status === 'Em andamento' ? '#3B82F6' : (t.status === 'Concluída' ? '#10B981' : '#EF4444'));
                    let statusIcon = t.status === 'Concluída' ? 'fa-check' : 'fa-circle';
                    
                    return `
                        <div style="background: rgba(255,255,255,0.02); border: 1px solid rgba(255,255,255,0.1); border-radius: 12px; padding: 15px;">
                            <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 10px;">
                                <div style="font-weight: 700; color: #fff; font-size: 0.95rem;">${t.titulo}</div>
                                <span style="font-size: 0.7rem; background: ${badgeColor}; color: white; padding: 3px 6px; border-radius: 4px; font-weight: 600;">${t.prioridade}</span>
                            </div>
                            <div style="font-size: 0.85rem; color: #BFBFBF; margin-bottom: 15px; display: flex; flex-direction: column; gap: 4px;">
                                <span><i class="fa-solid fa-location-dot" style="width: 16px;"></i> ${t.local}</span>
                                <span><i class="fa-regular fa-calendar" style="width: 16px;"></i> Prazo: ${t.prazo}</span>
                                <span><i class="fa-solid fa-user-tag" style="width: 16px;"></i> Resp: ${t.responsavel || 'Todos'}</span>
                            </div>
                            <div style="display: flex; justify-content: space-between; align-items: center;">
                                <span style="font-size: 0.75rem; color: ${statusColor}; font-weight: 600;"><i class="fa-solid ${statusIcon}" style="font-size: 0.5rem; vertical-align: middle;"></i> ${t.status}</span>
                                ${t.status !== 'Concluída' ? `<button class="btn-primary" style="background: var(--teal-primary); border: none; font-size: 0.8rem; padding: 6px 12px; border-radius: 6px;" onclick="App.openAtualizarTarefaModal('${t.id}', '${t.status}')">Atualizar</button>` : ''}
                            </div>
                        </div>
                    `;
                }).join('');
            }
            container.innerHTML = html;
        } catch (e) {
            console.error("Error rendering tarefas:", e);
            container.innerHTML = `<div style="color: #ef4444; padding: 20px; text-align: center;">Erro ao carregar as tarefas.</div>`;
        }
    },

    async loadAndRenderMemberScales() {
        const container = document.getElementById('member-scales-list');
        container.innerHTML = `<div style="text-align: center; padding: 30px;"><i class="fa-solid fa-circle-notch fa-spin" style="font-size: 1.5rem; color: var(--theme-color);"></i><p style="margin-top: 10px; font-size: 0.9rem;">Buscando escalas...</p></div>`;

        // Hide segment control and slider since we are showing full month list (v3.6.5 - evite barra rotativa)
        const segmentBar = document.querySelector('.segment-bar');
        const dateSlider = document.querySelector('.date-slider');
        if (segmentBar) segmentBar.style.display = 'none';
        if (dateSlider) dateSlider.style.display = 'none';

        // Always query the full month for all sectors to avoid sliders (v3.6.5)
        let periodToUse = 'month';
        const dateRange = this.getStartAndEndDates(this.memberCurrentDate, periodToUse);
        
        const dateRangeEl = document.getElementById('member-date-range');
        if (dateRangeEl) {
            dateRangeEl.innerText = dateRange.label;
        }

        try {
            const isDiaconiaOrAcolhimento = ['entrada', 'check_in', 'apoio_templo_ronda_dir', 'apoio_templo_ronda_esq', 'acolhimento', 'escala_livre'].includes(this.activeSectorId);
            const sectorToFetch = null;
            const escalas = await DbService.getEscalas(sectorToFetch, dateRange.start, dateRange.end);

            console.log('activeSectorId', this.activeSectorId);
            console.log('currentUser', this.currentUser?.nome);
            console.log('escalasEncontradas', escalas);

            // Smart check for non-scheduled members (v3.6.22)
            const userSectorEscalas = escalas.filter(e => e.membroId === this.currentUser.id && e.statusPresenca !== 'Recusada');
            
            // Modo Imersivo: Persistência do Plantão
            const hasActiveService = userSectorEscalas.some(e => e.statusServico === 'Em andamento');
            this.toggleBottomNav(!hasActiveService);

            if (userSectorEscalas.length === 0 && !this.forceShowFullScales && this.currentUser.perfil !== 'admin') {
                console.log('userSectorEscalas', 'Vazio (0 escalas)');
                this.renderNoScalesActionCards(container);
                return;
            }
            
            let nextService = null;
            const hojeStr = this.formatLocalISOString(new Date()).split('T')[0];

            if (isDiaconiaOrAcolhimento) {
                await this.renderDiaconiaOrganograma(escalas, container);
                
                // Detect next service for highlight
                escalas.forEach(escala => {
                    const isOwnScale = escala.membroId === this.currentUser.id;
                    if (isOwnScale && escala.data >= hojeStr && escala.statusServico !== 'Finalizado' && escala.statusPresenca !== 'Recusada') {
                        if (!nextService || escala.data < nextService.data) {
                            nextService = escala;
                        }
                    }
                });

                // Check if calendar view is scheduled to be shown after reload
                if (this.showCalendarAfterLoading) {
                    this.showCalendarAfterLoading = false;
                    this.showMonthlyCalendar();
                }
            } else {
                container.innerHTML = '';
                if (escalas.length === 0) {
                    const emptyCard = document.createElement('div');
                    emptyCard.style.cssText = 'text-align: center; padding: 30px var(--white); background: rgba(255,255,255,0.02); border: 1px solid rgba(255,255,255,0.06); border-radius: 16px; margin-bottom: 20px;';
                    emptyCard.innerHTML = `<i class="fa-solid fa-calendar-xmark" style="font-size: 2rem; color: #8AA6A3; opacity: 0.5;"></i><p style="margin-top: 10px; color: #8AA6A3; font-size: 0.9rem;">Você não está escalado para este período.</p>`;
                    container.appendChild(emptyCard);
                } else {
                    escalas.forEach(escala => {
                        const card = document.createElement('div');
                        card.className = 'card-scale';
                        
                        // Formatar data pt-BR
                        const dateParts = escala.data.split('-');
                        const d = new Date(dateParts[0], dateParts[1] - 1, dateParts[2]);
                        const diaFormatado = d.toLocaleDateString('pt-BR', { weekday: 'short', day: '2-digit', month: '2-digit' });
                        
                        // Determinar badge do status da presença
                        let statusBadge = '';
                        if (escala.statusPresenca === 'Pendente') {
                            statusBadge = `<span class="card-scale-status status-pendente">Pendente</span>`;
                        } else if (escala.statusPresenca === 'Confirmada') {
                            statusBadge = `<span class="card-scale-status status-confirmado">Confirmado</span>`;
                        } else if (escala.statusPresenca === 'Recusada') {
                            statusBadge = `<span class="card-scale-status status-recusado">Recusado</span>`;
                        }

                        // Determinar badge do status do serviço
                        let servicoBadge = '';
                        if (escala.statusServico === 'Em andamento') {
                            servicoBadge = `<span class="card-scale-status status-andamento" style="margin-left: 5px;">Em andamento</span>`;
                        } else if (escala.statusServico === 'Finalizado') {
                            servicoBadge = `<span class="card-scale-status status-finalizado" style="margin-left: 5px;">Finalizado</span>`;
                        }

                        // Identificar se a escala é do próprio usuário logado
                        const isOwnScale = escala.membroId === this.currentUser.id;
                        
                        if (isOwnScale) {
                            card.classList.add('user-own-scale-card');
                        }

                        // Renderizar botões de aceitar ou recusar presença
                        let actionButtonsHtml = '';
                        if (isOwnScale && escala.statusPresenca === 'Pendente') {
                            const isOp = this.isOperationalSector(this.activeSectorId);
                            const confirmText = isOp ? "Aceitar Escala" : "Confirmar Presença";
                            actionButtonsHtml = `
                                <div class="card-scale-actions">
                                    <button class="btn-scale-action btn-recusar-presenca" onclick="App.handleConfirmPresenca('${escala.id}', 'Recusada')">
                                        <i class="fa-solid fa-xmark"></i> Recusar
                                    </button>
                                    <button class="btn-scale-action btn-confirm-presenca" onclick="App.handleConfirmPresenca('${escala.id}', 'Confirmada')">
                                        <i class="fa-solid fa-check"></i> ${confirmText}
                                    </button>
                                </div>
                            `;
                        }

                        // Renderizar botões de serviço (Iniciar/Parar) para todos os setores
                        let serviceControlHtml = '';
                        if (isOwnScale && escala.statusPresenca === 'Confirmada') {
                            if (escala.statusServico === 'Agendado') {
                                serviceControlHtml = `
                                    <button class="btn-service-control btn-start-work" onclick="App.handleStartService('${escala.id}', '${escala.funcao}', '${escala.data}', '${escala.horarioInicio}', '${escala.horarioFim}')">
                                        <i class="fa-solid fa-play"></i> Iniciar Trabalho
                                    </button>
                                `;
                            } else if (escala.statusServico === 'Em andamento') {
                                serviceControlHtml = `
                                    <button class="btn-service-control btn-finish-work" onclick="App.handleFinishServiceModal('${escala.id}')">
                                        <i class="fa-solid fa-circle-stop"></i> Finalizar Trabalho
                                    </button>
                                `;
                            }
                        }

                        card.innerHTML = `
                            <div class="card-scale-header">
                                <span class="card-scale-date-badge">${diaFormatado.toUpperCase()}</span>
                                <div>
                                    ${statusBadge}
                                    ${servicoBadge}
                                </div>
                            </div>
                            <div class="card-scale-time">
                                <i class="fa-regular fa-clock"></i>
                                <span>${escala.horarioInicio} - ${escala.horarioFim}</span>
                            </div>
                            <div class="card-scale-role">${escala.funcao}</div>
                            <div class="card-scale-member">
                                <i class="fa-solid fa-user-circle"></i>
                                <span>${escala.membroNome} ${isOwnScale ? '<span class="own-scale-user-tag"><i class="fa-solid fa-circle-check"></i> Você</span>' : ''}</span>
                            </div>
                            ${escala.observacoes ? `<div class="card-scale-notes"><b>Instruções:</b> ${escala.observacoes}</div>` : ''}
                            ${actionButtonsHtml}
                            ${serviceControlHtml}
                        `;
                        
                        container.appendChild(card);

                        // Detect next service for highlight
                        if (isOwnScale && escala.data >= hojeStr && escala.statusServico !== 'Finalizado' && escala.statusPresenca !== 'Recusada') {
                            if (!nextService || escala.data < nextService.data) {
                                nextService = escala;
                            }
                        }
                    });
                }

                // --- SEÇÃO DE VOLUNTARIADO (v3.2) ---
                try {
                    // Buscar todos os cultos no período
                    const cultos = await DbService.getCultos(dateRange.start, dateRange.end);
                    
                    // Buscar todas as escalas do período
                    const allEscalas = await DbService.getEscalas(null, dateRange.start, dateRange.end);
                    
                    // Identificar cultos onde o usuário já está escalado
                    const userScaledCultoIds = new Set(
                        allEscalas.filter(e => e.membroId === this.currentUser.id && e.statusPresenca !== 'Recusada').map(e => e.cultoId)
                    );
                    
                    // Filtrar cultos onde o usuário NÃO está escalado
                    const availableCultos = cultos.filter(c => !userScaledCultoIds.has(c.id));
                    
                    // Buscar candidaturas de voluntários atuais
                    const standbys = await DbService.getStandbys();
                    const myStandbys = standbys.filter(s => s.membroId === this.currentUser.id);
                    
                    const volHeader = document.createElement('div');
                    volHeader.className = 'panel-title';
                    volHeader.style.cssText = 'margin-top: 30px; margin-bottom: 15px; color: #fff; font-size: 0.95rem; text-transform: uppercase; letter-spacing: 0.5px; text-align: left;';
                    volHeader.innerHTML = `<i class="fa-solid fa-hand-holding-hand" style="margin-right: 6px; color: var(--theme-color);"></i> Voluntariado e Backup`;
                    container.appendChild(volHeader);
                    
                    if (availableCultos.length === 0) {
                        const emptyVol = document.createElement('div');
                        emptyVol.style.cssText = 'text-align: center; padding: 20px; background: rgba(255,255,255,0.02); border: 1px dashed rgba(255,255,255,0.08); border-radius: 12px; color: #8AA6A3; font-size: 0.82rem;';
                        emptyVol.innerText = 'Nenhum outro culto disponível para voluntariado neste período.';
                        container.appendChild(emptyVol);
                    } else {
                        availableCultos.forEach(c => {
                            const card = document.createElement('div');
                            card.className = 'card-scale';
                            card.style.cssText = 'border: 1px dashed rgba(18, 115, 105, 0.35); background: rgba(18, 115, 105, 0.03);';
                            
                            const dateParts = c.data.split('-');
                            const d = new Date(dateParts[0], dateParts[1] - 1, dateParts[2]);
                            const diaFormatado = d.toLocaleDateString('pt-BR', { weekday: 'short', day: '2-digit', month: '2-digit' });
                            
                            const standbyDoc = myStandbys.find(s => s.cultoId === c.id);
                            const hasVolunteered = !!standbyDoc;
                            
                            const statusBadge = hasVolunteered
                                ? `<span class="card-scale-status status-confirmado" style="background: rgba(16, 185, 129, 0.15); color: #10b981; border: 1px solid rgba(16, 185, 129, 0.3);">Candidatura Enviada</span>`
                                : `<span class="card-scale-status status-pendente" style="background: rgba(138, 166, 163, 0.1); color: #8AA6A3; border: 1px solid rgba(138, 166, 163, 0.2);">Disponível</span>`;
                                
                            card.innerHTML = `
                                <div class="card-scale-header">
                                    <span class="card-scale-date-badge">${diaFormatado.toUpperCase()}</span>
                                    ${statusBadge}
                                </div>
                                <div class="card-scale-time">
                                    <i class="fa-regular fa-clock"></i>
                                    <span>${c.horarioInicio} - ${c.horarioFim}</span>
                                </div>
                                <div class="card-scale-role">${c.nome}</div>
                                <div style="margin-top: 12px; text-align: left;">
                                    ${hasVolunteered ? `
                                        <button class="btn-secondary" onclick="App.handleCancelStandbyFromList('${standbyDoc.id}')" style="width: 100%; height: 36px; border-radius: 10px; border: 1px solid rgba(239, 68, 68, 0.2); background: rgba(239, 68, 68, 0.05); color: #ef4444; font-size: 0.78rem; font-weight: 600; cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 6px;">
                                            <i class="fa-solid fa-trash-can"></i> Cancelar Disponibilidade
                                        </button>
                                    ` : `
                                        <button class="btn-primary" onclick="App.handleRegisterStandbyFromList('${c.id}', '${c.nome.replace(/'/g, "\\'")}', '${c.data}', '${c.horarioInicio} - ${c.horarioFim}')" style="width: 100%; height: 36px; border-radius: 10px; background: var(--theme-color); color: #fff; font-size: 0.78rem; font-weight: 700; border: none; cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 6px; text-transform: uppercase; letter-spacing: 0.3px;">
                                            <i class="fa-solid fa-hand-holding-hand"></i> Quero ser Voluntário
                                        </button>
                                    `}
                                </div>
                            `;
                            container.appendChild(card);
                        });
                    }
                } catch (eVol) {
                    console.error("Error loading volunteering options:", eVol);
                }
            }

            // Next service highlight rendering
            const highlightContainer = document.getElementById('next-service-highlight');
            const nextInfoContainer = document.getElementById('next-service-info');
            
            console.log('nextService', nextService);

            if (nextService) {
                highlightContainer.style.display = 'block';
                const dateParts = nextService.data.split('-');
                const d = new Date(dateParts[0], dateParts[1] - 1, dateParts[2]);
                const dayName = d.toLocaleDateString('pt-BR', { weekday: 'long' });
                const dayFmt = d.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit' });

                let actionBtn = '';
                if (nextService.statusPresenca === 'Confirmada') {
                    if (nextService.statusServico === 'Agendado') {
                        actionBtn = `<span style="display:inline-block; font-size:0.8rem; padding: 4px 8px; background: rgba(56, 190, 201, 0.15); color: var(--theme-color); font-weight:700; border-radius:5px; margin-top:5px;">SERVIÇO CONFIRMADO</span>`;
                    } else if (nextService.statusServico === 'Em andamento') {
                        actionBtn = `<span style="display:inline-block; font-size:0.8rem; padding: 4px 8px; background: #DBEAFE; color: #2563EB; font-weight:700; border-radius:5px; margin-top:5px;">SERVIÇO EM EXECUÇÃO</span>`;
                    }
                } else {
                    actionBtn = `<span style="display:inline-block; font-size:0.8rem; padding: 4px 8px; background: #FEF3C7; color: #D97706; font-weight:700; border-radius:5px; margin-top:5px;">CONFIRMAÇÃO PENDENTE</span>`;
                }

                nextInfoContainer.innerHTML = `
                    <div style="font-weight: 700; font-size: 1rem; margin-bottom: 4px; text-transform: capitalize;">
                        ${dayName} - ${dayFmt}
                    </div>
                    <div style="font-size: 1.1rem; font-weight: 800; color: var(--theme-color);">
                        ${nextService.horarioInicio} às ${nextService.horarioFim}
                    </div>
                    <div style="font-size: 0.9rem; font-weight: 600; margin-top: 4px;">
                        Função: ${nextService.funcao}
                    </div>
                    ${actionBtn}
                `;
            } else {
                highlightContainer.style.display = 'none';
            }

        } catch (e) {
            console.error("Error loading scales:", e);
            container.innerHTML = `<div style="color: #ef4444; padding: 20px; text-align: center;">Erro de conexão ao carregar as escalas.</div>`;
        }
    },

    async renderOperacionalDashboard() {
        const container = document.getElementById('member-scales-list');
        container.innerHTML = `<div style="text-align: center; padding: 30px;"><i class="fa-solid fa-circle-notch fa-spin" style="font-size: 1.5rem; color: var(--theme-color);"></i></div>`;
        
        // Hide segment control and slider
        const segmentBar = document.querySelector('.segment-bar');
        const dateSlider = document.querySelector('.date-slider');
        const highlightContainer = document.getElementById('member-next-escala-highlight');
        if (segmentBar) segmentBar.style.display = 'none';
        if (dateSlider) dateSlider.style.display = 'none';
        if (highlightContainer) highlightContainer.style.display = 'none';

        try {
            const todayStr = this.formatLocalISOString(this.memberCurrentDate).split('T')[0];
            const escalas = await DbService.getEscalasDoMembro(this.currentUser.id);
            const hojeEscalas = escalas.filter(e => e.data === todayStr && e.setorId === this.activeSectorId);
            
            const sectorInfo = this.sectorsData[this.activeSectorId];
            const activeServices = await DbService.getServicosEmAndamento();
            const myActiveService = activeServices.find(s => s.membroId === this.currentUser.id && s.setorId === this.activeSectorId);

            // Verificar se o ponto está atrasado
            this.checkPontoAtrasadoMembro(hojeEscalas, myActiveService);

            let html = `
                <div style="background: linear-gradient(135deg, ${sectorInfo.cor}, #0f172a); border-radius: 16px; padding: 25px 20px; color: white; margin-bottom: 25px; box-shadow: 0 10px 25px -5px rgba(0,0,0,0.1), 0 8px 10px -6px rgba(0,0,0,0.1); position: relative; overflow: hidden;">
                    <i class="${sectorInfo.icon}" style="position: absolute; right: -10px; top: -10px; font-size: 8rem; opacity: 0.1; transform: rotate(-15deg);"></i>
                    <h2 style="font-size: 1.4rem; font-weight: 800; margin-bottom: 5px; text-shadow: 0 2px 4px rgba(0,0,0,0.3);">Expediente Diário</h2>
                    <p style="opacity: 0.9; font-size: 0.9rem; margin-bottom: 20px;">${sectorInfo.nome}</p>
            `;

            if (myActiveService) {
                html += `
                    <div style="background: rgba(255,255,255,0.15); backdrop-filter: blur(10px); -webkit-backdrop-filter: blur(10px); padding: 15px; border-radius: 12px; border: 1px solid rgba(255,255,255,0.2);">
                        <div style="display: flex; align-items: center; gap: 10px; margin-bottom: 10px;">
                            <span style="display: inline-block; width: 10px; height: 10px; background: #10B981; border-radius: 50%; box-shadow: 0 0 8px #10B981; animation: pulse 2s infinite;"></span>
                            <span style="font-weight: 700; font-size: 0.95rem;">Trabalho em andamento</span>
                        </div>
                        <div style="font-size: 0.85rem; opacity: 0.9; margin-bottom: 15px;">
                            Iniciado às ${myActiveService.horarioInicioReal || myActiveService.horarioInicio}
                        </div>
                        
                        <!-- Checklist Dinâmico -->
                        <div style="margin-bottom: 15px; padding: 10px; background: rgba(0,0,0,0.1); border-radius: 8px;">
                            <div style="font-size: 0.85rem; font-weight: 700; margin-bottom: 8px;"><i class="fa-solid fa-list-check"></i> Checklist Diário</div>
                            <div style="display: flex; flex-direction: column; gap: 6px;" id="operacional-checklist-container">
                                <label style="display: flex; align-items: center; gap: 8px; font-size: 0.85rem; cursor: pointer;">
                                    <input type="checkbox" class="op-check-item" value="Banheiros"> Banheiros
                                </label>
                                <label style="display: flex; align-items: center; gap: 8px; font-size: 0.85rem; cursor: pointer;">
                                    <input type="checkbox" class="op-check-item" value="Salão principal"> Salão principal
                                </label>
                                <label style="display: flex; align-items: center; gap: 8px; font-size: 0.85rem; cursor: pointer;">
                                    <input type="checkbox" class="op-check-item" value="Cozinha"> Cozinha
                                </label>
                                <label style="display: flex; align-items: center; gap: 8px; font-size: 0.85rem; cursor: pointer;">
                                    <input type="checkbox" class="op-check-item" value="Corredores"> Corredores
                                </label>
                                <label style="display: flex; align-items: center; gap: 8px; font-size: 0.85rem; cursor: pointer;">
                                    <input type="checkbox" class="op-check-item" value="Retirar lixo"> Retirar lixo
                                </label>
                                <label style="display: flex; align-items: center; gap: 8px; font-size: 0.85rem; cursor: pointer;">
                                    <input type="checkbox" class="op-check-item" value="Repor papel"> Repor papel
                                </label>
                                <label style="display: flex; align-items: center; gap: 8px; font-size: 0.85rem; cursor: pointer;">
                                    <input type="checkbox" class="op-check-item" value="Repor sabonete"> Repor sabonete
                                </label>
                            </div>
                        </div>

                        <button class="btn-primary" style="width: 100%; background: #EF4444; border: none; font-weight: 700; font-size: 0.9rem; padding: 12px; border-radius: 8px; box-shadow: 0 4px 6px rgba(239, 68, 68, 0.3);" onclick="App.confirmFinishServiceWithChecklist('${myActiveService.id}', '${myActiveService.escalaId}')">
                            <i class="fa-solid fa-stop"></i> Finalizar Expediente
                        </button>
                    </div>
                `;
            } else if (hojeEscalas.length > 0) {
                const e = hojeEscalas[0];
                html += `
                    <div style="background: rgba(255,255,255,0.1); backdrop-filter: blur(10px); -webkit-backdrop-filter: blur(10px); padding: 15px; border-radius: 12px; border: 1px solid rgba(255,255,255,0.2);">
                        <h3 style="font-size: 1.05rem; font-weight: 700; margin-bottom: 8px;">Trabalho de hoje<br><span style="font-size: 0.95rem; font-weight: 500; opacity: 0.9;">${e.funcao}</span></h3>
                        <p style="font-size: 0.85rem; opacity: 0.9; margin-bottom: 5px;"><i class="fa-regular fa-clock"></i> ${e.horarioInicio} - ${e.horarioFim}</p>
                        <p style="font-size: 0.85rem; opacity: 0.9; margin-bottom: 15px;">Status: <b>${e.statusPresenca}</b></p>
                        
                        ${e.statusPresenca === 'Pendente' ? `
                            <button class="btn-primary" style="width: 100%; background: #10B981; border: none; font-weight: 700; font-size: 0.9rem; padding: 12px; border-radius: 8px; margin-bottom: 10px; box-shadow: 0 4px 6px rgba(16, 185, 129, 0.3);" onclick="App.handleConfirmPresenca('${e.id}', 'Confirmada')">
                                <i class="fa-solid fa-check-double"></i> Aceitar Plantão
                            </button>
                        ` : `
                            <button class="btn-primary" style="width: 100%; background: var(--teal-primary); border: none; font-weight: 700; font-size: 0.9rem; padding: 12px; border-radius: 8px; box-shadow: 0 4px 6px rgba(20, 184, 166, 0.3);" onclick="App.handleStartService('${e.id}', '${e.funcao}', '${e.data}', '${e.horarioInicio}', '${e.horarioFim}')">
                                <i class="fa-solid fa-play"></i> Iniciar Trabalho Agora
                            </button>
                        `}
                    </div>
                `;
            } else {
                html += `
                    <div style="background: rgba(255,255,255,0.1); backdrop-filter: blur(10px); -webkit-backdrop-filter: blur(10px); padding: 15px; border-radius: 12px; border: 1px solid rgba(255,255,255,0.2);">
                        <p style="font-size: 0.9rem; opacity: 0.9; margin-bottom: 15px;"><i class="fa-solid fa-info-circle"></i> Nenhum plantão agendado para você hoje.</p>
                        <button class="btn-primary" style="width: 100%; background: rgba(255,255,255,0.2); border: 1px solid rgba(255,255,255,0.3); font-weight: 700; font-size: 0.9rem; padding: 12px; border-radius: 8px;" onclick="App.handleStartService('extra', 'Extraordinário', '${todayStr}', '00:00', '23:59')">
                            <i class="fa-solid fa-play"></i> Iniciar Trabalho Extra
                        </button>
                    </div>
                `;
            }

            html += `</div>`;
            
            // Add Quick Actions for Operational
            html += `
                <div style="margin-bottom: 25px;">
                    <h3 style="font-size: 1rem; font-weight: 700; color: var(--navy-dark); margin-bottom: 15px;">Atalhos Operacionais</h3>
                    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">
                        <div style="background: white; border-radius: 12px; padding: 15px; text-align: center; border: 1px solid #E2E8F0; cursor: pointer; transition: all 0.2s;" onclick="App.switchMemberTab('reposicao')" onmouseover="this.style.borderColor='var(--teal-primary)'; this.style.boxShadow='0 4px 6px rgba(0,0,0,0.05)';" onmouseout="this.style.borderColor='#E2E8F0'; this.style.boxShadow='none';">
                            <i class="fa-solid fa-boxes-stacked" style="font-size: 1.5rem; color: var(--teal-primary); margin-bottom: 10px;"></i>
                            <div style="font-size: 0.85rem; font-weight: 600; color: var(--navy-dark);">Estoque / Reposição</div>
                        </div>
                        <div style="background: white; border-radius: 12px; padding: 15px; text-align: center; border: 1px solid #E2E8F0; cursor: pointer; transition: all 0.2s;" onclick="App.openMinhasEscalasModal()" onmouseover="this.style.borderColor='var(--teal-primary)'; this.style.boxShadow='0 4px 6px rgba(0,0,0,0.05)';" onmouseout="this.style.borderColor='#E2E8F0'; this.style.boxShadow='none';">
                            <i class="fa-regular fa-calendar-days" style="font-size: 1.5rem; color: var(--teal-primary); margin-bottom: 10px;"></i>
                            <div style="font-size: 0.85rem; font-weight: 600; color: var(--navy-dark);">Meus Agendamentos</div>
                        </div>
                    </div>
                </div>
            `;

            container.innerHTML = html;

        } catch (e) {
            console.error("Error rendering operacional dashboard:", e);
            container.innerHTML = `<div style="color: #ef4444; padding: 20px; text-align: center;">Erro ao carregar o painel operacional.</div>`;
        }
    },

    checkPontoAtrasadoMembro(hojeEscalas, myActiveService) {
        if (myActiveService || hojeEscalas.length === 0) return;
        
        const now = new Date();
        const currentMins = now.getHours() * 60 + now.getMinutes();
        
        for (const e of hojeEscalas) {
            if (e.statusPresenca === 'Pendente' && e.horarioInicio) {
                const [h, m] = e.horarioInicio.split(':').map(Number);
                const shiftMins = (h * 60) + m;
                
                // Se a hora atual já passou do horário previsto
                if (currentMins >= shiftMins) {
                    const diff = currentMins - shiftMins;
                    // Se passou e ainda é o mesmo dia (evitar avisos às 23h59)
                    if (diff > 0 && diff < 12 * 60) {
                        this.showAlert(
                            `Você tem um plantão de ${e.funcao} agendado para <b>${e.horarioInicio}</b> que já começou. Não esqueça de clicar em <b>Iniciar Trabalho Agora</b> para registrar o seu ponto!`,
                            "⏰ Esqueceu de Iniciar o Trabalho?"
                        );
                        // Mostrar apenas o primeiro alerta
                        break;
                    }
                }
            }
        }
    },

    // Render Organograma do Dia for Diaconia do Templo
    async renderDiaconiaOrganograma(escalas, container) {
        // Ensure cultosData is loaded (v3.2)
        if (!this.cultosData || this.cultosData.length === 0) {
            try {
                this.cultosData = await DbService.getCultos();
            } catch (err) {
                this.cultosData = [];
            }
        }

        // Fetch all members to map their photo URLs
        let membrosMap = {};
        this.membrosByNameMap = {};
        try {
            const membros = await DbService.getMembros();
            membros.forEach(m => {
                membrosMap[m.id] = m;
                if (m.nome) {
                    this.membrosByNameMap[m.nome.toLowerCase().trim()] = m;
                }
            });
        } catch (e) {
            console.error("Error loading members for organogram lookup:", e);
        }

        const eventsMap = {};
        escalas.forEach(escala => {
            if (this.isOperationalSector(escala.setorId)) return; // Ignora setores operacionais
            const dateStr = escala.data;
            const timeStr = escala.horarioInicio || "00:00";
            const cultoId = escala.cultoId || "sem-culto";
            const eventKey = `${dateStr}_${cultoId}_${timeStr}`;

            if (!eventsMap[eventKey]) {
                eventsMap[eventKey] = {
                    key: eventKey,
                    data: dateStr,
                    cultoId: escala.cultoId || null,
                    cultoNome: escala.cultoNome || (escala.cultoId ? "Culto" : "Escala Diária"),
                    horarioInicio: escala.horarioInicio || "00:00",
                    horarioFim: escala.horarioFim || "00:00",
                    escalas: []
                };
            }
            eventsMap[eventKey].escalas.push(escala);
        });

        const eventsList = Object.values(eventsMap);
        eventsList.sort((a, b) => {
            if (a.data !== b.data) return a.data.localeCompare(b.data);
            return a.horarioInicio.localeCompare(b.horarioInicio);
        });

        // Cache the sorted events list
        this.memberDiaconiaEventsList = eventsList;

        const hojeStr = this.formatLocalISOString(new Date()).split('T')[0];
        let activeEventKey = this.memberSelectedEventKey;
        if (eventsList.length > 0) {
            // Find events that are today or in the future
            const upcomingEvents = eventsList.filter(e => e.data >= hojeStr);
            if (upcomingEvents.length > 0) {
                // If the selected key is not in upcoming events, auto-advance to the first upcoming one
                if (!activeEventKey || !upcomingEvents.some(e => e.key === activeEventKey)) {
                    activeEventKey = upcomingEvents[0].key;
                    this.memberSelectedEventKey = activeEventKey;
                }
            } else {
                // If all events are in the past, fall back to the last event of the month
                if (!activeEventKey || !eventsMap[activeEventKey]) {
                    activeEventKey = eventsList[eventsList.length - 1].key;
                    this.memberSelectedEventKey = activeEventKey;
                }
            }
        } else {
            this.memberSelectedEventKey = null;
        }

        let evtActive = activeEventKey ? eventsMap[activeEventKey] : null;
        if (!evtActive && activeEventKey) {
            const [dateStr, cultoId, timeStr] = activeEventKey.split('_');
            const cDetails = this.cultosData.find(c => c.id === cultoId);
            if (cDetails) {
                evtActive = {
                    key: activeEventKey,
                    data: dateStr,
                    cultoId: cultoId,
                    cultoNome: cDetails.nome,
                    horarioInicio: cDetails.horarioInicio,
                    horarioFim: cDetails.horarioFim,
                    escalas: []
                };
            }
        }

        // Formatar datas para o banner
        let bannerLabel = "";
        let bannerSub = "";
        if (evtActive) {
            const dateParts = evtActive.data.split('-');
            const d = new Date(dateParts[0], dateParts[1] - 1, dateParts[2]);
            const diaSemanaFull = d.toLocaleDateString('pt-BR', { weekday: 'long' });
            const diaSemanaShort = d.toLocaleDateString('pt-BR', { weekday: 'short' }).replace('.', '').toUpperCase();
            const dataFmt = `${dateParts[2]}/${dateParts[1]}`;
            bannerLabel = `${diaSemanaShort}, ${dataFmt} • ${evtActive.cultoNome}`;
            bannerSub = `${evtActive.horarioInicio} – ${evtActive.horarioFim}`;
        } else {
            const monthName = this.memberCurrentDate.toLocaleDateString('pt-BR', { month: 'long', year: 'numeric' });
            bannerLabel = `${monthName.toUpperCase()}`;
            bannerSub = '';
        }

        // Check if current user is scheduled for this event (for banner indicator)
        const userInEvent = evtActive ? evtActive.escalas.some(e => e.membroId === this.currentUser.id && e.statusPresenca !== 'Recusada') : false;
        const userEventScale = userInEvent ? evtActive.escalas.find(e => e.membroId === this.currentUser.id && e.statusPresenca !== 'Recusada') : null;

        // Event index for navigation
        const currentEventIdx = eventsList.findIndex(e => e.key === (evtActive ? evtActive.key : null));
        const hasPrev = currentEventIdx > 0;
        const hasNext = currentEventIdx < eventsList.length - 1;

        // Interactive Date Header with left/right navigation
        let userBadgeHtml = '';
        if (userInEvent && userEventScale) {
            const isPending = userEventScale.statusPresenca === 'Pendente';
            const badgeColor = isPending ? '#D9A752' : '#10b981';
            const badgeIcon = isPending ? 'fa-solid fa-clock' : 'fa-solid fa-circle-check';
            const badgeText = isPending ? 'CONFIRMAR' : 'CONFIRMADO';
            userBadgeHtml = `
                <span class="org-user-event-badge" style="background: rgba(${isPending ? '217,167,82' : '16,185,129'},0.15); border: 1px solid rgba(${isPending ? '217,167,82' : '16,185,129'},0.35); color: ${badgeColor};">
                    <i class="${badgeIcon}"></i> ${badgeText}
                </span>
            `;
        }

        let staticHeaderHtml = `
            <div class="org-date-nav-banner">
                <button class="org-date-nav-arrow" onclick="App.navigateOrgEvent(-1)" style="opacity: ${hasPrev ? '1' : '0.2'}; pointer-events: ${hasPrev ? 'auto' : 'none'}" title="Evento anterior">
                    <i class="fa-solid fa-chevron-left"></i>
                </button>
                <div class="org-date-nav-center">
                    <div class="org-date-nav-label">${bannerLabel}</div>
                    ${bannerSub ? `<div class="org-date-nav-sub">${bannerSub}</div>` : ''}
                    ${userBadgeHtml}
                </div>
                <button class="org-date-nav-arrow" onclick="App.navigateOrgEvent(1)" style="opacity: ${hasNext ? '1' : '0.2'}; pointer-events: ${hasNext ? 'auto' : 'none'}" title="Próximo evento">
                    <i class="fa-solid fa-chevron-right"></i>
                </button>
            </div>
        `;

        if (!evtActive) {
            container.innerHTML = `
                ${staticHeaderHtml}
                <div style="text-align: center; padding: 40px var(--white); background: rgba(255,255,255,0.02); border: 1px solid rgba(255,255,255,0.06); border-radius: 16px; margin-top: 15px;">
                    <i class="fa-solid fa-calendar-xmark" style="font-size: 2.5rem; color: #8AA6A3; opacity: 0.4; margin-bottom: 12px;"></i>
                    <p style="color: #8AA6A3; font-size: 0.95rem;">Nenhuma escala agendada para este período.</p>
                </div>
            `;
            return;
        }

        const portariaScales = [];
        const checkinScales = [];
        const apoioDireitoScales = [];
        const apoioEsquerdoScales = [];
        const rondaDireitoScales = [];
        const rondaEsquerdoScales = [];
        const acolhimentoScales = [];
        const escalaLivreScales = [];

        evtActive.escalas.forEach(escala => {
            if (escala.statusPresenca === 'Recusada') {
                return;
            }

            const membroId = escala.membroId;
            const nomeKey = (escala.membroNome || '').toLowerCase().trim();
            const membro = (membroId ? membrosMap[membroId] : null) || this.membrosByNameMap[nomeKey];
            
            if (!membro || membro.status === 'inativo') {
                return;
            }

            const sectorId = escala.setorId;
            const func = (escala.funcao || '').toLowerCase();
            const obs = (escala.observacoes || '').toLowerCase();

            if (sectorId === 'escala_livre' || func.includes('escala livre')) {
                escalaLivreScales.push(escala);
            } else if (sectorId === 'acolhimento' || func.includes('acolhimento') || func.includes('conduzir') || func.includes('recepcionar') || func.includes('servir') || func.includes('preparar')) {
                acolhimentoScales.push(escala);
            } else if (sectorId === 'entrada' || func.includes('entrada') || func.includes('portaria')) {
                portariaScales.push(escala);
            } else if (sectorId === 'check_in' || func.includes('check')) {
                checkinScales.push(escala);
            } else if (sectorId === 'apoio_templo_ronda_dir') {
                if (func.includes('ronda')) {
                    rondaDireitoScales.push(escala);
                } else {
                    apoioDireitoScales.push(escala);
                }
            } else if (sectorId === 'apoio_templo_ronda_esq') {
                if (func.includes('ronda')) {
                    rondaEsquerdoScales.push(escala);
                } else {
                    apoioEsquerdoScales.push(escala);
                }
            } else {
                if (func.includes('portaria') || func.includes('entrada')) {
                    portariaScales.push(escala);
                } else if (func.includes('check')) {
                    checkinScales.push(escala);
                } else if (func.includes('apoio')) {
                    if (func.includes('direito') || obs.includes('direito') || func.includes('dir')) {
                        apoioDireitoScales.push(escala);
                    } else {
                        apoioEsquerdoScales.push(escala);
                    }
                } else if (func.includes('ronda')) {
                    if (func.includes('direito') || obs.includes('direito') || func.includes('dir')) {
                        rondaDireitoScales.push(escala);
                    } else {
                        rondaEsquerdoScales.push(escala);
                    }
                }
            }
        });

        // Verificar se o culto é no modelo Escala Livre
        const cultoAtivo = this.cultosData.find(c => c.id === evtActive.cultoId);
        const isEscalaLivre = cultoAtivo && cultoAtivo.modeloEscala === 'Escala Livre';

        // Gerar cards do organograma
        let areaCardsHtml = '';
        if (isEscalaLivre) {
            // Exibir apenas o cartão único de Escala Livre em largura total
            areaCardsHtml = this.renderAreaCard(escalaLivreScales, 'Escala Livre', 'fa-solid fa-users', 'escala_livre', 'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?auto=format&fit=crop&w=800&q=80', '#6B7280', membrosMap, true);
        } else {
            const recepcaoCardHtml = this.renderAreaCard([...portariaScales, ...checkinScales], 'Recepção', 'fa-solid fa-id-card', 'recepcao', 'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?auto=format&fit=crop&w=400&q=80', '#3B82F6', membrosMap);
            const temploCardHtml = this.renderAreaCard([...apoioDireitoScales, ...apoioEsquerdoScales, ...rondaDireitoScales, ...rondaEsquerdoScales], 'Templo', 'fa-solid fa-place-of-worship', 'templo', 'https://images.unsplash.com/photo-1545232979-8bf34eb9757b?auto=format&fit=crop&w=400&q=80', '#14B8A6', membrosMap);
            const acolhimentoCardHtml = this.renderAreaCard(acolhimentoScales, 'Acolhimento', 'fa-solid fa-hands-holding-child', 'acolhimento', 'https://images.unsplash.com/photo-1511632765486-a01980e01a18?auto=format&fit=crop&w=800&q=80', '#EC4899', membrosMap);
            areaCardsHtml = `${recepcaoCardHtml}${temploCardHtml}${acolhimentoCardHtml}`;
        }

        // Next service calculation for bottom summary card
        let nextServiceLabel = 'Nenhum serviço';
        let nextServiceDetail = 'Sem escalas agendadas';
        const hojeStr2 = this.formatLocalISOString(new Date()).split('T')[0];
        const userScales = escalas.filter(e => e.membroId === this.currentUser.id && e.data >= hojeStr2 && e.statusServico !== 'Finalizado' && e.statusPresenca !== 'Recusada');
        userScales.sort((a, b) => a.data.localeCompare(b.data) || a.horarioInicio.localeCompare(b.horarioInicio));
        if (userScales.length > 0) {
            const next = userScales[0];
            const [y, m, d] = next.data.split('-');
            nextServiceLabel = `${d}/${m} - ${next.horarioInicio}`;
            nextServiceDetail = `${next.funcao}`;
        }

        // Unread notices count
        let unreadCount = 0;
        try {
            const readAvisosStr = localStorage.getItem('diaconia_read_avisos');
            const readIds = readAvisosStr ? JSON.parse(readAvisosStr) : [];
            const avisos = this.cachedAvisosList || [];
            unreadCount = avisos.filter(a => !readIds.includes(a.id)).length;
        } catch (err) {}        const unreadLabelHtml = unreadCount > 0 ? `<span class="summary-bell-badge" style="display: flex; position: absolute; top: -5px; right: -5px; background: #ef4444; color: white; border-radius: 50%; width: 18px; height: 18px; align-items: center; justify-content: center; font-size: 0.65rem; font-weight: 700;">${unreadCount}</span>` : '';
        const unreadText = unreadCount === 1 ? 'Você tem 1 aviso' : `Você tem ${unreadCount} avisos`;

        let nextServiceOnClick = "";
        let nextServiceCursor = "";
        if (userScales.length > 0) {
            nextServiceOnClick = `onclick="App.openMinhasEscalasModal()"`;
            nextServiceCursor = "cursor: pointer;";
        }

        const summaryBlockHtml = `
            <div class="selection-summary-container" style="margin-top: 15px; display: flex; align-items: center; gap: 10px; width: 100%;">
                <div class="summary-col" style="flex: 1; display: flex; align-items: center; gap: 10px; background: rgba(255,255,255,0.02); border: 1px solid rgba(255,255,255,0.06); padding: 12px; border-radius: 16px; ${nextServiceCursor}" ${nextServiceOnClick}>
                    <div class="summary-icon-wrap" style="width: 32px; height: 32px; border-radius: 50%; background: rgba(18, 115, 105, 0.1); border: 1px solid rgba(18, 115, 105, 0.2); color: #127369; display: flex; align-items: center; justify-content: center; font-size: 0.95rem;">
                        <i class="fa-regular fa-calendar-check"></i>
                    </div>
                    <div class="summary-text-wrap" style="text-align: left;">
                        <span class="summary-label" style="display: block; font-size: 0.68rem; color: #8AA6A3; font-weight: 600; text-transform: uppercase;">Meus Serviços</span>
                        <span class="summary-val-main" style="display: block; font-size: 0.8rem; font-weight: 700; color: #fff; margin-top: 1px;">${nextServiceLabel}</span>
                        <span class="summary-val-sub" style="display: block; font-size: 0.68rem; color: #BFBFBF; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 100px;">Clique para gerenciar</span>
                    </div>
                </div>
                
                <div class="summary-col" style="flex: 1; display: flex; align-items: center; gap: 10px; background: rgba(255,255,255,0.02); border: 1px solid rgba(255,255,255,0.06); padding: 12px; border-radius: 16px; cursor: pointer;" onclick="App.switchMemberTab('avisos')">
                    <div class="summary-icon-wrap" style="width: 32px; height: 32px; border-radius: 50%; background: rgba(18, 115, 105, 0.1); border: 1px solid rgba(18, 115, 105, 0.2); color: #127369; display: flex; align-items: center; justify-content: center; font-size: 0.95rem; position: relative;">
                        <i class="fa-regular fa-bell"></i>
                        ${unreadLabelHtml}
                    </div>
                    <div class="summary-text-wrap" style="text-align: left;">
                        <span class="summary-label" style="display: block; font-size: 0.68rem; color: #8AA6A3; font-weight: 600; text-transform: uppercase;">Avisos</span>
                        <span class="summary-val-main" style="display: block; font-size: 0.8rem; font-weight: 700; color: #fff; margin-top: 1px;">Avisos não lidos</span>
                        <span class="summary-val-sub" style="display: block; font-size: 0.68rem; color: #BFBFBF; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 100px;">${unreadText}</span>
                    </div>
                </div>
            </div>
        `;

        // --- NOVO: Renderizar Escalas Pendentes (Confirmação) ---
        const userPendingScales = escalas.filter(e => e.membroId === this.currentUser.id && e.statusPresenca === 'Pendente' && e.data >= hojeStr && !this.isOperationalSector(e.setorId));
        let pendingAlertHtml = '';
        if (userPendingScales.length > 0) {
            let cardsHtml = userPendingScales.map(e => {
                const dateParts = e.data.split('-');
                const d = new Date(dateParts[0], dateParts[1] - 1, dateParts[2]);
                const diaFormatado = d.toLocaleDateString('pt-BR', { weekday: 'short', day: '2-digit', month: '2-digit' });
                return `
                    <div style="background: rgba(255,255,255,0.05); border: 1px solid rgba(255,255,255,0.1); border-radius: 10px; padding: 12px; margin-bottom: 10px;">
                        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
                            <span style="font-weight: 700; color: #fff;">${e.cultoNome || 'Escala'}</span>
                            <span style="font-size: 0.75rem; background: #D9A752; color: #fff; padding: 2px 6px; border-radius: 4px; font-weight: 600;">Pendente</span>
                        </div>
                        <div style="font-size: 0.85rem; color: #BFBFBF; margin-bottom: 12px;">
                            <i class="fa-regular fa-calendar" style="margin-right: 4px;"></i> ${diaFormatado.toUpperCase()} • ${e.horarioInicio} - ${e.horarioFim}<br>
                            <i class="fa-solid fa-user-tag" style="margin-right: 4px; margin-top: 6px;"></i> ${e.funcao}
                        </div>
                        <div style="display: flex; gap: 8px;">
                            <button class="btn-scale-action btn-recusar-presenca" onclick="App.handleConfirmPresenca('${e.id}', 'Recusada')" style="flex: 1; padding: 8px; border-radius: 6px;">
                                <i class="fa-solid fa-xmark"></i> Recusar
                            </button>
                            <button class="btn-scale-action btn-confirm-presenca" onclick="App.handleConfirmPresenca('${e.id}', 'Confirmada')" style="flex: 1; padding: 8px; border-radius: 6px; background: #10B981; color: white;">
                                <i class="fa-solid fa-check"></i> Aceitar
                            </button>
                        </div>
                    </div>
                `;
            }).join('');
            
            pendingAlertHtml = `
                <div style="margin-bottom: 20px; padding: 15px; background: linear-gradient(135deg, rgba(217, 167, 82, 0.15), rgba(217, 167, 82, 0.05)); border: 1px solid rgba(217, 167, 82, 0.3); border-radius: 12px;">
                    <h3 style="color: #D9A752; font-size: 0.95rem; font-weight: 700; margin-bottom: 12px; text-transform: uppercase;">
                        <i class="fa-solid fa-bell" style="margin-right: 6px;"></i> Suas Escalas Pendentes
                    </h3>
                    ${cardsHtml}
                </div>
            `;
        }
        // ---------------------------------------------------------

        container.innerHTML = `
            ${pendingAlertHtml}
            ${staticHeaderHtml}
            
            <div class="org-daily-container" id="org-daily-swipe-area">
                <div class="org-areas-grid">
                    ${areaCardsHtml}
                </div>
                
                ${summaryBlockHtml}
            </div>
        `;

        // Auto-open area detail if navigation was triggered from "Próximo Serviço"
        if (this.pendingOpenAreaDetailNodeId) {
            const nodeIdToOpen = this.pendingOpenAreaDetailNodeId;
            this.pendingOpenAreaDetailNodeId = null;
            setTimeout(() => {
                this.openAreaDetail(nodeIdToOpen);
            }, 200);
        }
    },

    renderAreaCard(scales, title, iconClass, nodeId, bgImageUrl, accentColor, membrosMap = {}, isFullWidth = false) {
        // Deduplicate scales by member
        const uniqueScales = [];
        const seenMembers = new Set();
        scales.forEach(escala => {
            const key = escala.membroId || escala.membroNome;
            if (key && !seenMembers.has(key)) {
                seenMembers.add(key);
                uniqueScales.push(escala);
            }
        });

        const count = uniqueScales.length;
        const countText = count === 1 ? '1 escalado' : `${count} voluntários`;

        const cardSpanClass = isFullWidth ? 'grid-column: span 2;' : '';
        
        // Static descriptions matching sectors
        const descMap = {
            'portaria': 'Controle de entrada e segurança',
            'checkin': 'Cadastro e identificação',
            'apoio-direito': 'Organização do lado direito',
            'apoio-esquerdo': 'Organização do lado esquerdo',
            'acolhimento': 'Receber e acolher com amor e excelência',
            
            // Unified mappings (v3.6.22)
            'recepcao': 'Controle de portaria e check-in de membros',
            'templo': 'Suporte, organização e acomodação no templo',
            'ronda': 'Ronda periódica e segurança externa/interna',
            'escala_livre': 'Atuar onde houver necessidade seguindo a supervisão'
        };
        const desc = descMap[nodeId] || '';

        // Check if the current user is scheduled in this specific area card
        const isUserAssigned = uniqueScales.some(escala => escala.membroId === this.currentUser.id);
        const cardClass = `org-area-card card-${nodeId} ${isUserAssigned ? 'user-assigned-card' : ''}`;

        if (isFullWidth) {
            return `
                <div class="org-area-card-wrapper" style="${cardSpanClass}">
                    <div class="${cardClass} card-horizontal" onclick="App.openAreaDetail('${nodeId}')">
                        <div class="org-area-pattern-overlay"></div>
                        <div style="display: flex; align-items: center; justify-content: space-between; gap: 12px; z-index: 1; width: 100%;">
                            <div style="display: flex; align-items: center; gap: 12px;">
                                <span class="org-area-icon-wrap-premium"><i class="${iconClass}"></i></span>
                                <h4 class="org-area-title" style="margin: 0;">${title}</h4>
                            </div>
                            ${isUserAssigned ? `<span class="user-assigned-badge"><i class="fa-solid fa-star"></i> SUA ESCALA</span>` : ''}
                        </div>
                        <p class="org-area-desc" style="z-index: 1; margin-top: 4px; text-align: left;">${desc}</p>
                        <div class="org-area-action">
                            <button class="org-area-chevron-circle-premium">
                                <i class="fa-solid fa-chevron-right"></i>
                            </button>
                        </div>
                    </div>
                </div>
            `;
        } else {
            return `
                <div class="org-area-card-wrapper" style="${cardSpanClass}">
                    <div class="${cardClass}" onclick="App.openAreaDetail('${nodeId}')">
                        <div class="org-area-pattern-overlay"></div>
                        <div style="display: flex; justify-content: space-between; width: 100%; align-items: flex-start; z-index: 1;">
                            <span class="org-area-icon-wrap-premium"><i class="${iconClass}"></i></span>
                            ${isUserAssigned ? `<span class="user-assigned-badge"><i class="fa-solid fa-star"></i> VOCÊ</span>` : ''}
                        </div>
                        <div class="org-area-text-section" style="margin-top: 10px; text-align: left; z-index: 1; width: 100%;">
                            <h4 class="org-area-title">${title}</h4>
                            <p class="org-area-desc" style="margin-top: 2px; line-height: 1.25;">${desc}</p>
                        </div>
                        <div class="org-area-action">
                            <button class="org-area-chevron-circle-premium">
                                <i class="fa-solid fa-chevron-right"></i>
                            </button>
                        </div>
                    </div>
                </div>
            `;
        }
    },

    // Static area goals and checklist configuration mapping
    areaStaticData: {
        'portaria': {
            objetivo: 'Controlar entrada e saída, recepcionar membros e manter a organização da entrada principal.',
            local: 'Entrada principal',
            supervisor: 'Supervisor Wan',
            chegada: '17:30',
            traje: 'Social',
            checklist: [
                'Organizar a entrada e saídas',
                'Recepcionar membros e visitantes',
                'Verificar fluxo de pessoas',
                'Auxiliar pessoas com necessidades especiais',
                'Manter comunicação com a equipe'
            ],
            instrucoes: 'Permaneça atento à entrada de pessoas sem identificação. Qualquer atitude suspeita, informe imediatamente ao Supervisor ou diáconos da ronda.'
        },
        'checkin': {
            objetivo: 'Realizar o cadastro e identificação de obreiros, membros e visitantes na entrada.',
            local: 'Balcão de check-in',
            supervisor: 'Supervisor Wan',
            chegada: '17:30',
            checklist: [
                'Ligar pc de check-in e monitor de propaganda',
                'Organizar envelopes, canetas e papéis de anotações',
                'Fazer check-in das crianças que entram',
                'Identificar e orientar visitantes',
                'Organizar fila de atendimento'
            ],
            instrucoes: 'Mantenha um sorriso no rosto. Se houver falha no sistema do tablet, use a ficha de papel de contingência.'
        },
        'apoio-direito': {
            objetivo: 'Dar suporte, orientação e acomodação aos membros e visitantes nas naves e assentos do lado direito.',
            local: 'Templo Lado Direito',
            supervisor: 'Supervisor Wan',
            chegada: '17:45',
            traje: 'Social',
            checklist: [
                'Verificar a limpeza e organização das cadeiras',
                'Orientar pessoas na ocupação dos assentos',
                'Auxiliar na coleta de ofertas e dízimos',
                'Manter postura discreta durante as orações',
                'Prestar atenção a qualquer mal-estar físico'
            ],
            instrucoes: 'Sempre acomode as pessoas da frente para trás para evitar assentos vazios dispersos.'
        },
        'apoio-esquerdo': {
            objetivo: 'Dar suporte, orientação e acomodação aos membros e visitantes nas naves e assentos do lado esquerdo.',
            local: 'Templo Lado Esquerdo',
            supervisor: 'Supervisor Wan',
            chegada: '17:45',
            traje: 'Social',
            checklist: [
                'Verificar a limpeza e organização das cadeiras',
                'Orientar pessoas na ocupação dos assentos',
                'Auxiliar na coleta de ofertas e dízimos',
                'Manter postura discreta durante as orações',
                'Prestar atenção a qualquer mal-estar físico'
            ],
            instrucoes: 'Sempre acomode as pessoas da frente para trás para evitar assentos vazios dispersos.'
        },
        'ronda-direito': {
            objetivo: 'Realizar rondas periódicas de segurança na área externa da entrada, sala pastoral e sala multiuso.',
            local: 'Estacionamento Lado Direito',
            supervisor: 'Supervisor Wan',
            chegada: '17:30',
            traje: 'Esporte Fino',
            checklist: [
                'Rondar as vias laterais e estacionamento',
                'Verificar fechamento de portões auxiliares',
                'Relatar qualquer movimentação atípica'
            ],
            instrucoes: 'Permaneça em movimento constante. Não se isole em locais escuros.'
        },
        'ronda-esquerdo': {
            objetivo: 'Realizar rondas periódicas de segurança na área externa (lado da cozinha), banheiros, salas de bebês e crianças, e garantia de que a porta do meio esteja sempre fechada.',
            local: 'Estacionamento Lado Esquerdo',
            supervisor: 'Supervisor Wan',
            chegada: '17:30',
            traje: 'Esporte Fino',
            checklist: [
                'Rondar as vias laterais e estacionamento',
                'Verificar fechamento de portões auxiliares',
                'Relatar qualquer movimentação atípica'
            ],
            instrucoes: 'Permaneça em movimento constante. Não se isole em locais escuros.'
        },
        'acolhimento': {
            objetivo: 'Receber, acolher e cuidar de pessoas com amor, empatia e excelência.',
            local: 'Sala de Acolhimento',
            supervisor: 'Supervisor Wan',
            chegada: '17:45',
            traje: 'Social',
            checklist: [
                'Posicionar-se após o final do culto na sala de acolhimento',
                'Recepcionar visitantes e servi-los com alegria',
                'Deixá-los à vontade para receber o pastor',
                'Entregar lembrancinhas'
            ],
            instrucoes: 'Seu sorriso é o primeiro contato das pessoas com a igreja. Sirva com amor!'
        },
        'recepcao': {
            objetivo: 'Controlar entrada e saída de pessoas, realizar check-in, recepcionar membros e visitantes na entrada principal.',
            local: 'Portaria e Balcão de Check-in',
            supervisor: 'Supervisor Wan',
            chegada: '17:30',
            traje: 'Social',
            checklist: [
                'Organizar a entrada e saídas',
                'Recepcionar membros e visitantes',
                'Ligar pc de check-in e monitor de propaganda',
                'Fazer check-in das pessoas que entram',
                'Auxiliar pessoas com necessidades especiais'
            ],
            instrucoes: 'Permaneça atento à entrada de pessoas e faça o registro com um sorriso no rosto. Use fichas de contingência em papel se houver problemas no tablet/computador.'
        },
        'templo': {
            objetivo: 'Dar suporte, orientação e acomodação aos membros e visitantes nas naves e assentos do templo (lados direito e esquerdo).',
            local: 'Nave do Templo',
            supervisor: 'Supervisor Wan',
            chegada: '17:45',
            traje: 'Social',
            checklist: [
                'Verificar a limpeza e organização das cadeiras',
                'Orientar pessoas na ocupação dos assentos',
                'Auxiliar na coleta de ofertas e dízimos',
                'Manter postura discreta durante as orações',
                'Prestar atenção a qualquer mal-estar físico'
            ],
            instrucoes: 'Sempre acomode as pessoas da frente para trás para evitar assentos vazios dispersos.'
        },
        'ronda': {
            objetivo: 'Realizar rondas periódicas de segurança nas áreas externas, estacionamentos, laterais, banheiros e salas de apoio.',
            local: 'Estacionamentos e Vias Laterais',
            supervisor: 'Supervisor Wan',
            chegada: '17:30',
            traje: 'Esporte Fino',
            checklist: [
                'Rondar as vias laterais e estacionamentos',
                'Verificar fechamento de portões auxiliares',
                'Garantir fechamento de portas de segurança',
                'Relatar qualquer movimentação atípica'
            ],
            instrucoes: 'Permaneça em movimento constante e mantenha contato com o Supervisor Geral.'
        },
        'escala_livre': {
            objetivo: 'Atuar com excelência onde houver necessidade durante o culto, seguindo a orientação da supervisão.',
            local: 'Templo e Áreas Gerais',
            supervisor: 'Supervisor Geral',
            chegada: '17:30',
            traje: 'Social',
            checklist: [
                'Apresentar-se ao Supervisor ao chegar',
                'Estar disponível para qualquer função designada',
                'Manter postura e disciplina durante o culto',
                'Comunicar ao Supervisor qualquer intercorrência'
            ],
            instrucoes: 'Você está em escala livre. Siga as instruções do Supervisor Geral e sirva com excelência onde for necessário.'
        }
    },

    openAreaDetail(nodeId) {
        // Hide the main scales view and the main header
        document.getElementById('member-sub-escala').style.display = 'none';
        const memberHeader = document.querySelector('.member-header');
        if (memberHeader) memberHeader.style.display = 'none';

        const detailContainer = document.getElementById('member-sub-area-detail');
        detailContainer.style.display = 'flex';
        detailContainer.style.flexDirection = 'column';
        detailContainer.innerHTML = '<div style="text-align: center; padding: 50px;"><i class="fa-solid fa-circle-notch fa-spin" style="font-size: 1.5rem; color: var(--theme-color);"></i></div>';

        // Load details dynamically
        setTimeout(async () => {
            try {
                // Ensure cultosData is loaded (v3.2)
                if (!this.cultosData || this.cultosData.length === 0) {
                    try {
                        this.cultosData = await DbService.getCultos();
                    } catch (err) {
                        this.cultosData = [];
                    }
                }

                const activeEventKey = this.memberSelectedEventKey;
                if (!activeEventKey) {
                    this.showToast('Selecione um culto primeiro.', 'warning');
                    this.closeAreaDetail();
                    return;
                }

                // Parse active event key
                const [dateStr, cultoId, timeStr] = activeEventKey.split('_');
                const escalas = await DbService.getEscalas(null, dateStr, dateStr);

                // Filter escalas for this specific area
                const areaScales = [];
                escalas.forEach(escala => {
                    const sectorId = escala.setorId;
                    const func = (escala.funcao || '').toLowerCase();
                    const obs = (escala.observacoes || '').toLowerCase();

                    if (escala.statusPresenca === 'Recusada') return;

                    if (nodeId === 'escala_livre' && (sectorId === 'escala_livre' || func.includes('escala livre'))) {
                        areaScales.push(escala);
                    } else if (nodeId === 'acolhimento' && (sectorId === 'acolhimento' || func.includes('acolhimento'))) {
                        areaScales.push(escala);
                    } else if (nodeId === 'recepcao' && (sectorId === 'entrada' || sectorId === 'check_in' || func.includes('entrada') || func.includes('check') || func.includes('portaria') || func.includes('recep'))) {
                        areaScales.push(escala);
                    } else if (nodeId === 'templo' && (sectorId === 'apoio_templo_ronda_dir' || sectorId === 'apoio_templo_ronda_esq' || func.includes('apoio') || func.includes('ronda'))) {
                        areaScales.push(escala);
                        if (nodeId === 'portaria' && (func.includes('portaria') || func.includes('entrada'))) {
                            areaScales.push(escala);
                        } else if (nodeId === 'checkin' && func.includes('check')) {
                            areaScales.push(escala);
                        } else if (nodeId === 'apoio-direito' && func.includes('apoio') && (func.includes('direito') || obs.includes('direito') || func.includes('dir'))) {
                            areaScales.push(escala);
                        } else if (nodeId === 'apoio-esquerdo' && func.includes('apoio') && (func.includes('esquerdo') || obs.includes('esquerdo') || func.includes('esq'))) {
                            areaScales.push(escala);
                        } else if (nodeId === 'ronda-direito' && func.includes('ronda') && (func.includes('direito') || obs.includes('direito') || func.includes('dir'))) {
                            areaScales.push(escala);
                        } else if (nodeId === 'ronda-esquerdo' && func.includes('ronda') && (func.includes('esquerdo') || obs.includes('esquerdo') || func.includes('esq'))) {
                            areaScales.push(escala);
                        }
                    }
                });

                const uniqueScales = [];
                const seenMembers = new Set();
                areaScales.forEach(escala => {
                    const key = escala.membroId || escala.membroNome;
                    if (key && !seenMembers.has(key)) {
                        seenMembers.add(key);
                        uniqueScales.push(escala);
                    }
                });

                const staticData = this.areaStaticData[nodeId] || {
                    objetivo: 'Atuar com excelência no culto.',
                    local: 'Templo',
                    supervisor: 'Supervisor Wan',
                    chegada: '18:00',
                    traje: 'Fino',
                    checklist: ['Chegar no horário', 'Fazer oração com a equipe'],
                    instrucoes: 'Sirva com alegria e excelência.'
                };

                const titleMap = {
                    'portaria': 'Portaria',
                    'checkin': 'Check-in',
                    'apoio-direito': 'Templo L. Dir.',
                    'apoio-esquerdo': 'Templo L. Esq.',
                    'ronda-direito': 'Ronda L. Dir.',
                    'ronda-esquerdo': 'Ronda L. Esq.',
                    'acolhimento': 'Acolhimento',
                    
                    // Unified mappings (v3.6.22)
                    'recepcao': 'Recepção',
                    'templo': 'Templo',
                    'ronda': 'Ronda',
                    'escala_livre': 'Escala Livre'
                };
                const areaTitle = titleMap[nodeId] || nodeId;

                const iconMap = {
                    'portaria': 'fa-solid fa-door-open',
                    'checkin': 'fa-solid fa-id-card',
                    'apoio-direito': 'fa-solid fa-place-of-worship',
                    'apoio-esquerdo': 'fa-solid fa-place-of-worship',
                    'ronda-direito': 'fa-solid fa-shield-halved',
                    'ronda-esquerdo': 'fa-solid fa-shield-halved',
                    'acolhimento': 'fa-solid fa-heart',
                    
                    // Unified mappings (v3.6.22)
                    'recepcao': 'fa-solid fa-id-card',
                    'templo': 'fa-solid fa-place-of-worship',
                    'ronda': 'fa-solid fa-shield-halved',
                    'escala_livre': 'fa-solid fa-users'
                };
                const iconClass = iconMap[nodeId] || 'fa-solid fa-circle';

                // Fetch members map for photo URLs
                let membrosMap = {};
                try {
                    const membros = await DbService.getMembros();
                    membros.forEach(m => {
                        membrosMap[m.id] = m;
                    });
                } catch (e) {}

                // Active Event Info
                const activeEvent = uniqueScales.length > 0 ? uniqueScales[0] : null;
                const activeEventDetails = this.cultosData.find(c => c.data === dateStr);
                const cultoNome = activeEvent ? activeEvent.cultoNome : (activeEventDetails ? activeEventDetails.nome : 'Culto');
                const horarioInicio = activeEvent ? activeEvent.horarioInicio : (activeEventDetails ? activeEventDetails.horarioInicio : '18:00');
                const horarioFim = activeEvent ? activeEvent.horarioFim : (activeEventDetails ? activeEventDetails.horarioFim : '22:00');

                // Fetch standbys for this event/area (v3.2)
                let standbys = [];
                try {
                    standbys = await DbService.getStandbys();
                } catch (e) {
                    console.error("Error loading standbys for organogram detail:", e);
                }
                const areaStandbys = standbys.filter(s => {
                    if (s.cultoId !== cultoId) return false;
                    const sectorId = s.setorId;
                    const funcLower = (s.funcao || '').toLowerCase();
                    if (nodeId === 'acolhimento' && (sectorId === 'acolhimento' || funcLower.includes('acolhimento'))) return true;
                    if (nodeId === 'recepcao' && (sectorId === 'entrada' || sectorId === 'check_in' || funcLower.includes('entrada') || funcLower.includes('check') || funcLower.includes('portaria') || funcLower.includes('recep'))) return true;
                    if (nodeId === 'templo' && (sectorId === 'apoio_templo_ronda_dir' || sectorId === 'apoio_templo_ronda_esq' || funcLower.includes('apoio'))) return true;
                    if (nodeId === 'ronda' && (sectorId === 'apoio_templo_ronda_dir' || sectorId === 'apoio_templo_ronda_esq' || funcLower.includes('ronda'))) return true;
                    return s.setorId === this.activeSectorId;
                });

                let standbysHtml = '';
                if (areaStandbys.length > 0) {
                    standbysHtml = `
                        <div class="panel-card" style="margin-bottom: 12px; text-align: left; padding: 15px; border: 1px dashed rgba(18, 115, 105, 0.4); background: rgba(18, 115, 105, 0.02);">
                            <div style="font-size: 0.85rem; font-weight: 700; color: #fff; margin-bottom: 10px;">
                                <i class="fa-solid fa-hand-holding-hand" style="color: var(--theme-color); margin-right: 5px;"></i> Obreiros Disponíveis (Backup)
                            </div>
                            <div style="display: flex; flex-direction: column; gap: 8px;">
                    `;
                    areaStandbys.forEach(s => {
                        const isOwn = s.membroId === this.currentUser.id;
                        const membroInfo = membrosMap[s.membroId];
                        const fotoUrl = membroInfo ? membroInfo.fotoUrl : null;
                        const avatarHtml = this.getCardAvatarHtml(s.membroNome, fotoUrl, 1);
                        
                        standbysHtml += `
                            <div style="display: flex; align-items: center; gap: 12px; padding: 6px 10px; border-radius: 8px; background: rgba(255, 255, 255, 0.01);">
                                ${avatarHtml}
                                <div style="flex: 1; text-align: left;">
                                    <div style="font-size: 0.82rem; font-weight: 700; color: #fff;">${s.membroNome} ${isOwn ? '<span style="color:#8AA6A3; font-weight:500;">(Você)</span>' : ''}</div>
                                    <div style="font-size: 0.68rem; color: #8AA6A3; margin-top: 1px;">Disponível como voluntário</div>
                                </div>
                            </div>
                        `;
                    });
                    standbysHtml += `
                            </div>
                        </div>
                    `;
                }

                // Area status calculations
                let statusTitle = 'Área pronta';
                let statusDesc = 'Todos os membros confirmados';
                let statusDotColor = '#127369';
                let statusClassBox = 'status-ready';

                if (uniqueScales.length === 0) {
                    statusTitle = 'Aguardando escala';
                    statusDesc = 'Nenhum voluntário escalado';
                    statusDotColor = '#D9A752';
                    statusClassBox = 'status-waiting';
                } else {
                    const hasPending = uniqueScales.some(e => e.statusPresenca === 'Pendente');
                    if (hasPending) {
                        statusTitle = 'Aguardando confirmações';
                        statusDesc = 'Alguns membros ainda não confirmaram a presença';
                        statusDotColor = '#D9A752';
                        statusClassBox = 'status-waiting';
                    }
                }

                // Render Team List
                let teamListHtml = '';
                uniqueScales.forEach(escala => {
                    const isOwn = escala.membroId === this.currentUser.id;
                    let statusClass = 'status-pendente';
                    let statusLabel = 'Pendente';
                    if (escala.statusPresenca === 'Confirmada') {
                        statusClass = 'status-confirmado';
                        statusLabel = 'Confirmado';
                    } else if (escala.statusPresenca === 'Recusada') {
                        statusClass = 'status-recusado';
                        statusLabel = 'Recusado';
                    }

                    const membroInfo = membrosMap[escala.membroId];
                    const fotoUrl = membroInfo ? membroInfo.fotoUrl : null;
                    const avatarHtml = this.getCardAvatarHtml(escala.membroNome, fotoUrl, 1);
                    
                    const isRonda = (escala.funcao || '').toLowerCase().includes('ronda');
                    const rondaBadge = isRonda ? `<span style="background: rgba(245, 158, 11, 0.2); border: 1px solid #F59E0B; color: #F59E0B; padding: 2px 6px; border-radius: 4px; font-size: 0.65rem; font-weight: 800; text-transform: uppercase;"><i class="fa-solid fa-shield-halved"></i> Ronda</span>` : '';

                    teamListHtml += `
                        <div style="display: flex; align-items: center; gap: 12px; background: rgba(255, 255, 255, 0.02); padding: 8px 12px; border-radius: 12px; border: 1px solid rgba(255, 255, 255, 0.05);">
                            ${avatarHtml}
                            <div style="flex: 1; text-align: left;">
                                <div style="font-size: 0.85rem; font-weight: 700; color: #fff; display: flex; align-items: center; gap: 6px;">${escala.membroNome} ${isOwn ? '<span style="color:#8AA6A3; font-weight:500;">(Você)</span>' : ''} ${rondaBadge}</div>
                                <div style="font-size: 0.7rem; color: #8AA6A3; margin-top: 1px; display: flex; align-items: center; gap: 4px; flex-wrap: wrap;">
                                    <span style="font-weight: 700; color: var(--theme-color);"><i class="fa-solid fa-user-tag" style="font-size: 0.65rem; margin-right: 2px;"></i>${escala.funcao || 'Membro'}</span>
                                    ${escala.observacoes ? `<span style="color: #8AA6A3;">•</span> <span style="color: #D9A752; font-weight: 600;"><i class="fa-solid fa-map-pin" style="font-size: 0.65rem; margin-right: 2px;"></i>${escala.observacoes}</span>` : ''}
                                </div>
                            </div>
                            <span class="card-scale-status ${statusClass}" style="font-size: 0.68rem; padding: 3px 8px; border-radius: 6px;">${statusLabel}</span>
                        </div>
                    `;
                });

                if (uniqueScales.length === 0) {
                    teamListHtml = '<div style="font-size: 0.8rem; color: #8AA6A3; padding: 10px; text-align: center;">Nenhum obreiro escalado ainda.</div>';
                }

                // Checkboxes setup
                let checklistHtml = '';
                const savedChecklistStr = localStorage.getItem(`diaconia_checklist_${activeEventKey}_${nodeId}`);
                const savedChecklist = savedChecklistStr ? JSON.parse(savedChecklistStr) : {};

                staticData.checklist.forEach((item, index) => {
                    const isChecked = savedChecklist[index] === true;
                    checklistHtml += `
                        <label style="display: flex; align-items: center; gap: 10px; color: #BFBFBF; cursor: pointer; user-select: none; margin-bottom: 4px;">
                            <input type="checkbox" class="checklist-item-checkbox" data-index="${index}" ${isChecked ? 'checked' : ''} onchange="App.handleChecklistItemChange('${nodeId}', ${index}, this)">
                            <span style="font-size: 0.8rem; text-align: left;">${item}</span>
                        </label>
                    `;
                });

                // Determine confirm button presence or standby volunteer button
                let confirmButtonHtml = '';
                const ownScale = uniqueScales.find(e => e.membroId === this.currentUser.id);
                if (ownScale) {
                    if (ownScale.statusPresenca === 'Pendente') {
                        confirmButtonHtml = `
                            <div style="width: 100%; display: flex; flex-direction: column; gap: 8px; margin-bottom: 15px;">
                                <button class="btn-primary confirm-pulse-btn" onclick="App.handleConfirmPresencaFromDetail('${ownScale.id}', 'Confirmada')" style="width: 100%; height: 50px; border-radius: 14px; background: linear-gradient(135deg, #10b981 0%, #059669 100%); color: #fff; font-weight: 800; font-size: 0.98rem; border: none; display: flex; align-items: center; justify-content: center; gap: 8px; box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.7); cursor: pointer; text-transform: uppercase; letter-spacing: 0.5px;">
                                    <i class="fa-solid fa-circle-check" style="font-size: 1.1rem;"></i> Confirmar Presença Agora
                                </button>
                                <button class="btn-secondary" onclick="App.handleConfirmPresencaFromDetail('${ownScale.id}', 'Recusada')" style="width: 100%; height: 38px; border-radius: 10px; border: 1px solid rgba(239, 68, 68, 0.2); background: rgba(239, 68, 68, 0.05); color: #ef4444; font-size: 0.8rem; font-weight: 600; cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 6px;">
                                    <i class="fa-solid fa-circle-xmark"></i> Não poderei comparecer
                                </button>
                            </div>
                        `;
                    } else if (ownScale.statusPresenca === 'Confirmada') {
                        confirmButtonHtml = `
                            <div style="width: 100%; display: flex; flex-direction: column; gap: 8px; margin-bottom: 15px;">
                                <div style="width: 100%; height: 46px; border-radius: 14px; border: 1.5px solid rgba(16, 185, 129, 0.4); background: rgba(16, 185, 129, 0.08); color: #10b981; font-weight: 800; font-size: 0.85rem; display: flex; align-items: center; justify-content: center; gap: 8px; letter-spacing: 0.5px; text-transform: uppercase;">
                                    <i class="fa-solid fa-check-double" style="font-size: 1rem;"></i> PRESENÇA CONFIRMADA
                                </div>
                                <button class="btn-secondary" onclick="App.handleConfirmPresencaFromDetail('${ownScale.id}', 'Recusada')" style="width: 100%; height: 38px; border-radius: 10px; border: 1px solid rgba(239, 68, 68, 0.2); background: rgba(239, 68, 68, 0.05); color: #ef4444; font-size: 0.8rem; font-weight: 600; cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 6px;">
                                    <i class="fa-solid fa-circle-xmark"></i> Não poderei comparecer
                                </button>
                            </div>
                        `;
                    }
                } else {
                    const ownStandby = areaStandbys.find(s => s.membroId === this.currentUser.id);
                    if (ownStandby) {
                        confirmButtonHtml = `
                            <div style="width: 100%; display: flex; flex-direction: column; gap: 8px; margin-bottom: 15px;">
                                <div style="width: 100%; height: 46px; border-radius: 14px; border: 1.5px dashed rgba(18, 115, 105, 0.4); background: rgba(18, 115, 105, 0.05); color: var(--theme-color); font-weight: 800; font-size: 0.82rem; display: flex; align-items: center; justify-content: center; gap: 8px; letter-spacing: 0.5px; text-transform: uppercase;">
                                    <i class="fa-solid fa-hand-holding-hand" style="font-size: 1rem;"></i> VOCÊ ESTÁ DISPONÍVEL COMO VOLUNTÁRIO
                                </div>
                                <button class="btn-secondary" onclick="App.handleCancelStandby('${ownStandby.id}', '${nodeId}')" style="width: 100%; height: 38px; border-radius: 10px; border: 1px solid rgba(239, 68, 68, 0.2); background: rgba(239, 68, 68, 0.05); color: #ef4444; font-size: 0.8rem; font-weight: 600; cursor: pointer;">
                                    <i class="fa-solid fa-trash-can"></i> Cancelar Disponibilidade
                                </button>
                            </div>
                        `;
                    } else {
                        const isUserScaledInThisCulto = escalas.some(escala => escala.cultoId === cultoId && escala.membroId === this.currentUser.id && escala.statusPresenca !== 'Recusada');
                        if (!isUserScaledInThisCulto) {
                            let roleSelectorHtml = '';
                            if (nodeId === 'recepcao') {
                                roleSelectorHtml = `
                                    <div style="margin-bottom: 12px; text-align: left; width: 100%;">
                                        <label style="font-size: 0.72rem; color: #8aa6a3; font-weight: 700; text-transform: uppercase; display: block; margin-bottom: 5px;"><i class="fa-solid fa-list-check" style="margin-right: 4px;"></i>Escolha a Função (Opcional):</label>
                                        <select id="standby-role-select" style="width: 100%; height: 38px; border-radius: 10px; background: rgba(0,0,0,0.3); border: 1px solid rgba(255,255,255,0.1); color: #fff; padding: 0 10px; font-size: 0.82rem; outline: none; cursor: pointer;">
                                            <option value="Recepção">Qualquer uma / Em aberto</option>
                                            <option value="Portaria">Portaria</option>
                                            <option value="Check-in">Check-in</option>
                                        </select>
                                    </div>
                                `;
                            } else if (nodeId === 'templo') {
                                roleSelectorHtml = `
                                    <div style="margin-bottom: 12px; text-align: left; width: 100%;">
                                        <label style="font-size: 0.72rem; color: #8aa6a3; font-weight: 700; text-transform: uppercase; display: block; margin-bottom: 5px;"><i class="fa-solid fa-map-pin" style="margin-right: 4px;"></i>Escolha o Lado (Opcional):</label>
                                        <select id="standby-role-select" style="width: 100%; height: 38px; border-radius: 10px; background: rgba(0,0,0,0.3); border: 1px solid rgba(255,255,255,0.1); color: #fff; padding: 0 10px; font-size: 0.82rem; outline: none; cursor: pointer;">
                                            <option value="Apoio Interno">Qualquer um / Em aberto</option>
                                            <option value="Apoio Interno (L. Dir.)">Lado Direito</option>
                                            <option value="Apoio Interno (L. Esq.)">Lado Esquerdo</option>
                                        </select>
                                    </div>
                                `;
                            } else if (nodeId === 'ronda') {
                                roleSelectorHtml = `
                                    <div style="margin-bottom: 12px; text-align: left; width: 100%;">
                                        <label style="font-size: 0.72rem; color: #8aa6a3; font-weight: 700; text-transform: uppercase; display: block; margin-bottom: 5px;"><i class="fa-solid fa-shield-halved" style="margin-right: 4px;"></i>Escolha o Lado (Opcional):</label>
                                        <select id="standby-role-select" style="width: 100%; height: 38px; border-radius: 10px; background: rgba(0,0,0,0.3); border: 1px solid rgba(255,255,255,0.1); color: #fff; padding: 0 10px; font-size: 0.82rem; outline: none; cursor: pointer;">
                                            <option value="Ronda">Qualquer um / Em aberto</option>
                                            <option value="Ronda (L. Dir.)">Lado Direito</option>
                                            <option value="Ronda (L. Esq.)">Lado Esquerdo</option>
                                        </select>
                                    </div>
                                `;
                            }

                            confirmButtonHtml = `
                                ${roleSelectorHtml}
                                <button class="btn-primary" onclick="App.handleRegisterStandby('${cultoId}', '${cultoNome.replace(/'/g, "\\'")}', '${dateStr}', '${horarioInicio} - ${horarioFim}', '${nodeId}')" style="width: 100%; height: 50px; border-radius: 14px; background: linear-gradient(135deg, var(--theme-color) 0%, #0d5e56 100%); color: #fff; font-weight: 800; font-size: 0.95rem; border: none; margin-bottom: 15px; display: flex; align-items: center; justify-content: center; gap: 8px; cursor: pointer; text-transform: uppercase;">
                                    <i class="fa-solid fa-hand-holding-hand" style="font-size: 1.1rem;"></i> Estou Disponível (Voluntário)
                                </button>
                            `;
                        } else {
                            confirmButtonHtml = `
                                <div style="width: 100%; height: 46px; border-radius: 14px; border: 1.5px solid rgba(138, 166, 163, 0.3); background: rgba(255,255,255,0.02); color: #8AA6A3; font-weight: 700; font-size: 0.82rem; margin-bottom: 15px; display: flex; align-items: center; justify-content: center; gap: 8px; text-transform: uppercase;">
                                    <i class="fa-solid fa-user-check"></i> Já escalado em outro setor/função
                                </div>
                            `;
                        }
                    }
                }

                // Calculate arrival time dynamically
                let arrivalTime = staticData.chegada;
                if (horarioInicio) {
                    try {
                        const [h, m] = horarioInicio.split(':').map(Number);
                        const offsetMinutes = staticData.chegada === '17:45' ? 15 : 30; // 15 mins before or 30 mins before
                        const date = new Date();
                        date.setHours(h);
                        date.setMinutes(m - offsetMinutes);
                        const arrivalH = String(date.getHours()).padStart(2, '0');
                        const arrivalM = String(date.getMinutes()).padStart(2, '0');
                        arrivalTime = `${arrivalH}:${arrivalM}`;
                    } catch (err) {}
                }

                let trajeHtml = '';
                if (staticData.traje) {
                    trajeHtml = `
                        <div style="display: flex; justify-content: space-between; align-items: center; padding-bottom: 2px;">
                            <span style="color: #8AA6A3; display: flex; align-items: center; gap: 8px;"><i class="fa-solid fa-shirt" style="width: 14px;"></i> Traje</span>
                            <span style="color: #fff; font-weight: 600;">${staticData.traje}</span>
                        </div>
                    `;
                }

                detailContainer.innerHTML = `
                    <header class="detail-header">
                        <button onclick="App.closeAreaDetail()" class="btn-icon" style="background: none; border: none; color: #fff; font-size: 1.1rem; cursor: pointer; display: flex; align-items: center; justify-content: center; width: 32px; height: 32px;">
                            <i class="fa-solid fa-arrow-left"></i>
                        </button>
                        <span class="detail-header-title">${areaTitle}</span>
                        <button class="btn-icon" style="background: none; border: none; color: #fff; font-size: 1.1rem; cursor: pointer; display: flex; align-items: center; justify-content: center; width: 32px; height: 32px;">
                            <i class="fa-solid fa-ellipsis"></i>
                        </button>
                    </header>

                    <div class="detail-area-banner card-${nodeId}">
                        <div class="org-area-pattern-overlay"></div>
                        <div style="display: flex; align-items: center; gap: 15px; z-index: 1; position: relative;">
                            <div class="org-area-icon-wrap-premium" style="width: 50px; height: 50px; font-size: 1.4rem;">
                                <i class="${iconClass}"></i>
                            </div>
                            <div style="text-align: left;">
                                <h2 style="font-size: 1.3rem; font-weight: 800; color: #fff; margin: 0; text-transform: uppercase; letter-spacing: -0.2px;">${areaTitle}</h2>
                                <p style="font-size: 0.8rem; color: #BFBFBF; margin-top: 2px; font-weight: 500;">${cultoNome}</p>
                                <p style="font-size: 0.75rem; color: #8AA6A3; margin-top: 1px; font-weight: 500;"><i class="fa-regular fa-clock" style="margin-right: 4px;"></i> ${horarioInicio} às ${horarioFim}</p>
                            </div>
                        </div>
                    </div>

                    <div class="status-box ${statusClassBox}">
                        <span style="width: 8px; height: 8px; border-radius: 50%; background: ${statusDotColor}; display: inline-block; box-shadow: 0 0 8px ${statusDotColor};"></span>
                        <div style="text-align: left;">
                            <div style="font-weight: 700; color: #fff;">${statusTitle}</div>
                            <div style="font-size: 0.72rem; color: #BFBFBF; font-weight: 500; margin-top: 1px;">${statusDesc}</div>
                        </div>
                    </div>

                    <div class="panel-card" style="margin-bottom: 12px; text-align: left; padding: 15px;">
                        <div style="display: flex; align-items: flex-start; justify-content: space-between; gap: 12px;">
                            <div style="flex: 1;">
                                <div style="font-size: 0.85rem; font-weight: 700; color: #fff; margin-bottom: 4px;">Objetivo da área</div>
                                <div style="font-size: 0.75rem; color: #BFBFBF; line-height: 1.4;">${staticData.objetivo}</div>
                            </div>
                            <div style="font-size: 1rem; color: var(--theme-color); opacity: 0.8;">
                                <i class="fa-solid fa-bullseye"></i>
                            </div>
                        </div>
                    </div>

                    <div class="panel-card" style="margin-bottom: 12px; text-align: left; padding: 15px;">
                        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;">
                            <span style="font-size: 0.85rem; font-weight: 700; color: #fff;">Equipe escalada</span>
                            <span style="font-size: 0.72rem; color: var(--theme-color); font-weight: 700; cursor: pointer;">Ver todos</span>
                        </div>
                        <div class="detail-team-list">
                            ${teamListHtml}
                        </div>
                    </div>

                    ${standbysHtml}

                    ${confirmButtonHtml}

                    <div class="panel-card" style="margin-bottom: 12px; text-align: left; padding: 15px;">
                        <div style="font-size: 0.85rem; font-weight: 700; color: #fff; margin-bottom: 10px;">Informações importantes</div>
                        <div style="display: flex; flex-direction: column; gap: 10px; font-size: 0.78rem;">
                            <div style="display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid rgba(255,255,255,0.05); padding-bottom: 8px;">
                                <span style="color: #8AA6A3; display: flex; align-items: center; gap: 8px;"><i class="fa-solid fa-location-dot" style="width: 14px;"></i> Local</span>
                                <span style="color: #fff; font-weight: 600;">${staticData.local}</span>
                            </div>
                            <div style="display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid rgba(255,255,255,0.05); padding-bottom: 8px;">
                                <span style="color: #8AA6A3; display: flex; align-items: center; gap: 8px;"><i class="fa-solid fa-user-tie" style="width: 14px;"></i> Supervisor</span>
                                <span style="color: #fff; font-weight: 600;">${staticData.supervisor}</span>
                            </div>
                            <div style="display: flex; justify-content: space-between; align-items: center; ${staticData.traje ? 'border-bottom: 1px solid rgba(255,255,255,0.05); padding-bottom: 8px;' : 'padding-bottom: 2px;'}">
                                <span style="color: #8AA6A3; display: flex; align-items: center; gap: 8px;"><i class="fa-regular fa-clock" style="width: 14px;"></i> Chegada</span>
                                <span style="color: #fff; font-weight: 600;">${arrivalTime}</span>
                            </div>
                            ${trajeHtml}
                        </div>
                    </div>

                    <div class="panel-card" style="margin-bottom: 15px; text-align: left; padding: 15px;">
                        <div style="font-size: 0.85rem; font-weight: 700; color: #fff; margin-bottom: 10px;">Checklist da área</div>
                        <div style="display: flex; flex-direction: column; gap: 6px;">
                            ${checklistHtml}
                        </div>
                    </div>

                    <div style="display: flex; gap: 10px; margin-bottom: 20px;">
                        <button class="btn-secondary" onclick="App.showAreaInstructions('${nodeId}')" style="flex: 1; height: 44px; border-radius: 12px; border: 1px solid rgba(255,255,255,0.08); background: rgba(255,255,255,0.02); color: #fff; font-size: 0.78rem; font-weight: 600; display: flex; align-items: center; justify-content: center; gap: 6px; cursor: pointer;">
                            <i class="fa-regular fa-file-lines"></i> Ver instruções
                        </button>
                        <button class="btn-secondary" onclick="App.requestAreaHelp('${nodeId}')" style="flex: 1; height: 44px; border-radius: 12px; border: 1px solid rgba(255,255,255,0.08); background: rgba(255,255,255,0.02); color: #fff; font-size: 0.78rem; font-weight: 600; display: flex; align-items: center; justify-content: center; gap: 6px; cursor: pointer;">
                            <i class="fa-solid fa-headset"></i> Solicitar ajuda
                        </button>
                    </div>
                `;
            } catch (err) {
                console.error(err);
                this.showToast('Erro ao carregar detalhes.', 'danger');
                this.closeAreaDetail();
            }
        }, 50);
    },

    closeAreaDetail() {
        document.getElementById('member-sub-area-detail').style.display = 'none';
        document.getElementById('member-sub-escala').style.display = 'block';
        const memberHeader = document.querySelector('.member-header');
        if (memberHeader) memberHeader.style.display = 'flex';
    },

    handleChecklistItemChange(nodeId, index, element) {
        const activeEventKey = this.memberSelectedEventKey;
        if (!activeEventKey) return;
        const key = `diaconia_checklist_${activeEventKey}_${nodeId}`;
        const savedChecklistStr = localStorage.getItem(key);
        const savedChecklist = savedChecklistStr ? JSON.parse(savedChecklistStr) : {};
        savedChecklist[index] = element.checked;
        localStorage.setItem(key, JSON.stringify(savedChecklist));
    },

    async handleConfirmPresencaFromDetail(escalaId, status) {
        try {
            await DbService.updatePresenca(escalaId, status);
            if (status === 'Confirmada') {
                this.showToast(`Presença confirmada com sucesso!`, 'success');
            } else if (status === 'Recusada') {
                this.showToast(`Escala recusada. O sistema tentará substituição automática.`, 'info');
                // Trigger auto-substitution
                await this.tentarSubstituicaoAutomatica(escalaId);
            } else {
                this.showToast(`Presença atualizada com sucesso!`, 'success');
            }
            await this.loadAndRenderMemberScales();
            this.closeAreaDetail();
        } catch (e) {
            this.showAlert('Erro ao atualizar presença no servidor.', 'Erro');
        }
    },



    showAreaInstructions(nodeId) {
        const staticData = this.areaStaticData[nodeId];
        const instr = staticData ? staticData.instrucoes : 'Instruções padrão da área.';
        this.showAlert(instr, 'Instruções da Área');
    },

    requestAreaHelp(nodeId) {
        this.showToast('Solicitação de ajuda enviada ao supervisor!', 'success');
    },

    getCardAvatarHtml(name, fotoUrl, zIndex = 1) {
        const directUrl = this.getDirectPhotoUrl(fotoUrl);
        if (directUrl) {
            return `
                <div class="org-card-avatar" style="z-index: ${zIndex};">
                    <img src="${directUrl}" alt="${name || ''}">
                </div>
            `;
        }
        if (!name) {
            return `<div class="org-card-avatar vacant" style="z-index: ${zIndex};"><i class="fa-solid fa-user"></i></div>`;
        }
        const initials = name.split(' ').filter(n => n.length > 0).map(n => n[0]).slice(0, 2).join('').toUpperCase();
        
        let hash = 0;
        for (let i = 0; i < name.length; i++) {
            hash = name.charCodeAt(i) + ((hash << 5) - hash);
        }
        const colors = ['#127369', '#10403B', '#8AA6A3', '#4C5958', '#D9A752'];
        const color = colors[Math.abs(hash) % colors.length];

        return `
            <div class="org-card-avatar" style="background-color: ${color}; z-index: ${zIndex};">
                ${initials}
            </div>
        `;
    },

    getDirectPhotoUrl(url) {
        if (!url) return null;
        // Match Google Drive file sharing links
        const driveMatch = url.match(/drive\.google\.com\/file\/d\/([a-zA-Z0-9_-]+)/);
        if (driveMatch && driveMatch[1]) {
            return `https://lh3.googleusercontent.com/d/${driveMatch[1]}`;
        }
        const driveOpenMatch = url.match(/drive\.google\.com\/open\?id=([a-zA-Z0-9_-]+)/);
        if (driveOpenMatch && driveOpenMatch[1]) {
            return `https://lh3.googleusercontent.com/d/${driveOpenMatch[1]}`;
        }
        return url;
    },

    isFemale(fullName) {
        if (!fullName) return false;
        const firstName = fullName.trim().split(' ')[0].toLowerCase();
        
        // Explicit female names in the system or common
        const femaleNames = ['debora', 'monica', 'maria', 'thaiza', 'ana', 'veronica', 'thainara', 'agda', 'verônica', 'mônica', 'débora', 'verônica', 'thaíza'];
        if (femaleNames.includes(firstName)) return true;
        
        // Male exceptions ending in 'a'
        const maleExceptions = ['luca', 'lucas', 'joshua', 'andrea', 'eneas', 'esdras', 'messias', 'matias', 'nataniel', 'gabriel'];
        if (maleExceptions.includes(firstName)) return false;
        
        // If it ends with "a", it's likely female
        return firstName.endsWith('a');
    },

    isMembroDisponivel(m, data, horarioInicio) {
        if (!m || m.status !== 'ativo' || m.perfil === 'admin') return false;
        
        // 1. Verificar afastamento temporário / férias
        const checkDate = data || new Date().toISOString().split('T')[0];
        
        if (m.afastamentoInicio && m.afastamentoFim) {
            // Membro tem período de afastamento definido
            if (checkDate >= m.afastamentoInicio && checkDate <= m.afastamentoFim) {
                return false; // Afastado no período (afetando escala manual, automática e preditiva)
            }
            if (checkDate > m.afastamentoFim) {
                const autoRetorno = m.afastamentoRetornoAutomativo === 'Sim' || m.afastamentoRetornoAutomativo === true;
                // Se não tem retorno automático E o status ainda consta como inativo/afastado
                if (!autoRetorno && m.statusOperacional && m.statusOperacional !== 'Disponível') {
                    return false; // Período expirou mas aguarda confirmação da supervisão
                }
            }
        } else if (m.statusOperacional && m.statusOperacional !== 'Disponível') {
            // Sem datas definidas mas marcado como inativo/afastado
            return false;
        }
        
        // 2. Verificar indisponibilidade declarada para o dia específico (Portal do Obreiro)
        if (data && m.indisponibilidades_mensais && m.indisponibilidades_mensais[data]) {
            if (m.indisponibilidades_mensais[data] === 'nao_posso') {
                return false;
            }
        }
        
        // 3. Verificar disponibilidade por turno (Domingo Manhã / Noite / Eventos Especiais / Todos)
        if (data) {
            const dateObj = new Date(data + 'T12:00:00'); // Evita timezone offset
            const dayOfWeek = dateObj.getDay(); // 0 = Domingo, 1 = Segunda, etc.
            
            const dispRaw = m.disponibilidade || 'Todos';
            const dispNorm = dispRaw.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
            
            // É considerado "Todos" se contiver as palavras chaves de disponibilidade geral
            const isTodos = dispNorm.includes('todos') || 
                            dispNorm.includes('todo culto') || 
                            dispNorm.includes('dias de culto') ||
                            dispNorm.includes('sempre disponivel') ||
                            dispNorm.includes('disponivel para escala') ||
                            dispNorm.includes('consultar primeiro');
            
            if (dayOfWeek === 0) { // Domingo
                const hour = parseInt((horarioInicio || '09:00').split(':')[0], 10);
                const isMorning = hour < 13;
                if (isMorning) {
                    if (!isTodos && dispRaw !== 'Domingo Manhã') {
                        return false;
                    }
                } else {
                    if (!isTodos && dispRaw !== 'Domingo Noite') {
                        return false;
                    }
                }
            } else { // Dia de semana
                if (!isTodos && dispRaw !== 'Eventos Especiais') {
                    return false;
                }
            }
        }
        
        return true;
    },

    toggleOrgEventsList() {
        const listEl = document.getElementById('org-events-list-scroll');
        const chevronEl = document.getElementById('org-banner-chevron');
        if (listEl && chevronEl) {
            if (listEl.style.display === 'none') {
                listEl.style.display = 'block';
                chevronEl.className = 'fa-solid fa-chevron-up';
            } else {
                listEl.style.display = 'none';
                chevronEl.className = 'fa-solid fa-chevron-down';
            }
        }
    },

    toggleNodeDetail(nodeId) {
        const detailEl = document.getElementById(`org-detail-${nodeId}`);
        const chevronEl = document.getElementById(`org-chevron-${nodeId}`);
        if (detailEl && chevronEl) {
            const isShow = detailEl.classList.toggle('show');
            const parentCard = chevronEl.closest('.org-node-card-horizontal');
            if (isShow) {
                chevronEl.style.transform = 'rotate(90deg)';
                if (parentCard) {
                    parentCard.style.borderBottomLeftRadius = '0';
                    parentCard.style.borderBottomRightRadius = '0';
                }
            } else {
                chevronEl.style.transform = 'none';
                if (parentCard) {
                    // Restore border radius after transition or immediately
                    parentCard.style.borderBottomLeftRadius = '16px';
                    parentCard.style.borderBottomRightRadius = '16px';
                }
            }
        }
    },

    showNodeLocationInfo(nodeId, side) {
        let message = `Este posto de trabalho está posicionado no ${side} do templo.`;
        if (nodeId.includes('apoio')) {
            message = `O posto de Apoio ao Templo nesta escala fica localizado no ${side} (em relação ao altar/púlpito).`;
        } else if (nodeId.includes('ronda')) {
            message = `O posto de Ronda do Templo nesta escala é responsável por cobrir a área do ${side} do templo.`;
        }
        this.showAlert(message, 'Localização do Posto');
    },

    refreshActiveScaleView() {
        console.log("DEBUG: refreshActiveScaleView called");
        this.showingMonthlyCalendar = false;
        const memberView = document.getElementById('view-member');
        if (memberView && memberView.classList.contains('active')) {
            this.loadAndRenderMemberScales();
        } else {
            this.renderSectorSelectionScreen();
        }
    },

    selectMemberOrganogramEvent(eventKey) {
        this.memberSelectedEventKey = eventKey;
        this.refreshActiveScaleView();
    },

    navigateOrgEvent(direction) {
        if (!this.memberDiaconiaEventsList || this.memberDiaconiaEventsList.length === 0) {
            // Shift month if there are no events in current month
            this.memberCurrentDate.setMonth(this.memberCurrentDate.getMonth() + direction);
            this.memberSelectedEventKey = null;
            this.refreshActiveScaleView();
            return;
        }
        
        let currentIndex = this.memberDiaconiaEventsList.findIndex(e => e.key === this.memberSelectedEventKey);
        if (currentIndex === -1) currentIndex = 0;
        
        let newIndex = currentIndex + direction;
        if (newIndex >= 0 && newIndex < this.memberDiaconiaEventsList.length) {
            const newEvent = this.memberDiaconiaEventsList[newIndex];
            this.memberSelectedEventKey = newEvent.key;
            const dateParts = newEvent.data.split('-');
            this.memberCurrentDate = new Date(dateParts[0], dateParts[1] - 1, dateParts[2]);
            this.refreshActiveScaleView();
        } else {
            // Shift month and auto-select next month's events
            this.memberCurrentDate.setMonth(this.memberCurrentDate.getMonth() + direction);
            this.memberSelectedEventKey = null;
            this.refreshActiveScaleView();
        }
    },


    changeMemberCalendarMonth(offset) {
        this.memberCurrentDate.setMonth(this.memberCurrentDate.getMonth() + offset);
        this.memberSelectedEventKey = null;
        this.showMonthlyCalendar();
    },

    changeAdminCalendarMonth(offset) {
        if (!this.adminCalendarDate) {
            this.adminCalendarDate = new Date();
        }
        this.adminCalendarDate.setMonth(this.adminCalendarDate.getMonth() + offset);
        this.renderPremiumCalendar(true);
    },

    showAdminCalendarOnly() {
        const calContainer = document.getElementById('admin-calendar-view-container');
        const detailContainer = document.getElementById('admin-selected-culto-section');
        const opContainer = document.getElementById('admin-escalas-operacionais-container');
        if (calContainer && detailContainer) {
            if (this.activeEscalasSubTab !== 'operacionais') {
                calContainer.style.display = 'block';
            }
            detailContainer.style.display = 'none';
        }
        
        if (opContainer && this.activeEscalasSubTab === 'operacionais') {
            opContainer.style.display = 'block';
            this.renderEscalasOperacionais();
        }
        
        // Remove selections from calendar event pills
        document.querySelectorAll('.calendar-event-pill').forEach(pill => {
            pill.style.boxShadow = '';
            pill.style.fontWeight = '700';
        });
        
        this.adminSelectedCultoId = null;
    },

    async renderPremiumCalendar(isAdminMode = false) {
        console.log("DEBUG: [renderPremiumCalendar] INÍCIO DA FUNÇÃO - isAdminMode:", isAdminMode);
        let container = null;
        let baseDate = null;
        
        try {
            if (isAdminMode) {
                container = document.getElementById('admin-calendar-container');
                if (!this.adminCalendarDate) {
                    this.adminCalendarDate = new Date();
                }
                baseDate = new Date(this.adminCalendarDate);
            } else {
                container = document.getElementById('member-scales-list');
                baseDate = new Date(this.memberCurrentDate);
            }
            
            console.log("DEBUG: [renderPremiumCalendar] ID do container encontrado:", container ? container.id : 'NENHUM_CONTAINER');
            
            if (!container) {
                console.log("DEBUG: [renderPremiumCalendar] Container é nulo/undefined, retornando.");
                return;
            }
            
            if (isAdminMode) {
                container.innerHTML = `<div style="padding: 20px; color: var(--slate-gray); text-align: center;"><i class="fa-solid fa-spinner fa-spin" style="margin-right: 8px;"></i>Carregando calendário administrativo...</div>`;
            }
            
            const year = baseDate.getFullYear();
            const month = baseDate.getMonth();
            const monthLabel = baseDate.toLocaleDateString('pt-BR', { month: 'long', year: 'numeric' });
            
            // Fetch all cultos for the calendar month (expanding range to avoid time zone cutting)
            const fetchStart = new Date(year, month - 1, 1);
            const fetchEnd = new Date(year, month + 2, 0);
            
            const startStr = this.formatLocalISOString(fetchStart).split('T')[0];
            const endStr = this.formatLocalISOString(fetchEnd).split('T')[0];
            
            let cultos = [];
            try {
                cultos = await DbService.getCultos(startStr, endStr);
                console.log("DEBUG: [renderPremiumCalendar] quantidade de cultos:", cultos ? cultos.length : 0);
            } catch (e) {
                console.error("DEBUG: [renderPremiumCalendar] Erro ao obter cultos:", e);
            }
            
            let escalas = [];
            try {
                escalas = await DbService.getEscalas();
                console.log("DEBUG: [renderPremiumCalendar] quantidade de escalas:", escalas ? escalas.length : 0);
            } catch (e) {
                console.error("DEBUG: [renderPremiumCalendar] Erro ao obter escalas:", e);
            }
            
            // Group cultos by day number (only if they belong to the currently viewed month and year)
            const cultosByDay = {};
            if (cultos && Array.isArray(cultos)) {
                cultos.forEach(c => {
                    if (!c.data) {
                        console.warn("DEBUG: [renderPremiumCalendar] Culto sem data encontrado:", c);
                        return;
                    }
                    const dateParts = c.data.split('-');
                    if (dateParts.length < 3) {
                        console.warn("DEBUG: [renderPremiumCalendar] Culto com formato de data inválido:", c.data);
                        return;
                    }
                    const cYear = parseInt(dateParts[0], 10);
                    const cMonth = parseInt(dateParts[1], 10) - 1; // 0-indexed
                    const dayNum = parseInt(dateParts[2], 10);
                    
                    if (cYear === year && cMonth === month) {
                        if (!cultosByDay[dayNum]) {
                            cultosByDay[dayNum] = [];
                        }
                        cultosByDay[dayNum].push(c);
                    }
                });
            } else {
                console.warn("DEBUG: [renderPremiumCalendar] cultos não é um array válido:", cultos);
            }
            
            // Calcule o primeiro dia e a quantidade de dias correta do mês visualizado
            const firstDayOfCurrentMonth = new Date(year, month, 1);
            const lastDayOfCurrentMonth = new Date(year, month + 1, 0);
            
            const firstDayIndex = firstDayOfCurrentMonth.getDay();
            const totalDays = lastDayOfCurrentMonth.getDate();
            
            let gridHtml = '';
            
            // Empty cells before the first day
            for (let i = 0; i < firstDayIndex; i++) {
                gridHtml += `<div class="calendar-cell-full empty"></div>`;
            }
            
            // Days of the month
            for (let day = 1; day <= totalDays; day++) {
                const dateStr = `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
                const dayOfWeek = new Date(year, month, day).getDay();
                
                // Map day of week to CSS classes
                const dayClasses = ['day-dom', 'day-seg', 'day-ter', 'day-qua', 'day-qui', 'day-sex', 'day-sab'];
                const dayClass = dayClasses[dayOfWeek];
                
                const dayCultos = cultosByDay[day] || [];
                let cultosHtml = '';
                
                dayCultos.forEach(c => {
                    const formattedHour = (() => {
                        if (!c.horarioInicio) return '';
                        const parts = c.horarioInicio.split(':');
                        const h = parseInt(parts[0], 10);
                        const m = parseInt(parts[1], 10);
                        return m === 0 ? `${h}H` : `${h}H${String(m).padStart(2, '0')}`;
                    })();
                    
                    let clickHandler = '';
                    if (isAdminMode) {
                        clickHandler = `onclick="event.stopPropagation(); App.selectAdminCulto('${c.id}')"`;
                    } else {
                        const eventKey = `${c.data}_${c.id}_${c.horarioInicio}`;
                        clickHandler = `onclick="event.stopPropagation(); App.selectMemberOrganogramEvent('${eventKey}')"`;
                    }
                    
                    // Add active style if selected
                    let activeStyle = '';
                    if (isAdminMode && c.id === this.adminSelectedCultoId) {
                        activeStyle = 'box-shadow: 0 0 0 2px var(--teal-primary) !important; font-weight: 800;';
                    }
                    
                    cultosHtml += `
                        <div class="calendar-event-pill" ${clickHandler} style="${activeStyle}" title="${c.nome} - ${c.horarioInicio}">
                            ${formattedHour}: ${c.nome}
                        </div>
                    `;
                });
                
                gridHtml += `
                    <div class="calendar-cell-full ${dayClass}">
                        <span class="day-num">${day}</span>
                        <div class="calendar-events-container">
                            ${cultosHtml}
                        </div>
                    </div>
                `;
            }
            
            const prevMonthClick = isAdminMode 
                ? `onclick="App.changeAdminCalendarMonth(-1)"`
                : `onclick="App.changeMemberCalendarMonth(-1)"`;
                
            const nextMonthClick = isAdminMode
                ? `onclick="App.changeAdminCalendarMonth(1)"`
                : `onclick="App.changeMemberCalendarMonth(1)"`;
                
            const backButtonHtml = isAdminMode ? '' : `
                <div class="calendar-back-action-bar">
                    <button class="calendar-back-btn" onclick="App.refreshActiveScaleView()">
                        <i class="fa-solid fa-arrow-left"></i> Voltar
                    </button>
                </div>
            `;
            
            const calendarHtml = `
                <div class="premium-full-calendar animate-fade-in">
                    <div class="calendar-month-nav">
                        <button ${prevMonthClick}><i class="fa-solid fa-chevron-left"></i></button>
                        <h4>${monthLabel.toUpperCase()}</h4>
                        <button ${nextMonthClick}><i class="fa-solid fa-chevron-right"></i></button>
                    </div>
                    
                    <div class="calendar-grid-full">
                        <div class="calendar-header-day">Dom</div>
                        <div class="calendar-header-day">Seg</div>
                        <div class="calendar-header-day">Ter</div>
                        <div class="calendar-header-day">Qua</div>
                        <div class="calendar-header-day">Qui</div>
                        <div class="calendar-header-day">Sex</div>
                        <div class="calendar-header-day">Sáb</div>
                        
                        ${gridHtml}
                    </div>
                    
                    ${backButtonHtml}
                </div>
            `;
            
            console.log("DEBUG: [renderPremiumCalendar] antes de montar o HTML");
            container.innerHTML = calendarHtml;
            console.log("DEBUG: [renderPremiumCalendar] depois de inserir o HTML");
            
            // Log computed dimensions and styles to check if they are hidden
            const rect = container.getBoundingClientRect();
            const computedStyle = window.getComputedStyle(container);
            console.log("DEBUG: [renderPremiumCalendar] Container dimensions:", rect.width, "x", rect.height, "visible:", computedStyle.display, "visibility:", computedStyle.visibility, "opacity:", computedStyle.opacity);
            
            const parent = document.getElementById('admin-calendar-view-container');
            if (parent) {
                const pRect = parent.getBoundingClientRect();
                const pStyle = window.getComputedStyle(parent);
                console.log("DEBUG: [renderPremiumCalendar] Parent dimensions:", pRect.width, "x", pRect.height, "visible:", pStyle.display, "visibility:", pStyle.visibility, "opacity:", pStyle.opacity);
            }
            
            const subEscalas = document.getElementById('admin-sub-escalas');
            if (subEscalas) {
                const sRect = subEscalas.getBoundingClientRect();
                const sStyle = window.getComputedStyle(subEscalas);
                console.log("DEBUG: [renderPremiumCalendar] Sub-view dimensions:", sRect.width, "x", sRect.height, "visible:", sStyle.display, "visibility:", sStyle.visibility, "opacity:", sStyle.opacity);
            }
        } catch (e) {
            console.error("DEBUG: [renderPremiumCalendar] CATCH COM ERRO COMPLETO:", e);
        }
    },

    renderScaleActionsForNode(scales) {
        const ownScale = scales.find(e => e.membroId === this.currentUser.id);
        if (!ownScale) return '';

        let actionButtonsHtml = '';
        if (ownScale.statusPresenca === 'Pendente') {
            actionButtonsHtml = `
                <div class="card-scale-actions" style="margin-top: 10px; justify-content: center; width: 100%;">
                    <button class="btn-scale-action btn-recusar-presenca" onclick="App.handleConfirmPresenca('${ownScale.id}', 'Recusada')">
                        <i class="fa-solid fa-xmark"></i> Recusar
                    </button>
                    <button class="btn-scale-action btn-confirm-presenca" onclick="App.handleConfirmPresenca('${ownScale.id}', 'Confirmada')">
                        <i class="fa-solid fa-check"></i> Confirmar
                    </button>
                </div>
            `;
        }

        let serviceControlHtml = '';
        if (ownScale.statusPresenca === 'Confirmada') {
            if (ownScale.statusServico === 'Agendado') {
                serviceControlHtml = `
                    <div style="margin-top: 10px; width: 100%;">
                        <button class="btn-service-control btn-start-work" style="width: 100%; justify-content: center;" onclick="App.handleStartService('${ownScale.id}', '${ownScale.funcao}', '${ownScale.data}', '${ownScale.horarioInicio}', '${ownScale.horarioFim}')">
                            <i class="fa-solid fa-play"></i> Iniciar Trabalho
                        </button>
                    </div>
                `;
            } else if (ownScale.statusServico === 'Em andamento') {
                serviceControlHtml = `
                    <div style="margin-top: 10px; width: 100%;">
                        <button class="btn-service-control btn-finish-work" style="width: 100%; justify-content: center;" onclick="App.handleFinishServiceModal('${ownScale.id}')">
                            <i class="fa-solid fa-circle-stop"></i> Finalizar Trabalho
                        </button>
                    </div>
                `;
            }
        }

        return actionButtonsHtml + serviceControlHtml;
    },

    async handleConfirmPresenca(escalaId, status) {
        try {
            await DbService.updatePresenca(escalaId, status);
            if (status === 'Confirmada') {
                this.showToast(`Presença confirmada com sucesso!`, 'success');
            } else if (status === 'Recusada') {
                this.showToast(`Escala recusada. O sistema tentará substituição automática.`, 'info');
                // Trigger auto-substitution
                await this.tentarSubstituicaoAutomatica(escalaId);
            } else {
                this.showToast(`Presença atualizada com sucesso!`, 'success');
            }
            this.loadAndRenderMemberScales();
            // Re-evaluate notification reminders (both pending and confirmed tomorrow)
            // runNotificationChecks removed (function deprecated)
        } catch (e) {
            this.showAlert('Erro ao atualizar presença no servidor.', 'Erro');
        }
    },

    async confirmarPresencaDireto(escalaId, data) {
        try {
            App.showLoading();
            await DbService.updatePresenca(escalaId, 'Confirmada');
            App.hideLoading();
            this.showToast(`Presença confirmada com sucesso!`, 'success');
            this.loadAndRenderMemberScales();
            // runNotificationChecks removed (function deprecated)
        } catch (e) {
            App.hideLoading();
            console.error("Erro em confirmarPresencaDireto:", e);
            this.showAlert('Erro ao confirmar presença no servidor.', 'Erro');
        }
    },

    async handleStartService(escalaId, funcao, data, horaIni, horaFim) {
        try {
            const servicoId = await DbService.iniciarServico(
                escalaId,
                this.currentUser.id,
                this.currentUser.nome,
                this.activeSectorId,
                funcao,
                data,
                horaIni,
                horaFim
            );
            // Save active service ID to local session
            localStorage.setItem(`active_service_${escalaId}`, servicoId);
            this.toggleBottomNav(false); // Modo Imersivo: Plantão Iniciado
            this.showToast('Serviço iniciado! Bom trabalho.', 'success');
            if (this.isOperationalSector(this.activeSectorId)) {
                this.renderOperacionalDashboard();
            } else {
                this.loadAndRenderMemberScales();
            }
        } catch (e) {
            this.showAlert('Erro ao iniciar o serviço no banco.', 'Erro');
        }
    },

    confirmFinishService(servicoId, escalaId) {
        if (!servicoId) return;
        document.getElementById('fechamento-servico-id').value = servicoId;
        document.getElementById('fechamento-escala-id').value = (escalaId && escalaId !== 'undefined') ? escalaId : 'extra';
        document.getElementById('fechamento-observacoes').value = '';
        document.getElementById('modal-servico-fechamento').classList.add('active');
    },

    confirmFinishServiceWithChecklist(servicoId, escalaId) {
        if (!servicoId) return;
        
        const checkboxes = document.querySelectorAll('.op-check-item');
        const checkedItems = [];
        checkboxes.forEach(cb => {
            if (cb.checked) {
                checkedItems.push(cb.value);
            }
        });
        
        let obsAdicional = '';
        if (checkedItems.length > 0) {
            obsAdicional = "Checklist realizado:\\n- " + checkedItems.join("\\n- ");
        } else {
            obsAdicional = "Nenhum item do checklist diário foi marcado.";
        }
        
        document.getElementById('fechamento-servico-id').value = servicoId;
        document.getElementById('fechamento-escala-id').value = (escalaId && escalaId !== 'undefined') ? escalaId : 'extra';
        document.getElementById('fechamento-observacoes').value = obsAdicional;
        document.getElementById('modal-servico-fechamento').classList.add('active');
    },

    handleFinishServiceModal(escalaId) {
        const servicoId = localStorage.getItem(`active_service_${escalaId}`);
        if (!servicoId) {
            // Fallback: search Firestore active services
            this.showAlert('Houve um problema de sincronização. Por favor, reinicie e tente novamente.');
            return;
        }

        document.getElementById('fechamento-servico-id').value = servicoId;
        document.getElementById('fechamento-escala-id').value = escalaId;
        document.getElementById('fechamento-observacoes').value = '';
        
        document.getElementById('modal-servico-fechamento').classList.add('active');
    },

    closeServicoFechamentoModal() {
        document.getElementById('modal-servico-fechamento').classList.remove('active');
    },

    async handleServicoFechamentoSubmit(event) {
        event.preventDefault();
        const servicoId = document.getElementById('fechamento-servico-id').value;
        const escalaId = document.getElementById('fechamento-escala-id').value;
        const obs = document.getElementById('fechamento-observacoes').value.trim();

        try {
            await DbService.finalizarServico(servicoId, escalaId, obs);
            localStorage.removeItem(`active_service_${escalaId}`);
            this.toggleBottomNav(true); // Modo Imersivo: Plantão Encerrado
            
            // [Automação do Mural] Evento de fim de limpeza
            if (this.isOperationalSector(this.activeSectorId)) {
                await this.triggerMuralLimpeza(escalaId);
            }
            
            this.closeServicoFechamentoModal();
            this.showToast('Trabalho concluído e presença registrada!', 'success');
            
            if (this.isOperationalSector(this.activeSectorId)) {
                this.renderOperacionalDashboard();
            } else {
                this.loadAndRenderMemberScales();
            }
        } catch (e) {
            this.showAlert('Erro ao gravar encerramento de serviço.', 'Erro');
        }
    },

    getPresenceBadgeHtml(statusPresenca) {
        if (statusPresenca === 'Confirmada') {
            return `<span class="badge badge-active">Trabalhou</span>`;
        }
        if (statusPresenca === 'Recusada') {
            return `<span class="badge" style="background:#FEE2E2; color:#B91C1C; font-weight:500;">Recusada</span>`;
        }
        if (statusPresenca === 'Ausente') {
            return `<span class="badge" style="background:#FEF2F2; color:#EF4444; border: 1px solid #FCA5A5; font-weight:500;">Faltou</span>`;
        }
        if (statusPresenca === 'Justificado') {
            return `<span class="badge" style="background:#FEF3C7; color:#D97706; border: 1px solid #FCD34D; font-weight:500;">Justificado</span>`;
        }
        if (statusPresenca === 'Substituido') {
            return `<span class="badge" style="background:#E2E8F0; color:#475569; font-weight:500;">Substituído</span>`;
        }
        return `<span class="badge badge-inactive">Pendente</span>`;
    },

    async openFechamentoCultoModal() {
        this.toggleBottomNav(false); // Modo Imersivo: Fechamento de Culto
        if (!this.adminSelectedCultoId) {
            this.showToast('Por favor, selecione um culto primeiro.', 'warning');
            return;
        }

        try {
            document.getElementById('fechamento-culto-id').value = this.adminSelectedCultoId;
            const container = document.getElementById('fechamento-membros-lista');
            container.innerHTML = '<div style="text-align:center; padding:20px;"><i class="fa-solid fa-spinner fa-spin fa-lg" style="color:var(--teal-primary);"></i><p style="margin-top:10px; font-size:0.85rem; color:#64748B;">Buscando membros...</p></div>';
            
            const c = this.cultosData.find(item => item.id === this.adminSelectedCultoId);
            const detailsDiv = document.getElementById('fechamento-culto-detalhes');
            if (c && detailsDiv) {
                const dataFmt = c.data ? c.data.split('-').reverse().join('/') : '';
                detailsDiv.innerText = `${c.nome} • ${dataFmt} • ${c.horarioInicio}`;
            }

            document.getElementById('modal-culto-fechamento').classList.add('active');

            const escalas = await DbService.getEscalas(null, null, null, this.adminSelectedCultoId);
            
            let html = `
                <table style="width: 100%; border-collapse: collapse; font-size: 0.85rem; color: #1E293B;">
                    <thead>
                        <tr style="border-bottom: 2px solid #CBD5E1; text-align: left;">
                            <th style="padding: 8px 4px; font-weight: 700; color: #475569;">Membro</th>
                            <th style="padding: 8px 4px; font-weight: 700; color: #475569;">Setor/Função</th>
                            <th style="padding: 8px 4px; font-weight: 700; color: #475569; text-align: right;">Situação</th>
                        </tr>
                    </thead>
                    <tbody>
            `;
            let count = 0;
            escalas.forEach(escala => {
                if (!escala.membroId || escala.membroNome === 'Vaga Pendente') return;
                if (this.isOperationalSector(escala.setorId)) return; // Ignora setores operacionais
                count++;
                const setorNome = this.sectorsData[escala.setorId]?.nome || escala.setorId;
                
                html += `
                    <tr style="border-bottom: 1px solid #F1F5F9;">
                        <td style="padding: 10px 4px; font-weight: 700; color: #1E293B;">${escala.membroNome}</td>
                        <td style="padding: 10px 4px; color: #475569;">${setorNome}<br><span style="font-size:0.75rem; color:#64748B;">${escala.funcao}</span></td>
                        <td style="padding: 10px 4px; text-align: right;">
                            <select class="presence-select" 
                                    data-escala-id="${escala.id}" 
                                    style="padding: 5px 8px; font-size: 0.8rem; border: 1px solid #CBD5E1; border-radius: 6px; background:#fff; color:#1E293B; font-weight: 600; cursor:pointer;">
                                <option value="Confirmada" ${escala.statusPresenca === 'Confirmada' ? 'selected' : ''}>Trabalhou</option>
                                <option value="Ausente" ${escala.statusPresenca === 'Ausente' ? 'selected' : ''}>Faltou</option>
                                <option value="Justificado" ${escala.statusPresenca === 'Justificado' ? 'selected' : ''}>Justificou</option>
                                <option value="Substituido" ${escala.statusPresenca === 'Substituido' ? 'selected' : ''}>Substituído</option>
                                <option value="Pendente" ${escala.statusPresenca === 'Pendente' ? 'selected' : ''}>Pendente</option>
                                <option value="Recusada" ${escala.statusPresenca === 'Recusada' ? 'selected' : ''}>Recusou</option>
                            </select>
                        </td>
                    </tr>
                `;
            });

            html += `</tbody></table>`;

            if (count === 0) {
                html = '<p style="text-align:center; color:#64748B; padding:20px; font-size:0.85rem; margin:0;">Nenhum voluntário liturgico escalado para este culto.</p>';
            }
            container.innerHTML = html;
        } catch (e) {
            console.error("Erro ao carregar modal de fechamento:", e);
            this.showToast('Erro ao carregar escala para fechamento.', 'danger');
            this.closeFechamentoCultoModal();
        }
    },

    closeFechamentoCultoModal() {
        this.toggleBottomNav(true); // Modo Imersivo: Restaurar
        document.getElementById('modal-culto-fechamento').classList.remove('active');
    },

    async handleFechamentoCultoSubmit(event) {
        event.preventDefault();
        const cultoId = document.getElementById('fechamento-culto-id').value;
        
        let hasPending = false;
        const statusEscalas = [];
        document.querySelectorAll('#fechamento-membros-lista .presence-select').forEach(select => {
            if (select.value === 'Pendente') {
                hasPending = true;
            }
            statusEscalas.push({
                escalaId: select.dataset.escalaId,
                statusPresenca: select.value
            });
        });

        if (hasPending) {
            this.showAlert('Atenção: Não é possível encerrar o culto enquanto houver membros com a situação "Pendente". Por favor, homologue todos.');
            return;
        }

        try {
            await DbService.fecharCulto(cultoId, statusEscalas);
            this.closeFechamentoCultoModal();
            this.showToast('Fechamento de culto concluído com sucesso!', 'success');
            
            if (this.adminSelectedCultoId === cultoId) {
                this.selectAdminCulto(cultoId);
            } else {
                this.loadAdminEscalas();
            }
        } catch (e) {
            console.error("Erro ao salvar fechamento:", e);
            this.showAlert('Erro ao salvar o fechamento do culto no banco de dados.');
        }
    },

    // --- REPOSIÇÃO (MEMBRO LIMPEZA / ESTOQUE) ---
    async loadAndRenderMemberReplenish() {
        const container = document.getElementById('member-estoque-lista-produtos');
        if (!container) return;
        
        container.innerHTML = '<div style="text-align: center; padding: 20px; color: #8AA6A3;"><i class="fa-solid fa-circle-notch fa-spin fa-lg"></i></div>';
        
        try {
            this.allProductsCache = await DbService.getProdutos();
            const ativos = this.allProductsCache.filter(p => p.status === 'ativo');
            
            let html = '';
            if (ativos.length === 0) {
                html = `<div style="text-align: center; padding: 30px; color: #8AA6A3;">Nenhum produto cadastrado no estoque.</div>`;
            } else {
                html = ativos.map(p => {
                    let alertHtml = '';
                    if (p.quantidadeAtual <= p.quantidadeMinima) {
                        alertHtml = `<span style="font-size: 0.7rem; background: #FEF2F2; color: #EF4444; border: 1px solid #FCA5A5; padding: 2px 6px; border-radius: 4px; margin-left: 8px;"><i class="fa-solid fa-triangle-exclamation"></i> Baixo</span>`;
                    }
                    
                    return `
                        <div style="background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.1); border-radius: 12px; padding: 15px;">
                            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;">
                                <div style="font-weight: 700; color: #fff; font-size: 1rem;">${p.nome} ${alertHtml}</div>
                                <div style="font-size: 1.2rem; font-weight: 800; color: var(--teal-primary);">${p.quantidadeAtual} <span style="font-size: 0.75rem; color: #8AA6A3; font-weight: 500;">un</span></div>
                            </div>
                            <div style="display: flex; gap: 8px;">
                                <button class="btn-primary" style="flex: 1; padding: 6px; font-size: 0.8rem; background: #10B981; border: none; border-radius: 6px;" onclick="App.openStockMovementModal('${p.id}', 'entrada')"><i class="fa-solid fa-arrow-down"></i> Entrada</button>
                                <button class="btn-primary" style="flex: 1; padding: 6px; font-size: 0.8rem; background: #EF4444; border: none; border-radius: 6px;" onclick="App.openStockMovementModal('${p.id}', 'saida')"><i class="fa-solid fa-arrow-up"></i> Saída</button>
                                <button class="btn-secondary" style="flex: 1; padding: 6px; font-size: 0.8rem; border-color: rgba(255,255,255,0.2); color: #fff; border-radius: 6px;" onclick="App.showAlert('Histórico em desenvolvimento')"><i class="fa-solid fa-clock-rotate-left"></i> Hist.</button>
                            </div>
                        </div>
                    `;
                }).join('');
            }
            container.innerHTML = html;
            
            // Load Request History
            this.renderMemberReplenishHistory();

        } catch (e) {
            console.error("Error loading products for replenish:", e);
            container.innerHTML = '<div style="color: #ef4444; padding: 20px; text-align: center;">Erro ao carregar o estoque.</div>';
        }
    },

    handleReplenishSectorChange(sectorId) {
        const select = document.getElementById('replenish-product-select');
        if (!select || !this.allProductsCache) return;

        const ativos = this.allProductsCache.filter(p => p.status === 'ativo' && (p.setorId === sectorId || p.setorId === 'limpeza' && sectorId === 'limpeza'));
        
        select.innerHTML = '<option value="" disabled selected>Selecione um produto</option>';
        ativos.forEach(p => {
            select.innerHTML += `<option value="${p.nome}" data-id="${p.id}">${p.nome}</option>`;
        });
    },

    async renderMemberReplenishHistory() {
        const container = document.getElementById('member-reposicao-list');
        if (!container) return;
        container.innerHTML = '<div style="text-align:center;"><i class="fa-solid fa-spinner fa-spin"></i></div>';

        try {
            const reqs = await DbService.getReposicoes();
            const ownReqs = reqs.filter(r => r.solicitadoPorId === this.currentUser.id || r.repositorId === this.currentUser.id);

            if (ownReqs.length === 0) {
                container.innerHTML = '<p style="text-align: center; color: var(--slate-gray); font-size: 0.9rem;">Nenhuma solicitação realizada.</p>';
                return;
            }

            container.innerHTML = '';
            ownReqs.forEach(r => {
                const item = document.createElement('div');
                item.className = 'notice-item';
                
                let badgeClass = 'status-pendente';
                let statusLabel = r.status;
                if (r.status === 'Em análise') {
                    badgeClass = 'status-andamento';
                } else if (r.status === 'Aguardando Compra') {
                    badgeClass = 'status-andamento';
                    statusLabel = 'Aprovada (Em Compra)';
                } else if (r.status === 'Atendida') {
                    badgeClass = 'status-confirmado';
                } else if (r.status === 'Rejeitado') {
                    badgeClass = 'status-recusado';
                }

                const dt = r.dataSolicitacao.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' });

                item.innerHTML = `
                    <div class="notice-meta">
                        <span>${dt}</span>
                        <span class="badge ${badgeClass}">${statusLabel}</span>
                    </div>
                    <h4 style="font-weight: 700; margin-bottom: 5px; color:var(--navy-dark);">${r.produtoNome} (Qtd: ${r.quantidade})</h4>
                    <p style="font-size: 0.85rem; color: var(--slate-gray); margin: 0;">
                        ${r.observacao ? `<b>Sua obs:</b> ${r.observacao}<br>` : ''}
                        ${r.repositorNome ? `<b>Comprador designado:</b> ${r.repositorNome}<br>` : ''}
                        ${r.status === 'Atendida' && r.valorGasto ? `<b>Compra concluída em:</b> ${r.dataCompra ? new Date(r.dataCompra).toLocaleDateString('pt-BR') : dt} (Valor: R$ ${r.valorGasto.toFixed(2)})<br>` : ''}
                        ${r.status === 'Rejeitado' && r.motivoRejeicao ? `<span style="color:#EF4444;"><b>Motivo rejeição:</b> ${r.motivoRejeicao}</span><br>` : ''}
                    </p>
                `;
                container.appendChild(item);
            });
        } catch (e) {
            container.innerHTML = '<p style="color: red;">Erro ao carregar histórico.</p>';
        }
    },

    async declinePurchase(reposicaoId) {
        if (!confirm('Deseja recusar a compra deste insumo? O pedido será arquivado como rejeitado.')) return;
        
        const motivo = prompt('Por favor, informe o motivo da recusa:');
        if (motivo === null) return;

        try {
            const repDoc = await db.collection('reposicoes').doc(reposicaoId).get();
            if (repDoc.exists) {
                const repData = repDoc.data();
                
                await db.collection('reposicoes').doc(reposicaoId).update({
                    status: 'Rejeitado',
                    motivoRejeicao: motivo || 'Recusado pelo comprador designado',
                    recusadoPorId: this.currentUser.id,
                    recusadoPorNome: this.currentUser.nome,
                    recusadoEm: firebase.firestore.FieldValue.serverTimestamp()
                });

                await DbService.addNotificacao({
                    paraUsuarioId: repData.solicitadoPorId,
                    mensagem: `Seu pedido de "${repData.produtoNome}" foi recusado pelo comprador ${this.currentUser.nome}. Motivo: ${motivo || 'Recusado pelo comprador'}.`,
                    reposicaoId: reposicaoId
                });
                
                this.showToast('Compra recusada e pedido arquivado.', 'info');
                this.loadAndRenderMemberReplenish();
            }
        } catch (e) {
            console.error(e);
            this.showAlert('Erro ao recusar compra.');
        }
    },

    async openRepositorCompraModal(reposicaoId) {
        try {
            const repDoc = await db.collection('reposicoes').doc(reposicaoId).get();
            if (!repDoc.exists) return;
            const r = repDoc.data();

            document.getElementById('repositor-compra-reposicao-id').value = reposicaoId;
            document.getElementById('repositor-compra-produto-nome').textContent = `Produto: ${r.produtoNome.toUpperCase()} (Qtd solicitada: ${r.quantidade})`;
            
            document.getElementById('repositor-compra-data').value = this.formatLocalISOString(new Date()).slice(0, 16);
            document.getElementById('repositor-compra-qtd').value = r.quantidade;
            document.getElementById('repositor-compra-valor').value = '';
            document.getElementById('repositor-compra-obs').value = '';

            document.getElementById('modal-repositor-compra').style.display = 'flex';
        } catch (e) {
            console.error(e);
            this.showAlert('Erro ao abrir o modal de compra.');
        }
    },

    closeRepositorCompraModal() {
        document.getElementById('modal-repositor-compra').style.display = 'none';
    },

    async handleRepositorCompraSubmit(event) {
        event.preventDefault();
        const reposicaoId = document.getElementById('repositor-compra-reposicao-id').value;
        const dataCompraStr = document.getElementById('repositor-compra-data').value;
        const qtdComprada = parseInt(document.getElementById('repositor-compra-qtd').value, 10);
        const valorGasto = parseFloat(document.getElementById('repositor-compra-valor').value);
        const compraObservacao = document.getElementById('repositor-compra-obs').value.trim();

        if (!reposicaoId || isNaN(qtdComprada) || qtdComprada <= 0 || isNaN(valorGasto) || valorGasto < 0) {
            this.showAlert('Por favor, informe valores válidos.');
            return;
        }

        try {
            const repDoc = await db.collection('reposicoes').doc(reposicaoId).get();
            if (repDoc.exists) {
                const r = repDoc.data();
                
                await db.collection('reposicoes').doc(reposicaoId).update({
                    status: 'Atendida',
                    dataCompra: new Date(dataCompraStr),
                    quantidadeComprada: qtdComprada,
                    valorGasto: valorGasto,
                    compraObservacao: compraObservacao,
                    concluidoEm: firebase.firestore.FieldValue.serverTimestamp()
                });

                let prodId = r.produtoId;
                if (!prodId) {
                    const prodSnap = await db.collection('produtos')
                        .where('nome', '==', r.produtoNome)
                        .where('setorId', '==', r.setorId || 'limpeza')
                        .limit(1)
                        .get();
                    if (!prodSnap.empty) {
                        prodId = prodSnap.docs[0].id;
                    }
                }

                if (prodId) {
                    await DbService.registrarMovimentacaoEstoque(
                        prodId, 
                        'entrada', 
                        qtdComprada, 
                        `Compra efetuada pelo repositor (Valor: R$ ${valorGasto.toFixed(2)})`, 
                        this.currentUser.nome
                    );

                    await DbService.registrarMovimentacaoEstoque(
                        prodId, 
                        'saida', 
                        r.quantidade, 
                        `Entrega de reposição solicitada (Ref: ${reposicaoId})`, 
                        this.currentUser.nome
                    );
                }

                await DbService.addNotificacao({
                    paraUsuarioId: r.solicitadoPorId,
                    mensagem: `Seu pedido de "${r.produtoNome}" foi comprado e entregue por ${this.currentUser.nome}.`,
                    reposicaoId: reposicaoId
                });

                this.closeRepositorCompraModal();
                this.showToast('Entrada de insumo registrada e estoque atualizado!', 'success');
                this.loadAndRenderMemberReplenish();
            }
        } catch (e) {
            console.error(e);
            this.showAlert('Erro ao registrar a compra.');
        }
    },

    async handleSinalizarFaltaProduto() {
        const pSelect = document.getElementById('replenish-product-select');
        const produtoNome = pSelect.value;
        const selectedOption = pSelect.options[pSelect.selectedIndex];
        const produtoId = selectedOption ? selectedOption.getAttribute('data-id') : null;

        if (!produtoNome || !produtoId) {
            this.showAlert('Por favor, selecione um produto para sinalizar falta.');
            return;
        }

        try {
            await db.collection('produtos').doc(produtoId).update({
                statusEstoque: 'Falta'
            });
            this.showToast(`Falta sinalizada para ${produtoNome}`, 'warning');
            
            // Também cria um alerta de reposição automático com qtd 0 para histórico
            const sector = this.sectorsData[this.activeSectorId];
            await DbService.addReposicao({
                produtoId,
                produtoNome,
                quantidade: 0,
                observacao: "SINALIZAÇÃO DE FALTA",
                solicitadoPorId: this.currentUser.id,
                solicitadoPorNome: this.currentUser.nome,
                setorId: this.activeSectorId,
                setorNome: sector ? sector.nome : this.activeSectorId
            });
            
            document.getElementById('replenish-request-form').reset();
            this.loadAndRenderMemberReplenish();
        } catch (e) {
            console.error(e);
            this.showToast('Erro ao sinalizar falta', 'error');
        }
    },

    switchEstoqueTab(tabName, el) {
        // Atualizar aba visual
        document.querySelectorAll('.segment-item').forEach(i => i.classList.remove('active'));
        el.classList.add('active');

        // Alternar visualização
        if (tabName === 'saida') {
            document.getElementById('estoque-saida-view').style.display = 'block';
            document.getElementById('estoque-compra-view').style.display = 'none';
        } else {
            document.getElementById('estoque-saida-view').style.display = 'none';
            document.getElementById('estoque-compra-view').style.display = 'block';
        }
    },

    handleProductSelectChange(selectElement) {
        const option = selectElement.options[selectElement.selectedIndex];
        const productId = option.getAttribute('data-id');
        const balanceInfo = document.getElementById('saida-product-balance-info');
        const balanceVal = document.getElementById('saida-product-balance-val');
        
        if (productId && this.allProductsCache) {
            const product = this.allProductsCache.find(p => p.id === productId);
            if (product) {
                if (balanceVal) balanceVal.innerText = product.quantidade || 0;
                if (balanceInfo) balanceInfo.style.display = 'block';
            } else {
                if (balanceInfo) balanceInfo.style.display = 'none';
            }
        } else {
            if (balanceInfo) balanceInfo.style.display = 'none';
        }
    },

    async handleSaidaEstoqueSubmit(event) {
        event.preventDefault();
        const pSelect = document.getElementById('saida-product-select');
        const produtoNome = pSelect.value;
        const selectedOption = pSelect.options[pSelect.selectedIndex];
        const produtoId = selectedOption ? selectedOption.getAttribute('data-id') : null;
        const quantidade = parseInt(document.getElementById('saida-qty').value);

        if (!produtoNome) {
            this.showAlert('Por favor, selecione um produto.');
            return;
        }

        try {
            await DbService.registrarSaidaEstoque({
                produtoId,
                produtoNome,
                quantidade,
                retiradoPorId: this.currentUser.id,
                retiradoPorNome: this.currentUser.nome,
                setorId: this.activeSectorId
            });

            document.getElementById('saida-estoque-form').reset();
            this.showToast('Saída registrada com sucesso!', 'success');
            // Idealmente atualizaria o saldo na view
        } catch (e) {
            this.showAlert('Erro ao registrar saída de estoque.', 'Erro');
        }
    },

    async handleReplenishSubmit(event) {
        event.preventDefault();
        
        const pSelect = document.getElementById('replenish-product-select');
        const produtoNome = pSelect.value;
        const selectedOption = pSelect.options[pSelect.selectedIndex];
        const produtoId = selectedOption ? selectedOption.getAttribute('data-id') : null;
        const quantidade = parseInt(document.getElementById('replenish-qty').value) || 1;
        const observacao = document.getElementById('replenish-notes').value.trim();

        if (!produtoNome) {
            this.showAlert('Por favor, selecione um produto.');
            return;
        }

        const selectedSectorId = this.activeSectorId;
        const sector = this.sectorsData[selectedSectorId];
        const sectorNome = sector ? sector.nome : selectedSectorId;

        try {
            await DbService.addReposicao({
                produtoId,
                produtoNome,
                quantidade,
                observacao,
                solicitadoPorId: this.currentUser.id,
                solicitadoPorNome: this.currentUser.nome,
                setorId: selectedSectorId,
                setorNome: sectorNome
            });

            document.getElementById('solicitar-compra-form').reset();
            document.getElementById('modal-solicitar-compra').style.display = 'none';
            this.showToast('Solicitação de compra enviada!', 'success');
            // Historico não está mais no HTML mas podemos tentar chamar se quisermos no futuro.
            // this.renderMemberReplenishHistory();
        } catch (e) {
            this.showAlert('Erro ao enviar solicitação.', 'Erro');
        }
    },

    // Load member stats on profile tab
    async loadMemberProfileStats() {
        try {
            const escalas = await DbService.getEscalas(this.activeSectorId);
            const userEscalas = escalas.filter(e => e.membroId === this.currentUser.id);
            
            const totalConfirmados = userEscalas.filter(e => e.statusPresenca === 'Confirmada').length;
            const totalServidos = userEscalas.filter(e => e.statusServico === 'Finalizado').length;

            document.getElementById('stat-confirmados').innerText = totalConfirmados;
            document.getElementById('stat-serviu-mes').innerText = totalServidos;
        } catch (e) {
            console.error("Error loading stats:", e);
        }
    },

    // ==========================================================================
    // VIEW 4: ADMIN PORTAL
    // ==========================================================================
    loadAndRenderAdminPortal() {
        // Validação rígida de segurança
        const isAdmin = this.currentUser && this.currentUser.perfil === 'admin';
        if (!isAdmin) {
            console.error('[Segurança] Tentativa de renderizar Portal Admin bloqueada para usuário:', this.currentUser ? this.currentUser.nome : 'Nulo');
            this.showToast('Acesso negado. Esta é uma área administrativa.', 'danger');
            this.navigateTo('view-setor-select');
            return;
        }

        // Toggle mobile drawer shut
        document.getElementById('admin-drawer').classList.remove('mobile-open');

        // Apply visual adjustments
        const titleEl = document.getElementById('admin-view-title');
        titleEl.innerText = this.getAdminTabTitle(this.adminActiveTab);

        // Hide all views, show selected
        document.querySelectorAll('.admin-tabview').forEach(view => view.style.display = 'none');
        document.getElementById(`admin-sub-${this.adminActiveTab}`).style.display = 'block';

        // Load data depending on view
        if (this.adminActiveTab === 'dashboard') {
            this.loadAdminDashboard();
        } else if (this.adminActiveTab === 'setores') {
            this.loadAdminSectors();
        } else if (this.adminActiveTab === 'membros') {
            this.loadAdminMembros();
        } else if (this.adminActiveTab === 'escalas') {
            this.loadAdminEscalas();
        } else if (this.adminActiveTab === 'reposicoes') {
            this.loadAdminReposicoes();
        } else if (this.adminActiveTab === 'produtos') {
            this.loadAdminProdutos();
        } else if (this.adminActiveTab === 'relatorios') {
            this.loadAdminRelatorios();
        } else if (this.adminActiveTab === 'avisos') {
            this.loadAdminAvisos();
        } else if (this.adminActiveTab === 'afastamentos') {
            this.loadAndRenderAdminAfastamentos();
        } else if (this.adminActiveTab === 'zeladoria') {
            this.renderEscalasOperacionais();
        } else if (this.adminActiveTab === 'operacional') {
            this.loadAdminOperacional();
        }

        // Para o listener de pendências se não está no dashboard
        if (this.adminActiveTab !== 'dashboard') {
            this.stopPendenciasListener();
        }
    },

    switchAdminTab(tabName, el) {
        this.adminActiveTab = tabName;
        
        const menuEl = el || document.querySelector(`.admin-menu-item[onclick*="'${tabName}'"]`);
        
        document.querySelectorAll('.admin-menu-item').forEach(item => {
            item.classList.remove('active');
        });
        if (menuEl) {
            menuEl.classList.add('active');
        }

        if (tabName === 'escalas') {
            if (el) {
                this.adminSelectedCultoId = null;
            }
        }

        this.loadAndRenderAdminPortal();
    },

    getAdminTabTitle(tabName) {
        switch (tabName) {
            case 'dashboard': return 'Painel Geral';
            case 'setores': return 'Estrutura de Setores';
            case 'membros': return 'Membros da Equipe';
            case 'afastamentos': return 'Gestão de Afastamentos';
            case 'escalas': return 'Controle de Escalas';
            case 'reposicoes': return 'Solicitações de Reposição';
            case 'produtos': return 'Produtos Cadastrados';
            case 'relatorios': return 'Métricas e Relatórios';
            case 'avisos': return 'Mural de Informativos';
            default: return 'Diaconato';
        }
    },

    toggleAdminSidebar() {
        document.getElementById('admin-drawer').classList.toggle('mobile-open');
    },

    // --- TAB: DASHBOARD (ADMIN) ---
    async loadAdminDashboard() {
        try {
            // 0. Fetch general counts & set welcome card details
            const membros = await DbService.getMembros();
            const cultos = await DbService.getCultos();
            const adminName = this.currentUser ? this.currentUser.nome : 'Supervisor';
            
            const adminWelcomeNameEl = document.getElementById('admin-welcome-name');
            if (adminWelcomeNameEl) adminWelcomeNameEl.innerText = adminName;
            
            const welcomeStatMembrosEl = document.getElementById('welcome-stat-membros');
            if (welcomeStatMembrosEl) welcomeStatMembrosEl.innerText = membros.filter(m => m.status === 'ativo').length;
            
            const welcomeStatCultosEl = document.getElementById('welcome-stat-cultos');
            if (welcomeStatCultosEl) {
                const hoje = new Date().toISOString().split('T')[0];
                const cultosAtivos = cultos.filter(c => c.data >= hoje && c.status !== 'Finalizado').length;
                welcomeStatCultosEl.innerText = cultosAtivos;
            }
            
            // 1. Fetch counts for stats cards (escalas ativas por setor)
            const escalas = await DbService.getEscalas();
            
            const sectorEscalas = {};
            const sectorVoluntarios = {};

            // Inicializar contagens para todos os setores ativos
            for (const key in this.sectorsData) {
                sectorEscalas[key] = 0;
                sectorVoluntarios[key] = 0;
            }

            // Contar escalas ativas por setor
            escalas.forEach(e => {
                if (e.statusServico !== 'Finalizado') {
                    if (sectorEscalas[e.setorId] !== undefined) {
                        sectorEscalas[e.setorId]++;
                    }
                }
            });

            // Contar membros ativos por setor
            membros.forEach(m => {
                if (m.status === 'ativo') {
                    if (Array.isArray(m.setores)) {
                        m.setores.forEach(sId => {
                            if (sectorVoluntarios[sId] !== undefined) {
                                sectorVoluntarios[sId]++;
                            }
                        });
                    } else if (m.setor && sectorVoluntarios[m.setor] !== undefined) {
                        sectorVoluntarios[m.setor]++;
                    }
                }
            });

            // Renderizar tabela compacta de status dos setores (substituindo 8 cards)
            const statsGrid = document.getElementById('admin-dashboard-stats-grid');
            if (statsGrid) {
                let tableHtml = `
                    <div style="overflow:hidden; border-radius:8px; border:1px solid #E2E8F0;">
                        <table style="width:100%; border-collapse:collapse; font-size:0.85rem;">
                            <thead>
                                <tr style="background:#F8FAFC; border-bottom:1px solid #E2E8F0;">
                                    <th style="padding:10px 14px; text-align:left; font-weight:700; color:#64748B; font-size:0.75rem; text-transform:uppercase; letter-spacing:0.5px;">Setor</th>
                                    <th style="padding:10px 14px; text-align:center; font-weight:700; color:#64748B; font-size:0.75rem; text-transform:uppercase; letter-spacing:0.5px;">Membros</th>
                                    <th style="padding:10px 14px; text-align:center; font-weight:700; color:#64748B; font-size:0.75rem; text-transform:uppercase; letter-spacing:0.5px;">Escalas Ativas</th>
                                    <th style="padding:10px 14px; text-align:center; font-weight:700; color:#64748B; font-size:0.75rem; text-transform:uppercase; letter-spacing:0.5px;">Status</th>
                                </tr>
                            </thead>
                            <tbody>
                `;

                const hojeStr = new Date().toISOString().split('T')[0];

                for (const [key, sector] of Object.entries(this.sectorsData)) {
                    const vol = sectorVoluntarios[key] || 0;
                    // Only count escalas for future/active cultos
                    const escalasAtivas = escalas.filter(e => {
                        if (e.setorId !== key) return false;
                        if (e.statusServico === 'Finalizado') return false;
                        const c = cultos.find(cu => cu.id === e.cultoId);
                        return !c || c.data >= hojeStr;
                    }).length;

                    const statusColor = escalasAtivas > 0 ? '#10B981' : '#94A3B8';
                    const statusText = escalasAtivas > 0 ? 'Com escala' : 'Sem escala';
                    const statusBg = escalasAtivas > 0 ? '#ECFDF5' : '#F1F5F9';

                    tableHtml += `
                        <tr style="border-bottom:1px solid #F1F5F9; transition:background 0.15s;" onmouseover="this.style.background='#F8FAFC'" onmouseout="this.style.background=''">
                            <td style="padding:11px 14px;">
                                <div style="display:flex; align-items:center; gap:10px;">
                                    <div style="width:10px; height:10px; border-radius:50%; background:${sector.cor}; flex-shrink:0;"></div>
                                    <span style="font-weight:600; color:#1E293B;">${sector.nome}</span>
                                </div>
                            </td>
                            <td style="padding:11px 14px; text-align:center; font-weight:700; color:#1E293B;">${vol}</td>
                            <td style="padding:11px 14px; text-align:center; font-weight:700; color:#1E293B;">${escalasAtivas}</td>
                            <td style="padding:11px 14px; text-align:center;">
                                <span style="background:${statusBg}; color:${statusColor}; padding:3px 10px; border-radius:20px; font-size:0.75rem; font-weight:600;">${statusText}</span>
                            </td>
                        </tr>
                    `;
                }

                tableHtml += `</tbody></table></div>`;
                statsGrid.innerHTML = tableHtml;
            }

            // 2. Load Services in Progress
            const activeServices = await DbService.getServicosEmAndamento();
            const serviceContainer = document.getElementById('admin-dashboard-active-services');
            document.getElementById('active-services-count').innerText = `${activeServices.length} Ativo(s)`;

            if (activeServices.length === 0) {
                serviceContainer.innerHTML = `<div style="text-align: center; color: var(--slate-gray); padding: 30px; font-size:0.9rem;">Não há serviços em andamento no momento.</div>`;
            } else {
                serviceContainer.innerHTML = '';
                activeServices.forEach(s => {
                    const secInfo = this.sectorsData[s.setorId];
                    const row = document.createElement('div');
                    row.className = 'active-service-item';
                    row.style.borderLeftColor = secInfo ? secInfo.cor : 'var(--theme-color)';
                    
                    row.innerHTML = `
                        <div>
                            <div style="font-weight: 700; font-size: 0.95rem;">${s.membroNome}</div>
                            <div style="font-size: 0.8rem; color: var(--slate-gray);">${secInfo ? secInfo.nome : s.setorId} - ${s.funcao}</div>
                        </div>
                        <div style="text-align: right;">
                            <span class="badge badge-active" style="animation: pulse 1.5s infinite;"><i class="fa-solid fa-play"></i> Iniciou às ${s.horarioInicio}</span>
                        </div>
                    `;
                    serviceContainer.appendChild(row);
                });
            }

            // 3. Scale Summary Stats & Progress Bar
            const summaryContainer = document.getElementById('admin-dashboard-scales-summary');
            summaryContainer.innerHTML = '';
            
            const escalasLiturgicas = escalas.filter(e => !this.isOperationalSector(e.setorId));
            const totalScales = escalasLiturgicas.length;
            const confirmed = escalasLiturgicas.filter(e => e.statusPresenca === 'Confirmada').length;
            const pending = escalasLiturgicas.filter(e => e.statusPresenca === 'Pendente').length;
            const finished = escalasLiturgicas.filter(e => e.statusServico === 'Finalizado').length;
            const other = totalScales - confirmed - pending;

            const pctConfirmed = totalScales > 0 ? Math.round((confirmed / totalScales) * 100) : 0;
            const pctPending = totalScales > 0 ? Math.round((pending / totalScales) * 100) : 0;
            const pctOther = totalScales > 0 ? (100 - pctConfirmed - pctPending) : 0;

            const confirmedEl = document.querySelector('#dashboard-scales-progress-bar .confirmed');
            const pendingEl = document.querySelector('#dashboard-scales-progress-bar .pending');
            const otherEl = document.querySelector('#dashboard-scales-progress-bar .other');

            if (confirmedEl) confirmedEl.style.width = `${pctConfirmed}%`;
            if (pendingEl) pendingEl.style.width = `${pctPending}%`;
            if (otherEl) otherEl.style.width = `${pctOther}%`;

            const pctConfirmedEl = document.getElementById('dash-progress-pct-confirmed');
            const pctPendingEl = document.getElementById('dash-progress-pct-pending');
            if (pctConfirmedEl) pctConfirmedEl.innerText = `${pctConfirmed}%`;
            if (pctPendingEl) pctPendingEl.innerText = `${pctPending}%`;

            summaryContainer.innerHTML = `
                <div class="report-row"><span>Total Planejado:</span> <b>${totalScales}</b></div>
                <div class="report-row"><span>Presenças Confirmadas:</span> <b style="color: #10B981;">${confirmed}</b></div>
                <div class="report-row"><span>Presenças Pendentes:</span> <b style="color: #F59E0B;">${pending}</b></div>
                <div class="report-row"><span>Serviços Finalizados:</span> <b style="color: var(--teal-primary);">${finished}</b></div>
            `;

            // 4. Pending Replenishments summary
            const reposicoes = await DbService.getReposicoes();
            const pendingReps = reposicoes.filter(r => r.status === 'Pendente');
            const repContainer = document.getElementById('admin-dashboard-reposicoes');

            if (pendingReps.length === 0) {
                repContainer.innerHTML = `<div style="color:#059669; font-weight:600;"><i class="fa-solid fa-circle-check"></i> Tudo abastecido. Sem solicitações.</div>`;
            } else {
                repContainer.innerHTML = `
                    <div style="color: #DC2626; font-weight:700; font-size:1.1rem; margin-bottom:5px;">
                        ${pendingReps.length} Solicitações Pendentes
                    </div>
                    <button class="btn-primary" style="padding: 6px 12px; font-size: 0.8rem; width: auto; margin: 0 auto;" onclick="App.navigateToTabFromDashboard('reposicoes')">
                        Ver e Atender
                    </button>
                `;
            }

            // 6. Calculate absence alerts for dashboard
            const adminDashboardAfastamentosAlertas = document.getElementById('admin-dashboard-afastamentos-alertas');
            if (adminDashboardAfastamentosAlertas) {
                const feriasCount = membros.filter(m => m.statusOperacional === 'Férias').length;
                const outrosAfastadosCount = membros.filter(m => m.statusOperacional && m.statusOperacional !== 'Disponível' && m.statusOperacional !== 'Férias').length;
                
                let retornandoEm5Dias = 0;
                const hoje = new Date();
                hoje.setHours(0,0,0,0);
                const limiteFim = new Date(hoje);
                limiteFim.setDate(hoje.getDate() + 5);

                const parseLocalDate = (dateStr) => {
                    if (!dateStr) return null;
                    const parts = dateStr.split('-');
                    return new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10));
                };

                membros.forEach(m => {
                    if (m.statusOperacional && m.statusOperacional !== 'Disponível' && m.afastamentoFim) {
                        const fim = parseLocalDate(m.afastamentoFim);
                        if (fim >= hoje && fim <= limiteFim) {
                            retornandoEm5Dias++;
                        }
                    }
                });

                let alertasHTML = '<div style="display: flex; flex-direction: column; gap: 8px;">';
                alertasHTML += `
                    <div style="display: flex; justify-content: space-between; align-items: center; padding: 6px 0; border-bottom: 1px solid rgba(0,0,0,0.03);">
                        <span style="display: flex; align-items: center; gap: 6px;"><i class="fa-solid fa-umbrella-beach" style="color: #10B981;"></i> Obreiros em Férias</span>
                        <span class="badge" style="background: rgba(16, 185, 129, 0.1); color: #10B981; font-weight: 700; border-radius: 6px; padding: 2px 8px;">${feriasCount}</span>
                    </div>
                    <div style="display: flex; justify-content: space-between; align-items: center; padding: 6px 0; border-bottom: 1px solid rgba(0,0,0,0.03);">
                        <span style="display: flex; align-items: center; gap: 6px;"><i class="fa-solid fa-person-walking-luggage" style="color: #F59E0B;"></i> Outros Afastamentos</span>
                        <span class="badge" style="background: rgba(245, 158, 11, 0.1); color: #F59E0B; font-weight: 700; border-radius: 6px; padding: 2px 8px;">${outrosAfastadosCount}</span>
                    </div>
                    <div style="display: flex; justify-content: space-between; align-items: center; padding: 6px 0;">
                        <span style="display: flex; align-items: center; gap: 6px;"><i class="fa-solid fa-arrows-spin" style="color: #6366F1;"></i> Retornos nos próximos 5 dias</span>
                        <span class="badge" style="background: rgba(99, 102, 241, 0.1); color: #6366F1; font-weight: 700; border-radius: 6px; padding: 2px 8px;">${retornandoEm5Dias}</span>
                    </div>
                `;
                alertasHTML += '</div>';
                adminDashboardAfastamentosAlertas.innerHTML = alertasHTML;
            }

            // 5. Operational Pendencies panel rendering (Decoupled)
            this.renderOperationalPendingPanel(cultos, escalas);

            // 6. Real-time listener para atualizar pendências quando obreiros confirmam
            this.startPendenciasListener();

        } catch (e) {
            console.error("Dashboard load error:", e);
        }
    },

    _pendenciasUnsubscribe: null,

    startPendenciasListener() {
        // Cancela listener anterior se existir
        if (this._pendenciasUnsubscribe) {
            this._pendenciasUnsubscribe();
            this._pendenciasUnsubscribe = null;
        }

        // Ouve mudanças em tempo real na coleção de escalas
        this._pendenciasUnsubscribe = db.collection('escalas')
            .onSnapshot(async () => {
                // Limpa o cache para garantir dados frescos
                DbService.limparCache('escalas');
                try {
                    const [cultos, escalas] = await Promise.all([
                        DbService.getCultos(),
                        DbService.getEscalas()
                    ]);
                    this.renderOperationalPendingPanel(cultos, escalas);
                } catch(e) {
                    console.warn('[Listener] Erro ao atualizar pendências:', e);
                }
            }, err => {
                console.warn('[Listener] Erro no snapshot de escalas:', err);
            });
    },

    stopPendenciasListener() {
        if (this._pendenciasUnsubscribe) {
            this._pendenciasUnsubscribe();
            this._pendenciasUnsubscribe = null;
        }
    },

    navigateToTabFromDashboard(tabName) {
        const el = Array.from(document.querySelectorAll('.admin-menu-item')).find(item => item.innerHTML.includes(tabName === 'reposicoes' ? 'Reposição' : tabName));
        if (el) {
            this.switchAdminTab(tabName, el);
        }
    },

    renderOperationalPendingPanel(cultos, escalas) {
        const pendenciasContainer = document.getElementById('admin-dashboard-pendencias');
        if (!pendenciasContainer) return;

        const agora = new Date();
        const hojeStr = agora.toISOString().split('T')[0];
        const horaAtual = agora.toTimeString().split(' ')[0].substring(0, 5);

        const cultosPassados = cultos.filter(c => {
            if (c.status === 'Finalizado') return false;
            if (c.data < hojeStr) return true;
            if (c.data === hojeStr) {
                const fim = c.horarioFim || '23:59';
                return horaAtual > fim;
            }
            return false;
        }).filter(c => {
            const escalasDoCulto = escalas.filter(e => e.cultoId === c.id);
            return escalasDoCulto.length > 0;
        });

        const aceitesPendentes = escalas.filter(e => {
            if (e.statusPresenca !== 'Pendente' || !e.membroId || e.membroNome === 'Vaga Pendente' || !e.cultoId) return false;
            const c = cultos.find(culto => culto.id === e.cultoId);
            return c && c.status !== 'Finalizado';
        });

        const faltasSemJustificativa = escalas.filter(e => {
            if (e.statusPresenca !== 'Ausente') return false;
            const c = cultos.find(culto => culto.id === e.cultoId);
            return c && c.data < hojeStr;
        });

        const finalizadosRecentemente = cultos
            .filter(c => c.status === 'Finalizado')
            .sort((a, b) => b.data.localeCompare(a.data))
            .slice(0, 3);

        const totalPendencias = cultosPassados.length + aceitesPendentes.length + faltasSemJustificativa.length;

        const badgeEl = document.getElementById('pendencias-count-badge');
        if (badgeEl) {
            badgeEl.innerText = `${totalPendencias} Pendência(s)`;
            if (totalPendencias === 0) {
                badgeEl.style.background = '#ECFDF5';
                badgeEl.style.color = '#10B981';
                badgeEl.style.borderColor = '#A7F3D0';
            } else {
                badgeEl.style.background = '#FEF2F2';
                badgeEl.style.color = '#EF4444';
                badgeEl.style.borderColor = '#FCA5A5';
            }
        }

        let itemsHtml = '';

        // A. Cultos Passados sem Fechamento
        cultosPassados.forEach(c => {
            const dataFmt = c.data.split('-').reverse().join('/');
            itemsHtml += `
                <div style="display:flex; align-items:center; justify-content:space-between; background:#FEF2F2; border:1px solid #FCA5A5; padding:12px; border-radius:10px; gap: 10px; box-shadow: 0 1px 2px rgba(0,0,0,0.02);">
                    <div style="display:flex; align-items:center; gap:12px; text-align:left;">
                        <span style="font-size:1rem; display:inline-flex; align-items:center; justify-content:center; width:32px; height:32px; border-radius:50%; background:#FEE2E2; color:#EF4444;">
                            <i class="fa-solid fa-lock-open"></i>
                        </span>
                        <div>
                            <div style="font-weight:700; font-size:0.82rem; color:var(--navy-dark);">Culto sem Fechamento</div>
                            <div style="font-size:0.75rem; color:var(--slate-gray); font-weight:500;">${c.nome} • ${dataFmt}</div>
                        </div>
                    </div>
                    <button onclick="App.adminSelectedCultoId='${c.id}'; App.openFechamentoCultoModal();" class="btn-clean-action" style="padding: 5px 10px; font-size: 0.72rem; background:#EF4444; color:#fff; border-radius: 6px; border:none; cursor:pointer; font-weight: 700; transition:opacity 0.2s;" onmouseover="this.style.opacity='0.9'" onmouseout="this.style.opacity='1'">Fechar</button>
                </div>
            `;
        });

        // B. Aceites Pendentes
        aceitesPendentes.forEach(e => {
            const dataFmt = e.data.split('-').reverse().join('/');
            const c = cultos.find(culto => culto.id === e.cultoId);
            const cultoNome = c ? c.nome : 'Culto';
            itemsHtml += `
                <div style="display:flex; align-items:center; justify-content:space-between; background:#FFFBEB; border:1px solid #FCD34D; padding:12px; border-radius:10px; gap: 10px; box-shadow: 0 1px 2px rgba(0,0,0,0.02);">
                    <div style="display:flex; align-items:center; gap:12px; text-align:left;">
                        <span style="font-size:1rem; display:inline-flex; align-items:center; justify-content:center; width:32px; height:32px; border-radius:50%; background:#FEF3C7; color:#D97706;">
                            <i class="fa-solid fa-hourglass-half"></i>
                        </span>
                        <div>
                            <div style="font-weight:700; font-size:0.82rem; color:var(--navy-dark);">Aceite Pendente</div>
                            <div style="font-size:0.75rem; color:var(--slate-gray); font-weight:500;"><b>${e.membroNome}</b> • ${cultoNome} (${dataFmt})</div>
                        </div>
                    </div>
                    <button onclick="App.adminSelectedCultoId='${e.cultoId}'; App.switchAdminTab('escalas');" class="btn-clean-action" style="padding: 5px 10px; font-size: 0.72rem; background:#D97706; color:#fff; border-radius: 6px; border:none; cursor:pointer; font-weight: 700; transition:opacity 0.2s;" onmouseover="this.style.opacity='0.9'" onmouseout="this.style.opacity='1'">Ver</button>
                </div>
            `;
        });

        // C. Faltas Injustificadas
        faltasSemJustificativa.forEach(e => {
            const dataFmt = e.data.split('-').reverse().join('/');
            const c = cultos.find(culto => culto.id === e.cultoId);
            const cultoNome = c ? c.nome : 'Culto';
            itemsHtml += `
                <div style="display:flex; align-items:center; justify-content:space-between; background:#FEF2F2; border:1px solid #FCA5A5; padding:12px; border-radius:10px; gap: 10px; box-shadow: 0 1px 2px rgba(0,0,0,0.02);">
                    <div style="display:flex; align-items:center; gap:12px; text-align:left;">
                        <span style="font-size:1rem; display:inline-flex; align-items:center; justify-content:center; width:32px; height:32px; border-radius:50%; background:#FEE2E2; color:#EF4444;">
                            <i class="fa-solid fa-circle-xmark"></i>
                        </span>
                        <div>
                            <div style="font-weight:700; font-size:0.82rem; color:var(--navy-dark);">Falta Injustificada</div>
                            <div style="font-size:0.75rem; color:var(--slate-gray); font-weight:500;"><b>${e.membroNome}</b> • ${cultoNome} (${dataFmt})</div>
                        </div>
                    </div>
                    <button onclick="App.adminSelectedCultoId='${e.cultoId}'; App.openFechamentoCultoModal();" class="btn-clean-action" style="padding: 5px 10px; font-size: 0.72rem; background:#EF4444; color:#fff; border-radius: 6px; border:none; cursor:pointer; font-weight: 700; transition:opacity 0.2s;" onmouseover="this.style.opacity='0.9'" onmouseout="this.style.opacity='1'">Justificar</button>
                </div>
            `;
        });

        if (!itemsHtml) {
            itemsHtml = `
                <div style="grid-column: 1 / -1; text-align: center; color: var(--slate-gray); padding: 30px; font-size:0.95rem; font-weight:500; display:flex; flex-direction:column; align-items:center; gap:10px;">
                    <i class="fa-solid fa-circle-check" style="color:#10B981; font-size:2rem;"></i>
                    Nenhuma pendência operacional ativa no momento.
                </div>
            `;
        }

        pendenciasContainer.innerHTML = itemsHtml;
    },

    // --- TAB: OPERACIONAL (ADMIN) ---
    async loadAdminOperacional() {
        try {
            // 1. Carregar Expedientes Ativos (Limpeza / Manutenção)
            const activeServices = await DbService.getServicosEmAndamento();
            const opActive = activeServices.filter(s => this.isOperationalSector(s.setorId));
            const containerActive = document.getElementById('admin-op-active-services');
            
            if (opActive.length === 0) {
                containerActive.innerHTML = `<div style="text-align: center; color: var(--slate-gray); padding: 30px; font-size:0.9rem;">Não há expedientes operacionais em andamento no momento.</div>`;
            } else {
                containerActive.innerHTML = '';
                opActive.forEach(s => {
                    const secInfo = this.sectorsData[s.setorId];
                    const row = document.createElement('div');
                    row.className = 'active-service-item';
                    row.style.borderLeftColor = secInfo ? secInfo.cor : 'var(--theme-color)';
                    row.innerHTML = `
                        <div>
                            <div style="font-weight: 700; font-size: 0.95rem;">${s.membroNome}</div>
                            <div style="font-size: 0.8rem; color: var(--slate-gray);">${secInfo ? secInfo.nome : s.setorId} - ${s.funcao}</div>
                        </div>
                        <div style="text-align: right;">
                            <span class="badge badge-active" style="animation: pulse 1.5s infinite;"><i class="fa-solid fa-play"></i> Iniciou às ${s.horarioInicio}</span>
                        </div>
                    `;
                    containerActive.appendChild(row);
                });
            }

            // 2. Carregar Escalas Operacionais Futuras e do Dia (cultoId === 'op-YYYY-MM-DD')
            const todasEscalas = await DbService.getEscalas();
            const opScheduled = todasEscalas.filter(e => e.cultoId && e.cultoId.startsWith('op-'));
            
            // 2.5 Verificar Atrasos de Hoje
            const today = new Date();
            const y = today.getFullYear();
            const m = String(today.getMonth() + 1).padStart(2, '0');
            const d = String(today.getDate()).padStart(2, '0');
            const todayStr = `${y}-${m}-${d}`;
            const currentMins = today.getHours() * 60 + today.getMinutes();
            
            const atrasos = opScheduled.filter(e => {
                if (e.data === todayStr && e.statusPresenca === 'Pendente' && e.horarioInicio) {
                    const [hh, mm] = e.horarioInicio.split(':').map(Number);
                    const shiftMins = (hh * 60) + mm;
                    // Se passou mais de 15 minutos do horário marcado
                    if (currentMins >= (shiftMins + 15)) {
                        return true;
                    }
                }
                return false;
            });

            // Container de Alertas Gerais (atrasos operacionais)
            const alertSection = document.getElementById('admin-op-alert-section') || document.createElement('div');
            alertSection.id = 'admin-op-alert-section';
            alertSection.innerHTML = ''; // Clear previous
            
            if (atrasos.length > 0) {
                let htmlAtrasos = `<div style="background: #FEF2F2; border: 1px solid #FCA5A5; border-radius: 12px; padding: 15px; margin-bottom: 20px;">
                    <h3 style="font-size: 0.95rem; font-weight: 800; color: #DC2626; margin-bottom: 10px; display: flex; align-items: center; gap: 8px;">
                        <i class="fa-solid fa-triangle-exclamation" style="animation: pulse 2s infinite;"></i> Atrasos Identificados
                    </h3>
                    <div style="display: flex; flex-direction: column; gap: 8px;">`;
                
                atrasos.forEach(a => {
                    htmlAtrasos += `
                        <div style="display: flex; justify-content: space-between; align-items: center; font-size: 0.85rem; background: white; padding: 10px; border-radius: 8px; border: 1px solid #FECACA;">
                            <div>
                                <span style="font-weight: 700; color: var(--navy-dark);">${a.membroNome}</span>
                                <span style="color: var(--slate-gray);"> • ${a.funcao}</span>
                            </div>
                            <span style="font-weight: 700; color: #DC2626;"><i class="fa-regular fa-clock"></i> Era ${a.horarioInicio}</span>
                        </div>
                    `;
                });
                
                htmlAtrasos += `</div></div>`;
                alertSection.innerHTML = htmlAtrasos;
                
                // Prepend to the first tab-content of admin operacional
                const containerActiveParent = document.getElementById('admin-op-active-services').parentElement;
                containerActiveParent.insertBefore(alertSection, containerActiveParent.firstChild);
            } else if (alertSection.parentElement) {
                alertSection.parentElement.removeChild(alertSection);
            }

            
            // Sort by Date
            opScheduled.sort((a, b) => new Date(a.data) - new Date(b.data));
            
            const containerScheduled = document.getElementById('admin-op-scheduled-services');
            if (opScheduled.length === 0) {
                containerScheduled.innerHTML = `<div style="text-align: center; color: var(--slate-gray); padding: 30px; font-size:0.9rem;">Nenhum agendamento operacional futuro.</div>`;
            } else {
                containerScheduled.innerHTML = '';
                opScheduled.forEach(e => {
                    const secInfo = this.sectorsData[e.setorId];
                    const dateParts = e.data.split('-');
                    const dateFormatted = dateParts.length === 3 ? `${dateParts[2]}/${dateParts[1]}/${dateParts[0]}` : e.data;
                    
                    const row = document.createElement('div');
                    row.style.cssText = "background: white; border-radius: 8px; padding: 12px; margin-bottom: 10px; border: 1px solid #E2E8F0; display: flex; justify-content: space-between; align-items: center;";
                    row.style.borderLeft = `4px solid ${secInfo ? secInfo.cor : 'var(--theme-color)'}`;
                    
                    row.innerHTML = `
                        <div>
                            <div style="font-weight: 700; font-size: 0.95rem; color: var(--navy-dark);">${e.membroNome}</div>
                            <div style="font-size: 0.8rem; color: var(--slate-gray);">${secInfo ? secInfo.nome : e.setorId} - ${e.funcao}</div>
                            <div style="font-size: 0.75rem; color: var(--teal-primary); font-weight:600; margin-top:4px;">
                                <i class="fa-regular fa-calendar"></i> ${dateFormatted} às ${e.horarioInicio || '--:--'}
                            </div>
                        </div>
                        <div>
                            <button class="btn-clean-action" style="color: #DC2626;" onclick="App.deleteEscalaOperacional('${e.id}')">
                                <i class="fa-solid fa-trash"></i>
                            </button>
                        </div>
                    `;
                    containerScheduled.appendChild(row);
                });
            }

            // 3. Carregar Alertas de Estoque (Produtos com statusEstoque === 'Falta')
            const produtos = await DbService.getProdutos();
            const stockAlerts = produtos.filter(p => p.statusEstoque === 'Falta');
            const containerAlerts = document.getElementById('admin-op-stock-alerts');

            if (stockAlerts.length === 0) {
                containerAlerts.innerHTML = `<div style="color:#059669; font-weight:600;"><i class="fa-solid fa-circle-check"></i> Sem alertas de estoque no momento.</div>`;
            } else {
                containerAlerts.innerHTML = '';
                stockAlerts.forEach(p => {
                    const row = document.createElement('div');
                    row.style.cssText = "background: white; border-radius: 8px; padding: 12px; margin-bottom: 10px; border: 1px solid #FCA5A5; display: flex; justify-content: space-between; align-items: center;";
                    row.innerHTML = `
                        <div>
                            <div style="font-weight: 700; font-size: 0.95rem; color: #DC2626;">${p.nome}</div>
                            <div style="font-size: 0.8rem; color: var(--slate-gray);">Setor: ${this.sectorsData[p.setorId]?.nome || 'Limpeza'}</div>
                        </div>
                        <div>
                            <button class="btn-primary" style="background:#10B981; border:none; padding: 6px 12px; font-size: 0.75rem; border-radius: 6px;" onclick="App.removerFaltaProduto('${p.id}', '${p.nome}')">
                                <i class="fa-solid fa-check"></i> Reposto
                            </button>
                        </div>
                    `;
                    containerAlerts.appendChild(row);
                });
            }

        } catch (e) {
            console.error("Error loading Admin Operacional:", e);
        }
    },

    async openEscalaOperacionalModal() {
        const setorSelect = document.getElementById('escala-op-setor');
        setorSelect.innerHTML = '<option value="" disabled selected>Selecione Limpeza ou Manutenção</option>';
        for (const [id, sec] of Object.entries(this.sectorsData)) {
            if (sec.tipo === 'operacional') {
                setorSelect.innerHTML += `<option value="${id}">${sec.nome}</option>`;
            }
        }
        
        document.getElementById('escala-op-form').reset();
        
        // Hide repeat options
        document.getElementById('escala-op-repeat-options').style.display = 'none';
        document.getElementById('escala-op-repeat-toggle').checked = false;
        
        // Clear Members (will populate on sector change)
        const membroContainer = document.getElementById('escala-op-membro-container');
        if (membroContainer) {
            membroContainer.innerHTML = '<div style="font-size: 0.85rem; color: var(--slate-gray); padding: 5px;">Escolha primeiro o setor...</div>';
        }
        
        document.getElementById('modal-escala-operacional-form').classList.add('active');
    },

    async handleEscalaOpSetorChange(sectorId) {
        const funcSelect = document.getElementById('escala-op-funcao');
        funcSelect.innerHTML = '<option value="" disabled selected>Selecione a função</option>';
        
        if (this.sectorsData[sectorId]) {
            this.sectorsData[sectorId].funcoes.forEach(f => {
                funcSelect.innerHTML += `<option value="${f}">${f}</option>`;
            });
        }
        
        // Populate Members filtered by sectorId
        const membros = await DbService.getMembros();
        const membroContainer = document.getElementById('escala-op-membro-container');
        if (!membroContainer) return;
        
        membroContainer.innerHTML = '';
        
        const filteredMembros = membros.filter(m => {
            if (m.status !== 'ativo') return false;
            const mSetores = m.setores || (m.setor ? [m.setor] : []);
            return mSetores.includes(sectorId) || m.setorId === sectorId || m.setor === sectorId;
        });
        
        if (filteredMembros.length === 0) {
            membroContainer.innerHTML = '<div style="font-size: 0.85rem; color: var(--slate-gray); padding: 5px;">Nenhum voluntário deste setor</div>';
        } else {
            filteredMembros.forEach(m => {
                membroContainer.innerHTML += `
                    <label style="display: flex; align-items: center; gap: 8px; padding: 6px; cursor: pointer; border-bottom: 1px solid #f1f5f9; font-size: 0.9rem;">
                        <input type="checkbox" class="escala-op-membro-checkbox" value="${m.id}" data-nome="${m.nome}" style="width: 16px; height: 16px; accent-color: var(--teal-primary);">
                        ${m.nome}
                    </label>
                `;
            });
        }
    },

    async handleEscalaOperacionalSave(event) {
        event.preventDefault();
        
        const setorId = document.getElementById('escala-op-setor').value;
        const funcao = document.getElementById('escala-op-funcao').value;
        const dataStr = document.getElementById('escala-op-data').value;
        const horaInicio = document.getElementById('escala-op-horainicio').value;
        
        const memberCheckboxes = document.querySelectorAll('.escala-op-membro-checkbox:checked');
        if (memberCheckboxes.length === 0) {
            this.showToast('Selecione pelo menos um voluntário.', 'error');
            return;
        }

        const selectedMembers = Array.from(memberCheckboxes).map(cb => ({
            membroId: cb.value,
            membroNome: cb.getAttribute('data-nome')
        }));
        
        const repeatToggle = document.getElementById('escala-op-repeat-toggle').checked;
        
        try {
            const baseEscalaPartial = {
                setorId,
                funcao,
                horarioInicio: horaInicio,
                horarioFim: "23:59", // Padrão operacional
                statusPresenca: 'Pendente'
            };

            let datasParaCriar = [dataStr];
            
            if (repeatToggle) {
                const dataFimStr = document.getElementById('escala-op-data-fim').value;
                if (!dataFimStr) {
                    this.showToast('Preencha a Data Fim para repetir.', 'error');
                    return;
                }
                
                const dowsCheckboxes = document.querySelectorAll('.escala-op-dow:checked');
                const dows = Array.from(dowsCheckboxes).map(cb => parseInt(cb.value));
                
                const startDt = new Date(dataStr + 'T12:00:00');
                const endDt = new Date(dataFimStr + 'T12:00:00');
                
                if (startDt > endDt) {
                    this.showToast('A Data Fim deve ser maior que a Inicial.', 'error');
                    return;
                }
                
                datasParaCriar = [];
                let currDt = new Date(startDt);
                
                while (currDt <= endDt) {
                    const dayOfWeek = currDt.getDay();
                    if (dows.length === 0 || dows.includes(dayOfWeek)) {
                        const y = currDt.getFullYear();
                        const m = String(currDt.getMonth() + 1).padStart(2, '0');
                        const d = String(currDt.getDate()).padStart(2, '0');
                        datasParaCriar.push(`${y}-${m}-${d}`);
                    }
                    currDt.setDate(currDt.getDate() + 1);
                }
            }
            
            if (datasParaCriar.length === 0) {
                this.showToast('Nenhuma data encontrada no período.', 'error');
                return;
            }

            // Múltiplos saves (Datas x Membros)
            const promises = [];
            datasParaCriar.forEach(d => {
                selectedMembers.forEach(m => {
                    const novaEscala = { 
                        ...baseEscalaPartial, 
                        membroId: m.membroId,
                        membroNome: m.membroNome,
                        data: d, 
                        cultoId: `op-${d}` 
                    };
                    promises.push(DbService.saveEscala(null, novaEscala));
                });
            });
            
            await Promise.all(promises);
            
            this.showToast(promises.length > 1 ? `${promises.length} escalas criadas!` : 'Escala operacional criada!', 'success');
            document.getElementById('modal-escala-operacional-form').classList.remove('active');
            
            this.loadAdminOperacional();
        } catch (error) {
            console.error("Erro ao salvar escala(s) operacional(is):", error);
            this.showToast('Erro ao salvar escala(s).', 'error');
        }
    },

    async deleteEscalaOperacional(escalaId) {
        if (!confirm("Tem certeza que deseja excluir este agendamento operacional?")) return;
        try {
            await DbService.deleteEscala(escalaId);
            this.showToast('Agendamento excluído.', 'success');
            this.loadAdminOperacional();
        } catch (error) {
            console.error("Erro ao excluir:", error);
            this.showToast('Erro ao excluir.', 'error');
        }
    },

    async removerFaltaProduto(produtoId, produtoNome) {
        if (!confirm(`Confirmar que o produto ${produtoNome} foi reposto/comprado e não está mais em falta?`)) return;
        try {
            await db.collection('produtos').doc(produtoId).update({
                statusEstoque: firebase.firestore.FieldValue.delete()
            });
            this.showToast(`Estoque normalizado para ${produtoNome}`, 'success');
            this.loadAdminOperacional();
        } catch (e) {
            console.error(e);
            this.showToast('Erro ao remover falta', 'error');
        }
    },

    // --- TAB: SETORES (ADMIN) ---
    async loadAdminSectors() {
        const container = document.getElementById('admin-organogram-container');
        if (!container) return;
        container.innerHTML = '<div style="text-align:center; padding: 40px; background:white; border-radius:12px; border:1px solid #E2E8F0;"><i class="fa-solid fa-spinner fa-spin fa-2x" style="color:var(--navy-primary);"></i><p style="margin-top:15px; color:var(--slate-gray);">Carregando Organograma...</p></div>';

        try {
            const setores = await DbService.getSetores();
            const membros = await DbService.getMembros();
            
            const supervisors = membros.filter(m => m.perfil === 'admin' && m.status === 'ativo');
            const supervisorName = supervisors.length > 0 ? supervisors.map(s => s.nome).join(' / ') : 'Supervisor Geral';

            let organogramHtml = `
                <div class="sectors-list-container" style="max-width: 900px; margin: 0 auto;">
                    <div style="background: #fff; border-radius: 8px; border: 1px solid #E2E8F0; padding: 20px; margin-bottom: 20px; box-shadow: 0 1px 3px rgba(0,0,0,0.05);">
                        <h3 style="color: var(--navy-primary); font-size: 1.1rem; margin-bottom: 5px;"><i class="fa-solid fa-network-wired" style="color: var(--teal-primary); margin-right: 8px;"></i>Coordenação Geral</h3>
                        <p style="color: var(--slate-gray); font-size: 0.9rem; margin-bottom: 0;"><strong>${supervisorName}</strong> — Administração Matricial</p>
                    </div>
                    <div class="sectors-accordion">
            `;

            setores.forEach(s => {
                const sectorMembers = membros.filter(m => {
                    if (m.status !== 'ativo') return false;
                    const mSetores = m.setores || (m.setor ? [m.setor] : []);
                    return mSetores.includes(s.id);
                });

                const buyers = sectorMembers.filter(m => m.eRepositor === true);
                const operationalMembers = sectorMembers.filter(m => !m.eRepositor);

                const functionGroups = {};
                s.funcoes.forEach(f => {
                    functionGroups[f] = [];
                });
                
                operationalMembers.forEach(m => {
                    const matchedFun = s.funcoes.find(f => m.funcao && m.funcao.toLowerCase().includes(f.toLowerCase())) || s.funcoes[0];
                    if (functionGroups[matchedFun]) {
                        functionGroups[matchedFun].push(m);
                    } else {
                        functionGroups[matchedFun] = [m];
                    }
                });

                let buyersHtml = '';
                if (buyers.length > 0) {
                    buyers.forEach(b => {
                        buyersHtml += `
                            <div class="org-member-badge repositor-badge" style="background: white; border: 1px solid #E9D5FF; padding: 6px 10px; border-radius: 6px; font-size: 0.8rem; margin-bottom: 5px; color: #5F388C;">
                                <i class="fa-solid fa-basket-shopping" style="margin-right: 5px;"></i>
                                <span><b>${b.nome}</b></span>
                            </div>
                        `;
                    });
                } else {
                    buyersHtml = `<div style="font-size:0.8rem; color:#94A3B8; font-style:italic;">Nenhum repositor designado</div>`;
                }

                let operationalHtml = '';
                for (const [func, list] of Object.entries(functionGroups)) {
                    let listHtml = '';
                    if (list.length > 0) {
                        list.forEach(v => {
                            listHtml += `
                                <div class="org-member-badge" style="background: white; border: 1px solid #E2E8F0; padding: 4px 8px; border-radius: 4px; font-size: 0.75rem; margin-bottom: 4px; color: #1E293B;">
                                    <i class="fa-solid fa-user-tag" style="color: #94A3B8; margin-right: 4px;"></i>
                                    <span>${v.nome}</span>
                                </div>
                            `;
                        });
                    } else {
                        listHtml = `<div style="font-size:0.75rem; color:#94A3B8; font-style:italic; padding-left: 5px;">Sem membros escalados</div>`;
                    }
                    operationalHtml += `
                        <div style="margin-bottom: 12px; background: #F1F5F9; padding: 10px; border-radius: 6px;">
                            <div style="font-size:0.75rem; font-weight:700; color: #1E293B; margin-bottom:8px;"><i class="fa-solid fa-chevron-right" style="font-size:0.6rem; color:${s.cor}; margin-right: 5px;"></i> ${func}</div>
                            ${listHtml}
                        </div>
                    `;
                }

                organogramHtml += `
                    <div class="sector-accordion-item" style="background: #fff; border: 1px solid #E2E8F0; border-radius: 8px; margin-bottom: 12px; overflow: hidden; box-shadow: 0 1px 2px rgba(0,0,0,0.02);">
                        <div class="sector-accordion-header" onclick="const b = this.nextElementSibling; b.style.display = b.style.display === 'none' ? 'block' : 'none';" style="padding: 15px 20px; cursor: pointer; display: flex; align-items: center; justify-content: space-between; background: #f8fafc; border-bottom: 1px solid #E2E8F0; transition: background 0.2s;">
                            <div style="display: flex; align-items: center; gap: 12px;">
                                <div style="width: 14px; height: 14px; border-radius: 50%; background-color: ${s.cor}; border: 2px solid white; box-shadow: 0 0 0 1px #CBD5E1;"></div>
                                <span style="font-weight: 700; font-size: 1.05rem; color: #1E293B;">${s.nome}</span>
                            </div>
                            <div style="font-size: 0.85rem; color: var(--slate-gray); font-weight: 500;">
                                ${sectorMembers.length} membro(s) <i class="fa-solid fa-chevron-down" style="margin-left: 10px; font-size: 0.75rem;"></i>
                            </div>
                        </div>
                        <div class="sector-accordion-body" style="display: none; padding: 20px;">
                            <div style="display: grid; grid-template-columns: 1fr 2fr; gap: 20px;">
                                <div class="org-group" style="background: #FDF4FF; border: 1px solid #F5D0FE; padding: 15px; border-radius: 8px;">
                                    <div class="org-group-title" style="color: #701A75; font-size: 0.85rem; font-weight: 700; margin-bottom: 15px; text-transform: uppercase;"><i class="fa-solid fa-cart-flatbed-suitcases"></i> Estoque & Compras</div>
                                    ${buyersHtml}
                                </div>
                                <div class="org-group" style="background: #fff; border: 1px solid #E2E8F0; padding: 15px; border-radius: 8px;">
                                    <div class="org-group-title" style="color: #1E293B; font-size: 0.85rem; font-weight: 700; margin-bottom: 15px; text-transform: uppercase;"><i class="fa-solid fa-users"></i> Funções Operacionais</div>
                                    <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 15px;">
                                        ${operationalHtml}
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                `;
            });

            organogramHtml += `
                    </div>
                </div>
            `;
            
            container.innerHTML = organogramHtml;
        } catch (e) {
            console.error(e);
            container.innerHTML = '<div style="text-align:center; padding: 40px; color:red; background:white; border-radius:12px; border:1px solid #E2E8F0;">Erro ao gerar organograma matricial.</div>';
        }
    },

    // --- TAB: MEMBROS (ADMIN) ---
    async loadAdminMembros() {
        this.renderMembrosTable();
    },

    async renderMembrosTable() {
        const body = document.getElementById('admin-membros-table-body');
        body.innerHTML = '<tr><td colspan="6" style="text-align:center;"><i class="fa-solid fa-spinner fa-spin"></i></td></tr>';

        const filterSector = document.getElementById('member-filter-sector')?.value || '';
        const filterStatus = document.getElementById('member-filter-status')?.value || '';
        const searchQuery = (document.getElementById('member-search-input')?.value || '').toLowerCase().trim();

        try {
            let membros = await DbService.getMembros();

            if (filterSector) {
                membros = membros.filter(m => {
                    if (Array.isArray(m.setores)) return m.setores.includes(filterSector);
                    return m.setor === filterSector;
                });
            }
            if (filterStatus) {
                membros = membros.filter(m => m.status === filterStatus);
            }
            if (searchQuery) {
                membros = membros.filter(m => m.nome?.toLowerCase().includes(searchQuery) || m.funcao?.toLowerCase().includes(searchQuery));
            }

            if (membros.length === 0) {
                body.innerHTML = '<tr><td colspan="6" style="text-align:center; color: var(--slate-gray); padding:30px;">Nenhum membro encontrado com esses filtros.</td></tr>';
                return;
            }

            body.innerHTML = '';
            membros.forEach(m => {
                // Status badge
                let statusBadge;
                if (m.statusOperacional && m.statusOperacional !== 'Disponível') {
                    const opColors = { 'Férias': '#10B981', 'Afastado': '#F59E0B', 'Licença Médica': '#EF4444', 'Viagem / Intercâmbio': '#6366F1', 'Inativo Temporário': '#6B7280' };
                    const cor = opColors[m.statusOperacional] || '#6B7280';
                    statusBadge = `<span style="background:${cor}18; color:${cor}; padding:3px 8px; border-radius:5px; font-size:0.75rem; font-weight:700;">${m.statusOperacional}</span>`;
                } else {
                    statusBadge = m.status === 'ativo'
                        ? '<span class="badge badge-active">Disponível</span>'
                        : '<span class="badge badge-inactive">Inativo</span>';
                }

                // Setor principal (first one only, others truncated)
                const mSetores = (m.perfil === 'admin') ? [] : (m.setores || (m.setor ? [m.setor] : []));
                let setorNome = '-';
                if (m.perfil === 'admin') {
                    setorNome = '<span style="color:#6B7280; font-style:italic;">Admin</span>';
                } else if (mSetores.length === 0) {
                    setorNome = '<span style="color:#94A3B8; font-style:italic;">Sem setor</span>';
                } else if (mSetores.length === 1) {
                    setorNome = this.sectorsData[mSetores[0]]?.nome || mSetores[0];
                } else {
                    const primeiro = this.sectorsData[mSetores[0]]?.nome || mSetores[0];
                    setorNome = `${primeiro} <span title="${mSetores.slice(1).map(s => this.sectorsData[s]?.nome || s).join(', ')}" style="background:#E2E8F0; color:#64748B; padding:2px 6px; border-radius:4px; font-size:0.7rem; cursor:help;">+${mSetores.length - 1}</span>`;
                }

                const funcao = m.funcao || '-';

                // Archive/deactivate instead of delete
                const isAtivo = m.status === 'ativo';
                const archiveBtn = isAtivo
                    ? `<button class="btn-table-action" onclick="App.handleArchiveMembro('${m.id}', '${m.nome.replace(/'/g, "\\'")}')" title="Inativar membro" style="color:#F59E0B;"><i class="fa-solid fa-box-archive"></i></button>`
                    : `<button class="btn-table-action" onclick="App.handleRestoreMembro('${m.id}', '${m.nome.replace(/'/g, "\\'")}')" title="Reativar membro" style="color:#10B981;"><i class="fa-solid fa-rotate-left"></i></button>`;

                const row = document.createElement('tr');
                row.innerHTML = `
                    <td><b>${m.nome}</b></td>
                    <td>${funcao}</td>
                    <td>${setorNome}</td>
                    <td>${statusBadge}</td>
                    <td>
                        <div class="action-buttons">
                            <button class="btn-table-action" onclick="App.handleEditMembro('${m.id}')" title="Editar membro"><i class="fa-solid fa-pen"></i></button>
                            <button class="btn-table-action" onclick="App.openAfastamentoRapidoModal('${m.id}', '${m.nome.replace(/'/g, "\\'")}')" title="Registrar afastamento" style="color:#F59E0B;"><i class="fa-solid fa-person-walking-luggage"></i></button>
                            ${archiveBtn}
                        </div>
                    </td>
                `;
                body.appendChild(row);
            });
        } catch (e) {
            body.innerHTML = '<tr><td colspan="6" style="color:red; text-align:center;">Erro ao carregar membros.</td></tr>';
        }
    },

    async handleArchiveMembro(membroId, nome) {
        if (confirm(`Inativar o membro "${nome}"? Ele não será excluído, mas ficará inativo nas escalas.`)) {
            try {
                await DbService.saveMembro(membroId, { status: 'inativo' });
                this.showToast(`${nome} foi inativado.`, 'success');
                this.renderMembrosTable();
            } catch (e) {
                this.showAlert('Erro ao inativar membro.');
            }
        }
    },

    async handleRestoreMembro(membroId, nome) {
        if (confirm(`Reativar o membro "${nome}"?`)) {
            try {
                await DbService.saveMembro(membroId, { status: 'ativo', statusOperacional: 'Disponível' });
                this.showToast(`${nome} foi reativado.`, 'success');
                this.renderMembrosTable();
            } catch (e) {
                this.showAlert('Erro ao reativar membro.');
            }
        }
    },



    // --- MEMBRO FORM MODAL ---
    switchMembroModalTab(tabId) {
        // Toggle active navigation button styles
        const tabBtns = document.querySelectorAll('#membro-modal-tabs .modal-tab-btn');
        tabBtns.forEach(btn => {
            btn.classList.remove('active');
            btn.style.fontWeight = '600';
            btn.style.color = '#64748B';
            btn.style.borderBottom = 'none';
        });

        // Highlight selected tab button
        const clickedBtn = Array.from(tabBtns).find(btn => btn.getAttribute('onclick').includes(`'${tabId}'`));
        if (clickedBtn) {
            clickedBtn.classList.add('active');
            clickedBtn.style.fontWeight = '700';
            clickedBtn.style.color = 'var(--teal-primary)';
            clickedBtn.style.borderBottom = '2px solid var(--teal-primary)';
        }

        // Toggle actual modal content divs
        const contentDivs = document.querySelectorAll('.membro-modal-tab-content');
        contentDivs.forEach(div => div.style.display = 'none');
        
        const targetDiv = document.getElementById(`membro-tab-${tabId}`);
        if (targetDiv) targetDiv.style.display = 'block';
    },

    async redefinirSenhaMembro() {
        const id = document.getElementById('membro-form-id').value;
        const novaSenha = document.getElementById('membro-nova-senha').value.trim();

        if (!id) {
            this.showAlert('Salve o membro primeiro antes de redefinir sua senha de acesso.');
            return;
        }
        if (!novaSenha) {
            this.showAlert('Por favor, digite a nova senha de acesso.');
            return;
        }

        try {
            App.showLoading();
            // Generate Hash and Salt Client Side
            const salt = DbService.generateSalt();
            const passwordHash = await DbService.hashPassword(novaSenha, salt);
            
            // Save to /credenciais secure collection
            await db.collection('credenciais').doc(id).set({
                passwordHash,
                passwordSalt: salt
            });

            // Also keep legacy password text on member doc for app.js legacy authentication compatibility
            await db.collection('membros').doc(id).update({
                senha: novaSenha
            });

            App.hideLoading();
            this.showToast('Senha de acesso redefinida com sucesso!', 'success');
            document.getElementById('membro-nova-senha').value = '';
        } catch (e) {
            App.hideLoading();
            console.error(e);
            this.showAlert('Erro ao redefinir a senha do membro.');
        }
    },

    openMembroFormModal() {
        document.getElementById('membro-modal-title').innerText = "Cadastrar Novo Membro";
        document.getElementById('membro-form-id').value = '';
        document.getElementById('membro-form').reset();
        
        // Hide password reset block for new member creation (must save first)
        document.getElementById('redefinir-senha-bloco').style.display = 'none';

        // Reset operational status and absence fields
        document.getElementById('membro-status-operacional').value = 'Disponível';
        document.getElementById('membro-afastamento-inicio').value = '';
        document.getElementById('membro-afastamento-fim').value = '';
        document.getElementById('membro-afastamento-motivo').value = '';
        document.getElementById('membro-afastamento-obs').value = '';
        document.getElementById('membro-afastamento-retorno').value = 'Sim';
        this.toggleAfastamentoDatesFields('Disponível');
        
        // Reset birthdate field
        const birthdateEl = document.getElementById('membro-data-nascimento');
        if (birthdateEl) birthdateEl.value = '';
        
        // Reset checkbox explicitly
        document.getElementById('membro-e-repositor').checked = false;
        
        // Reset advanced fields to defaults
        document.getElementById('membro-sexo').value = 'Masculino';
        document.getElementById('membro-disponibilidade').value = 'Todos';
        if (document.getElementById('membro-funcao-principal')) {
            document.getElementById('membro-funcao-principal').value = '';
        }
        if (document.getElementById('membro-funcao-principal-custom')) {
            document.getElementById('membro-funcao-principal-custom').value = '';
            document.getElementById('membro-funcao-principal-custom').style.display = 'none';
        }
        if (document.getElementById('membro-funcao-secundaria')) {
            document.getElementById('membro-funcao-secundaria').value = '';
        }
        if (document.getElementById('membro-funcao-secundaria-custom')) {
            document.getElementById('membro-funcao-secundaria-custom').value = '';
            document.getElementById('membro-funcao-secundaria-custom').style.display = 'none';
        }
        document.getElementById('membro-participa-substituicao').value = 'Sim';
        document.getElementById('membro-prioridade').value = 'Normal';
        
        // Render empty checkboxes
        this.renderMembroSetoresCheckboxes([]);
        this.updateMembroFuncoesOptions([], '', '');
        
        // Reset modal tabs to first tab
        this.switchMembroModalTab('id');

        document.getElementById('modal-membro-form').classList.add('active');
    },

    closeMembroFormModal() {
        document.getElementById('modal-membro-form').classList.remove('active');
    },

    updateMembroFuncoesOptions(selectedSectors = [], currentPrincipal = '', currentSecundaria = '') {
        const selectPrincipal = document.getElementById('membro-funcao-principal');
        const selectSecundaria = document.getElementById('membro-funcao-secundaria');
        const customPrincipal = document.getElementById('membro-funcao-principal-custom');
        const customSecundaria = document.getElementById('membro-funcao-secundaria-custom');

        if (!selectPrincipal || !selectSecundaria) return;

        // Gather all standard functions from selected sectors
        let availableFunctions = [];
        if (selectedSectors.length > 0) {
            selectedSectors.forEach(secId => {
                const sector = this.sectorsData[secId];
                if (sector && sector.funcoes) {
                    availableFunctions.push(...sector.funcoes);
                }
            });
        } else {
            // If no sectors are selected, show functions from all sectors
            Object.values(this.sectorsData).forEach(sector => {
                if (sector.funcoes) {
                    availableFunctions.push(...sector.funcoes);
                }
            });
        }
        
        // Remove duplicates
        availableFunctions = Array.from(new Set(availableFunctions));

        // Helper to populate a select
        const populateSelect = (selectEl, customEl, currentValue) => {
            selectEl.innerHTML = '<option value="">Nenhuma</option>';
            
            // Add functions
            availableFunctions.forEach(fun => {
                const opt = document.createElement('option');
                opt.value = fun;
                opt.textContent = fun;
                selectEl.appendChild(opt);
            });

            // Add "Outra" option
            const optOutra = document.createElement('option');
            optOutra.value = "outro";
            optOutra.textContent = "Outra (Digitar...)";
            selectEl.appendChild(optOutra);

            // Determine what value to set
            if (!currentValue) {
                selectEl.value = "";
                customEl.value = "";
                customEl.style.display = "none";
            } else if (availableFunctions.includes(currentValue)) {
                selectEl.value = currentValue;
                customEl.value = "";
                customEl.style.display = "none";
            } else {
                selectEl.value = "outro";
                customEl.value = currentValue;
                customEl.style.display = "block";
            }
        };

        populateSelect(selectPrincipal, customPrincipal, currentPrincipal);
        populateSelect(selectSecundaria, customSecundaria, currentSecundaria);

        // Update general function suggestions
        const datalistGeral = document.getElementById('membro-funcao-sugestoes');
        if (datalistGeral) {
            datalistGeral.innerHTML = '';
            availableFunctions.forEach(fun => {
                const opt = document.createElement('option');
                opt.value = fun;
                datalistGeral.appendChild(opt);
            });
        }
    },

    handleFuncaoPrincipalChange(val) {
        const customEl = document.getElementById('membro-funcao-principal-custom');
        if (val === 'outro') {
            customEl.style.display = 'block';
            customEl.required = true;
            customEl.focus();
        } else {
            customEl.style.display = 'none';
            customEl.required = false;
        }
    },
    
    handleFuncaoSecundariaChange(val) {
        const customEl = document.getElementById('membro-funcao-secundaria-custom');
        if (val === 'outro') {
            customEl.style.display = 'block';
            customEl.required = true;
            customEl.focus();
        } else {
            customEl.style.display = 'none';
            customEl.required = false;
        }
    },

    handleMembroPerfilChange(perfil) {
        const fields = document.getElementById('membro-setor-funcao-fields');
        if (perfil === 'admin') {
            fields.style.display = 'none';
            document.getElementById('membro-funcao').required = false;
        } else {
            fields.style.display = 'block';
            document.getElementById('membro-funcao').required = true;
        }
    },

    renderMembroSetoresCheckboxes(selectedSectors = []) {
        const container = document.getElementById('membro-setores-checkboxes');
        if (!container) return;
        container.innerHTML = '';

        for (const [key, sector] of Object.entries(this.sectorsData)) {
            const isChecked = selectedSectors.includes(key);
            const wrapper = document.createElement('label');
            wrapper.className = 'checkbox-label';
            wrapper.style.display = 'flex';
            wrapper.style.alignItems = 'center';
            wrapper.style.gap = '8px';
            wrapper.style.cursor = 'pointer';
            wrapper.style.padding = '8px';
            wrapper.style.borderRadius = '8px';
            wrapper.style.background = isChecked ? `${sector.cor}15` : 'transparent';
            wrapper.style.border = `1px solid ${isChecked ? sector.cor : 'rgba(0,0,0,0.05)'}`;
            wrapper.style.transition = 'all 0.2s ease';

            const checkbox = document.createElement('input');
            checkbox.type = 'checkbox';
            checkbox.value = key;
            checkbox.checked = isChecked;
            checkbox.style.accentColor = sector.cor;
            
            checkbox.onchange = (e) => {
                if (checkbox.checked) {
                    wrapper.style.background = `${sector.cor}15`;
                    wrapper.style.border = `1px solid ${sector.cor}`;
                } else {
                    wrapper.style.background = 'transparent';
                    wrapper.style.border = '1px solid rgba(0,0,0,0.05)';
                }
                
                // Dynamically update function options based on checked sectors
                const checkedBoxes = document.querySelectorAll('#membro-setores-checkboxes input[type="checkbox"]:checked');
                const selected = Array.from(checkedBoxes).map(cb => cb.value);
                
                const valP = document.getElementById('membro-funcao-principal').value;
                const currentP = valP === 'outro' ?
                    document.getElementById('membro-funcao-principal-custom').value : valP;
                    
                const valS = document.getElementById('membro-funcao-secundaria').value;
                const currentS = valS === 'outro' ?
                    document.getElementById('membro-funcao-secundaria-custom').value : valS;
                
                this.updateMembroFuncoesOptions(selected, currentP, currentS);
            };

            const span = document.createElement('span');
            span.innerText = sector.nome;
            span.style.fontSize = '0.9rem';
            span.style.color = 'var(--navy-dark)';
            span.style.fontWeight = '500';

            wrapper.appendChild(checkbox);
            wrapper.appendChild(span);
            container.appendChild(wrapper);
        }
    },

    async handleEditMembro(id) {
        try {
            const membros = await DbService.getMembros();
            const m = membros.find(item => item.id === id);
            if (!m) return;

            document.getElementById('membro-modal-title').innerText = "Editar Membro";
            document.getElementById('membro-form-id').value = m.id;
            document.getElementById('membro-nome').value = m.nome;
            document.getElementById('membro-foto-url').value = m.fotoUrl || '';

            const birthdateEl = document.getElementById('membro-data-nascimento');
            if (birthdateEl) birthdateEl.value = m.dataNascimento || '';
            document.getElementById('membro-email').value = m.email;
            
            // Show password reset block when editing an existing member
            document.getElementById('redefinir-senha-bloco').style.display = 'block';
            document.getElementById('membro-nova-senha').value = '';

            document.getElementById('membro-perfil').value = m.perfil;
            document.getElementById('membro-status').value = m.status;

            // Populate operational status and absence fields
            const opStatus = m.statusOperacional || 'Disponível';
            document.getElementById('membro-status-operacional').value = opStatus;
            document.getElementById('membro-afastamento-inicio').value = m.afastamentoInicio || '';
            document.getElementById('membro-afastamento-fim').value = m.afastamentoFim || '';
            document.getElementById('membro-afastamento-motivo').value = m.afastamentoMotivo || '';
            document.getElementById('membro-afastamento-obs').value = m.afastamentoObsSupervisao || '';
            document.getElementById('membro-afastamento-retorno').value = m.afastamentoRetornoAutomativo || 'Sim';
            this.toggleAfastamentoDatesFields(opStatus);

            this.handleMembroPerfilChange(m.perfil);

            if (m.perfil !== 'admin') {
                let selectedSectors = [];
                if (Array.isArray(m.setores)) {
                    selectedSectors = m.setores;
                } else if (m.setor) {
                    selectedSectors = [m.setor];
                }
                this.renderMembroSetoresCheckboxes(selectedSectors);
                document.getElementById('membro-funcao').value = m.funcao || '';
                
                // Advanced fields
                document.getElementById('membro-sexo').value = m.sexo || 'Masculino';
                document.getElementById('membro-disponibilidade').value = m.disponibilidade || 'Todos';
                this.updateMembroFuncoesOptions(selectedSectors, m.funcaoPrincipal || '', m.funcaoSecundaria || '');
                document.getElementById('membro-participa-substituicao').value = m.participaSubstituicao || 'Sim';
                document.getElementById('membro-prioridade').value = m.prioridade || 'Normal';
            }

            document.getElementById('membro-e-repositor').checked = !!m.eRepositor;
            
            // Switch tabs in modal back to first tab
            this.switchMembroModalTab('id');
            
            document.getElementById('modal-membro-form').classList.add('active');
        } catch (e) {
            this.showAlert('Erro ao buscar dados do membro.');
        }
    },

    async handleMembroSave(event) {
        event.preventDefault();
        const id = document.getElementById('membro-form-id').value;
        const nome = document.getElementById('membro-nome').value.trim();
        const fotoUrl = document.getElementById('membro-foto-url').value.trim();
        const email = document.getElementById('membro-email').value.toLowerCase().trim();
        const perfil = document.getElementById('membro-perfil').value;
        const status = document.getElementById('membro-status').value;
        
        let setor = null;
        let setores = [];
        let funcao = 'Administrador';
        
        let sexo = 'Masculino';
        let disponibilidade = 'Todos';
        let funcaoPrincipal = '';
        let funcaoSecundaria = '';
        let participaSubstituicao = 'Sim';
        let prioridade = 'Normal';

        if (perfil !== 'admin') {
            const checkedBoxes = document.querySelectorAll('#membro-setores-checkboxes input[type="checkbox"]:checked');
            checkedBoxes.forEach(cb => setores.push(cb.value));
            
            funcao = document.getElementById('membro-funcao').value.trim();
            if (setores.length === 0) {
                this.showAlert('Por favor, selecione pelo menos um setor de atuação.');
                return;
            }
            if (!funcao) {
                this.showAlert('Por favor, defina a função para o membro.');
                return;
            }
            // Fallback for single sector field
            setor = setores[0];
            
            sexo = document.getElementById('membro-sexo').value;
            disponibilidade = document.getElementById('membro-disponibilidade').value;
            
            const selectValP = document.getElementById('membro-funcao-principal').value;
            funcaoPrincipal = selectValP === 'outro' ?
                document.getElementById('membro-funcao-principal-custom').value.trim() : selectValP.trim();
                
            const selectValS = document.getElementById('membro-funcao-secundaria').value;
            funcaoSecundaria = selectValS === 'outro' ?
                document.getElementById('membro-funcao-secundaria-custom').value.trim() : selectValS.trim();
                
            participaSubstituicao = document.getElementById('membro-participa-substituicao').value;
            prioridade = document.getElementById('membro-prioridade').value;
        }

        const statusOperacional = document.getElementById('membro-status-operacional').value;
        const afastamentoInicio = document.getElementById('membro-afastamento-inicio').value;
        const afastamentoFim = document.getElementById('membro-afastamento-fim').value;
        const afastamentoMotivo = document.getElementById('membro-afastamento-motivo').value.trim();
        const afastamentoObsSupervisao = document.getElementById('membro-afastamento-obs').value.trim();
        const afastamentoRetornoAutomativo = document.getElementById('membro-afastamento-retorno').value;

        if (statusOperacional !== 'Disponível') {
            if (!afastamentoInicio || !afastamentoFim || !afastamentoMotivo) {
                this.showAlert('Por favor, preencha as datas e o motivo do afastamento.');
                return;
            }
            if (afastamentoFim < afastamentoInicio) {
                this.showAlert('A data final prevista não pode ser anterior à data inicial.');
                return;
            }
            // Check future scales
            if (id) {
                const hojeStr = new Date().toISOString().split('T')[0];
                try {
                    const escalas = await DbService.getEscalas();
                    const escalasFuturas = escalas.filter(esc => esc.membroId === id && esc.data >= hojeStr);
                    if (escalasFuturas.length > 0) {
                        const confirmar = confirm(`Atenção: O membro possui ${escalasFuturas.length} escala(s) futura(s) agendada(s) (a partir de hoje). Ao confirmar o afastamento, essas escalas precisarão ser revisadas ou substituídas. Deseja continuar?`);
                        if (!confirmar) return;
                    }
                } catch (err) {
                    console.error("Erro ao verificar escalas futuras:", err);
                }
            }
        }

        try {
            const eRepositor = document.getElementById('membro-e-repositor').checked;
            const birthdateEl = document.getElementById('membro-data-nascimento');
            const dataNascimento = birthdateEl ? birthdateEl.value : '';

            // Check if operational status changed or dates changed to append to history
            let statusChangedOrNewAfastamento = false;
            if (statusOperacional !== 'Disponível') {
                if (id) {
                    const membros = await DbService.getMembros();
                    const m = membros.find(item => item.id === id);
                    if (m) {
                        if (m.statusOperacional !== statusOperacional ||
                            m.afastamentoInicio !== afastamentoInicio ||
                            m.afastamentoFim !== afastamentoFim ||
                            m.afastamentoMotivo !== afastamentoMotivo) {
                            statusChangedOrNewAfastamento = true;
                        }
                    }
                } else {
                    statusChangedOrNewAfastamento = true;
                }
            }

            const membroData = {
                nome,
                email,
                perfil,
                setor,
                setores,
                funcao,
                status,
                fotoUrl,
                dataNascimento,
                eRepositor: !!eRepositor,
                sexo,
                disponibilidade,
                funcaoPrincipal,
                funcaoSecundaria,
                participaSubstituicao,
                prioridade,
                statusOperacional,
                afastamentoInicio: statusOperacional === 'Disponível' ? '' : afastamentoInicio,
                afastamentoFim: statusOperacional === 'Disponível' ? '' : afastamentoFim,
                afastamentoMotivo: statusOperacional === 'Disponível' ? '' : afastamentoMotivo,
                afastamentoObsSupervisao: statusOperacional === 'Disponível' ? '' : afastamentoObsSupervisao,
                afastamentoRetornoAutomativo: statusOperacional === 'Disponível' ? 'Sim' : afastamentoRetornoAutomativo
            };

            const savedId = await DbService.saveMembro(id ? id : null, membroData);

            if (statusChangedOrNewAfastamento && savedId) {
                // Also trigger saveAfastamento to log in history
                await DbService.saveAfastamento(savedId, {
                    statusOperacional,
                    afastamentoInicio,
                    afastamentoFim,
                    afastamentoMotivo,
                    afastamentoObsSupervisao,
                    afastamentoRetornoAutomativo
                });

                // FASE 2: Remover obreiro de escalas conflitantes futuras no período
                await this.removerMembroDeEscalasConflitantes(savedId, nome, afastamentoInicio, afastamentoFim, statusOperacional);
            }

            this.closeMembroFormModal();
            this.showToast('Membro salvo com sucesso!', 'success');
            this.renderMembrosTable();
            if (this.adminActiveTab === 'afastamentos') {
                this.loadAndRenderAdminAfastamentos();
            }
        } catch (e) {
            console.error(e);
            this.showAlert('Erro ao gravar membro.');
        }
    },

    async handleDeleteMembro(id, nome) {
        if (confirm(`Tem certeza que deseja excluir permanentemente o membro "${nome}"?`)) {
            try {
                await DbService.deleteMembro(id);
                this.showToast('Membro removido!', 'success');
                this.renderMembrosTable();
            } catch (e) {
                this.showAlert('Erro ao remover membro.');
            }
        }
    },

    // --- AUTO-MIGRAÇÃO DE ESCALAS LEGADAS ---
    async autoMigrateLegacyScales() {
        try {
            console.log("Checking for legacy scales to migrate...");
            const escalas = await DbService.getEscalas();
            const legacyScales = escalas.filter(e => !e.cultoId && !this.isOperationalSector(e.setorId));
            
            if (legacyScales.length === 0) {
                console.log("No legacy scales to migrate.");
                return;
            }
            
            console.log(`Found ${legacyScales.length} legacy scales. Migrating...`);
            
            // Agrupar por data + horarioInicio + horarioFim
            const groups = {};
            legacyScales.forEach(e => {
                const key = `${e.data}_${e.horarioInicio}_${e.horarioFim}`;
                if (!groups[key]) groups[key] = [];
                groups[key].push(e);
            });
            
            const cultosExistentes = await DbService.getCultos();
            
            for (const key in groups) {
                const scalesInGroup = groups[key];
                const [data, inicio, fim] = key.split('_');
                
                // Verificar se já existe um culto nesta data e horario
                let culto = cultosExistentes.find(c => c.data === data && c.horarioInicio === inicio && c.horarioFim === fim);
                let cultoId = culto ? culto.id : null;
                let cultoNome = culto ? culto.nome : null;
                
                if (!cultoId) {
                    // Criar um culto correspondente
                    const dateParts = data.split('-');
                    const formattedDate = `${dateParts[2]}/${dateParts[1]}/${dateParts[0]}`;
                    
                    let deducedName = "Culto Especial";
                    const dateObj = new Date(dateParts[0], dateParts[1] - 1, dateParts[2]);
                    const dayOfWeek = dateObj.getDay();
                    
                    if (dayOfWeek === 0) {
                        deducedName = inicio < "13:00" ? "Domingo Manhã" : "Domingo Noite";
                    } else if (dayOfWeek === 3) {
                        deducedName = "Quarta Ensino";
                    } else if (dayOfWeek === 5) {
                        deducedName = "Sexta Oração";
                    } else {
                        deducedName = "Evento Especial";
                    }
                    
                    cultoNome = deducedName;
                    cultoId = await DbService.saveCulto(null, {
                        nome: cultoNome,
                        data: data,
                        horarioInicio: inicio,
                        horarioFim: fim,
                        status: "Confirmado",
                        tipo: dayOfWeek === 0 || dayOfWeek === 3 || dayOfWeek === 5 ? "regular" : "especial"
                    });
                    console.log(`Created new automatic culto: ${cultoNome} on ${formattedDate}`);
                }
                
                // Associar escalas ao culto
                for (const escala of scalesInGroup) {
                    await DbService.saveEscala(escala.id, {
                        cultoId: cultoId,
                        cultoNome: cultoNome
                    });
                }
                console.log(`Associated ${scalesInGroup.length} scales to cultoId ${cultoId}`);
            }
            console.log("Migration complete!");
        } catch (e) {
            console.error("Error migrating legacy scales:", e);
        }
    },

    // --- TAB: ESCALAS (ADMIN) ---
    async loadAdminEscalas() {
        // Mostra spinner imediatamente para evitar tela em branco durante awaits
        const calendarEl = document.getElementById('admin-calendar-container');
        if (calendarEl) {
            calendarEl.innerHTML = `
                <div style="display:flex; flex-direction:column; align-items:center; justify-content:center; padding: 60px 20px; gap: 16px;">
                    <i class="fa-solid fa-spinner fa-spin fa-2x" style="color:var(--teal-primary);"></i>
                    <p style="color:var(--slate-gray); font-size:0.9rem; margin:0;">Carregando calendário...</p>
                </div>`;
        }

        // Executa migração de dados legados
        await this.autoMigrateLegacyScales();
        
        // Carrega alertas e notificações da supervisão (v3.2)
        await this.loadAndRenderSupervisorAlerts();
        
        try {
            this.cultosData = await DbService.getCultos();
            
            // Render Admin Calendar (New Premium Calendar view)
            await this.renderPremiumCalendar(true);
            
            const calContainer = document.getElementById('admin-calendar-view-container');
            const detailContainer = document.getElementById('admin-selected-culto-section');
            
            const opContainer = document.getElementById('admin-escalas-operacionais-container');
            
            if (this.adminSelectedCultoId) {
                const exists = this.cultosData.some(c => c.id === this.adminSelectedCultoId);
                if (exists) {
                    if (calContainer) calContainer.style.display = 'none';
                    if (detailContainer) detailContainer.style.display = 'block';
                    if (opContainer) opContainer.style.display = 'none';
                    this.selectAdminCulto(this.adminSelectedCultoId);
                    return;
                }
            }
            
            // Restaurar estado da aba ativa ou padronizar para 'cultos'
            this.activeEscalasSubTab = this.activeEscalasSubTab || 'cultos';
            this.switchEscalasSubTab(this.activeEscalasSubTab);
            
            if (this.activeEscalasSubTab === 'operacionais') {
                this.renderEscalasOperacionais();
            }
        } catch (e) {
            console.error("Erro ao carregar cultos:", e);
            // Exibe mensagem de erro e botão de tentar novamente no container correto
            const calViewContainer = document.getElementById('admin-calendar-view-container');
            if (calViewContainer) calViewContainer.style.display = 'block';
            const calContainer = document.getElementById('admin-calendar-container');
            if (calContainer) {
                calContainer.innerHTML = `
                    <div style="background: #FEF2F2; border: 1px solid #F87171; border-radius: 8px; padding: 30px; text-align: center; margin-top: 20px;">
                        <i class="fa-solid fa-triangle-exclamation" style="font-size: 2rem; color: #EF4444; margin-bottom: 15px;"></i>
                        <h3 style="color: #991B1B; margin-bottom: 10px; font-size: 1.1rem;">Falha ao carregar os dados de Cultos</h3>
                        <p style="color: #7F1D1D; font-size: 0.9rem; margin-bottom: 20px;">Isso pode acontecer por instabilidade na rede ou permissões do servidor em sincronização. Detalhe técnico: ${e.message}</p>
                        <button class="btn-primary" onclick="App.loadAdminDashboard()" style="background: #DC2626; padding: 8px 16px; border-radius: 6px; font-size: 0.9rem;">
                            <i class="fa-solid fa-rotate-right" style="margin-right: 6px;"></i>Tentar Novamente
                        </button>
                    </div>
                `;
            }
        }
    },

    switchEscalasSubTab(tab) {
        this.activeEscalasSubTab = tab;
        
        const btnCultos = document.getElementById('btn-tab-cultos');
        const btnOp = document.getElementById('btn-tab-operacionais');
        const calContainer = document.getElementById('admin-calendar-view-container');
        const opContainer = document.getElementById('admin-escalas-operacionais-container');
        const detailContainer = document.getElementById('admin-selected-culto-section');
        
        if (btnCultos && btnOp) {
            if (tab === 'cultos') {
                btnCultos.style.background = 'var(--teal-primary)';
                btnCultos.style.color = 'white';
                btnCultos.style.borderColor = 'transparent';
                
                btnOp.style.background = 'transparent';
                btnOp.style.color = 'var(--navy-dark)';
                btnOp.style.borderColor = '#CBD5E1';
                
                if (calContainer) calContainer.style.display = 'block';
                if (opContainer) opContainer.style.display = 'none';
                
                // Se houvesse um culto selecionado antes, e formos para cultos, não o mostramos automaticamente se a aba estava no calendário, mas mantemos o fluxo do loadAdminDashboard
            } else if (tab === 'operacionais') {
                btnOp.style.background = 'var(--teal-primary)';
                btnOp.style.color = 'white';
                btnOp.style.borderColor = 'transparent';
                
                btnCultos.style.background = 'transparent';
                btnCultos.style.color = 'var(--navy-dark)';
                btnCultos.style.borderColor = '#CBD5E1';
                
                if (calContainer) calContainer.style.display = 'none';
                if (detailContainer) detailContainer.style.display = 'none';
                if (opContainer) {
                    opContainer.style.display = 'block';
                    this.renderEscalasOperacionais();
                }
            }
        }
    },

    renderAdminCultoCards() {
        const cultosList = document.getElementById('admin-cultos-list');
        cultosList.innerHTML = '';
        
        this.cultosData.forEach(c => {
            const dateParts = c.data.split('-');
            const formattedDate = `${dateParts[2]}/${dateParts[1]}/${dateParts[0]}`;
            
            const card = document.createElement('div');
            card.className = `culto-card ${c.id === this.adminSelectedCultoId ? 'active' : ''}`;
            card.id = `culto-card-${c.id}`;
            card.setAttribute('onclick', `App.selectAdminCulto('${c.id}')`);
            
            let statusClass = 'badge-inactive';
            if (c.status === 'Confirmado') statusClass = 'badge-active';
            if (c.tipo === 'especial') statusClass = 'badge-especial';
            
            const selectionCircle = c.id === this.adminSelectedCultoId 
                ? '<span class="selection-circle active"><i class="fa-solid fa-circle-check"></i></span>'
                : '<span class="selection-circle"></span>';
            
            card.innerHTML = `
                <div style="display:flex; justify-content:space-between; align-items:flex-start; margin-bottom:10px;">
                    ${selectionCircle}
                    <span class="badge-status ${statusClass}">${c.tipo === 'especial' ? 'Evento' : c.status}</span>
                </div>
                <h4 style="margin: 0 0 5px 0; font-size: 1rem; font-weight: 700; color: var(--navy-dark);">${c.nome}</h4>
                <p style="margin: 0; font-size: 0.8rem; color: var(--slate-gray); font-weight: 500;">
                    ${formattedDate} • ${c.horarioInicio}
                </p>
            `;
            cultosList.appendChild(card);
        });
    },

    async selectAdminCulto(cultoId) {
        console.log("DEBUG: [selectAdminCulto] INÍCIO - chamado com cultoId:", cultoId);
        try {
            this.adminSelectedCultoId = cultoId;
            
            const calContainer = document.getElementById('admin-calendar-view-container');
            const detailContainer = document.getElementById('admin-selected-culto-section');
            const opContainer = document.getElementById('admin-escalas-operacionais-container');
            if (calContainer && detailContainer) {
                console.log("DEBUG: [selectAdminCulto] Trocando visibilidade dos containers. calContainer = none, detailContainer = block");
                calContainer.style.display = 'none';
                detailContainer.style.display = 'block';
            } else {
                console.warn("DEBUG: [selectAdminCulto] calContainer ou detailContainer não encontrado no DOM!");
            }
            if (opContainer) {
                opContainer.style.display = 'none';
            }
            
            // Highlight selected event pill in calendar
            console.log("DEBUG: [selectAdminCulto] Atualizando destaque das pílulas no calendário");
            document.querySelectorAll('.calendar-event-pill').forEach(pill => {
                pill.style.boxShadow = '';
                pill.style.fontWeight = '700';
            });
            const activePills = document.querySelectorAll(`[onclick*="selectAdminCulto('${cultoId}')"]`);
            activePills.forEach(pill => {
                pill.style.boxShadow = '0 0 0 2px var(--teal-primary) !important';
                pill.style.fontWeight = '800';
            });

            // Atualizar classe ativa nos cards
            console.log("DEBUG: [selectAdminCulto] Atualizando visualização dos cards");
            document.querySelectorAll('.culto-card').forEach(card => {
                card.classList.remove('active');
                const circle = card.querySelector('.selection-circle');
                if (circle) {
                    circle.classList.remove('active');
                    circle.innerHTML = '';
                }
            });
            
            const activeCard = document.getElementById(`culto-card-${cultoId}`);
            if (activeCard) {
                activeCard.classList.add('active');
                const circle = activeCard.querySelector('.selection-circle');
                if (circle) {
                    circle.classList.add('active');
                    circle.innerHTML = '<i class="fa-solid fa-circle-check"></i>';
                }
            }
            
            // Buscar dados do culto ativo
            if (!this.cultosData) {
                console.warn("DEBUG: [selectAdminCulto] this.cultosData é undefined/null. Buscando do banco...");
                this.cultosData = await DbService.getCultos();
            }
            
            const c = this.cultosData.find(item => item.id === cultoId);
            if (!c) {
                console.warn("DEBUG: [selectAdminCulto] Culto não encontrado em this.cultosData para o ID:", cultoId);
                return;
            }
            
            console.log("DEBUG: [selectAdminCulto] Culto localizado com sucesso:", c.nome, c.data);
            
            const dateParts = c.data.split('-');
            const formattedDate = `${dateParts[2]}/${dateParts[1]}/${dateParts[0]}`;
            
            const elName = document.getElementById('admin-active-culto-name');
            const elDate = document.getElementById('admin-active-culto-date');
            const elTime = document.getElementById('admin-active-culto-time');
            
            if (elName) elName.innerText = c.nome;
            if (elDate) elDate.innerText = formattedDate;
            if (elTime) elTime.innerText = `${c.horarioInicio} às ${c.horarioFim}`;
            
            const statusBadge = document.getElementById('admin-active-culto-status-badge');
            if (statusBadge) {
                statusBadge.innerText = c.status;
                statusBadge.className = '';
                if (c.status === 'Confirmado') {
                    statusBadge.className = 'badge badge-active';
                } else {
                    statusBadge.className = 'badge badge-inactive';
                }
            }
            
            // Fechar dropdown de ações do culto
            const elActionsMenu = document.getElementById('active-culto-actions-menu');
            if (elActionsMenu) elActionsMenu.style.display = 'none';
            
            // Atualizar textos do menu de ações dependendo do tipo
            const actionEdit = document.getElementById('action-edit-culto');
            const actionDelete = document.getElementById('action-delete-culto');
            if (actionEdit && actionDelete) {
                const isEspecial = c.tipo === 'especial';
                actionEdit.innerHTML = `<i class="fa-solid fa-pen" style="margin-right: 5px;"></i> Editar ${isEspecial ? 'Evento' : 'Culto'}`;
                actionDelete.innerHTML = `<i class="fa-solid fa-trash" style="margin-right: 5px;"></i> Excluir ${isEspecial ? 'Evento' : 'Culto'}`;
            }
            
            // Carregar e renderizar escalas deste culto
            console.log("DEBUG: [selectAdminCulto] chamando loadAndRenderAdminEscalas");
            await this.loadAndRenderAdminEscalas();
        } catch (e) {
            console.error("DEBUG: [selectAdminCulto] CATCH COM ERRO COMPLETO:", e);
        }
    },

    toggleActiveCultoActionsDropdown(event) {
        event.stopPropagation();
        const menu = document.getElementById('active-culto-actions-menu');
        const isVisible = menu.style.display === 'block';
        
        menu.style.display = isVisible ? 'none' : 'block';
        
        if (!isVisible) {
            const closeMenu = (e) => {
                menu.style.display = 'none';
                document.removeEventListener('click', closeMenu);
            };
            setTimeout(() => document.addEventListener('click', closeMenu), 0);
        }
    },

    async loadAndRenderAdminEscalas() {
        console.log("DEBUG: [loadAndRenderAdminEscalas] INÍCIO - adminSelectedCultoId:", this.adminSelectedCultoId);
        const container = document.getElementById('admin-escalas-sectors-accordion');
        if (!container) {
            console.warn("DEBUG: [loadAndRenderAdminEscalas] Container admin-escalas-sectors-accordion não encontrado no DOM.");
            return;
        }
        
        container.innerHTML = '<div style="text-align:center; padding:40px;"><i class="fa-solid fa-spinner fa-spin fa-2x" style="color:var(--teal-primary);"></i><p style="margin-top:10px; font-size:0.9rem;">Buscando escalas...</p></div>';
        
        if (!this.adminSelectedCultoId) {
            console.log("DEBUG: [loadAndRenderAdminEscalas] Sem culto selecionado.");
            container.innerHTML = '<div style="text-align:center; padding:40px; color:var(--slate-gray);"><i class="fa-solid fa-hand-pointer fa-2x" style="opacity:0.5; margin-bottom:15px; display:block;"></i><p>Selecione um evento ou culto no menu superior para visualizar as escalas.</p></div>';
            return;
        }
        
        try {
            console.log("DEBUG: [loadAndRenderAdminEscalas] Buscando escalas para cultoId:", this.adminSelectedCultoId);
            const escalas = await DbService.getEscalas(null, null, null, this.adminSelectedCultoId);
            console.log("DEBUG: [loadAndRenderAdminEscalas] Escalas retornadas do DB. Quantidade:", escalas ? escalas.length : 0);
            
            container.innerHTML = '';
            
            let totalFunctions = 0;
            let totalScheduled = 0;
            let totalPending = 0;
            let totalConfirmed = 0;
            
            if (!this.cultosData) {
                console.log("DEBUG: [loadAndRenderAdminEscalas] this.cultosData nulo, buscando do banco...");
                this.cultosData = await DbService.getCultos();
            }
            
            const c = this.cultosData.find(item => item.id === this.adminSelectedCultoId);
            const cultoTipo = c ? c.tipo : 'regular';
            
            console.log("DEBUG: [loadAndRenderAdminEscalas] Renderizando acordeão de setores...");
            for (const sectorId in this.sectorsData) {
                if (this.isOperationalSector(sectorId)) continue;
                const sector = this.sectorsData[sectorId];
                const sectorEscalas = escalas.filter(e => e.setorId === sectorId);
                
                const funcoes = this.getSectorFunctions(sectorId, cultoTipo);
                const totalSectorFuncs = funcoes.length;
                
                if (totalSectorFuncs === 0 && sectorEscalas.length === 0) {
                    continue;
                }
                
                let preenchidas = 0;
                funcoes.forEach(func => {
                    if (sectorEscalas.some(e => e.funcao.toLowerCase().trim() === func.toLowerCase().trim())) {
                        preenchidas++;
                    }
                });
                
                totalFunctions += totalSectorFuncs;
                totalScheduled += sectorEscalas.length;
                
                sectorEscalas.forEach(e => {
                    if (e.statusPresenca === 'Pendente') totalPending++;
                    if (e.statusPresenca === 'Confirmada') totalConfirmed++;
                });
                
                if (this.openAccordions[sectorId] === undefined) {
                    this.openAccordions[sectorId] = sectorId === 'entrada';
                }
                
                const isOpen = this.openAccordions[sectorId];
                
                const accordion = document.createElement('div');
                accordion.className = 'sector-accordion';
                accordion.style.borderLeft = `4px solid ${sector.cor}`;
                
                let progressBadgeClass = 'progress-incomplete';
                if (preenchidas === totalSectorFuncs) progressBadgeClass = 'progress-complete';
                
                accordion.innerHTML = `
                    <div class="sector-accordion-header" onclick="App.toggleSectorAccordion('${sectorId}')">
                        <div style="display:flex; align-items:center; gap:12px;">
                            <div class="sector-icon-circle" style="background:${sector.cor}1a; color:${sector.cor};">
                                <i class="${this.getSectorIcon(sectorId)}"></i>
                            </div>
                            <div>
                                <h4 style="margin:0; font-size:1rem; font-weight:700; color:var(--navy-dark);">${sector.nome}</h4>
                                <span style="font-size:0.75rem; color:var(--slate-gray); font-weight:500;">${totalSectorFuncs} funções</span>
                            </div>
                        </div>
                        <div style="display:flex; align-items:center; gap:15px;">
                            <span class="sector-progress-badge ${progressBadgeClass}">${preenchidas}/${totalSectorFuncs}</span>
                            <i class="fa-solid fa-chevron-down sector-accordion-chevron ${isOpen ? 'open' : ''}"></i>
                        </div>
                    </div>
                    <div class="sector-accordion-body" style="display: ${isOpen ? 'block' : 'none'};">
                        <div class="table-container" style="box-shadow:none; border-radius:0; border-top: 1px solid #E2E8F0; padding:0;">
                            <table class="admin-table accordion-table">
                                <thead>
                                    <tr>
                                        <th>Função</th>
                                        <th>Membro Escalado</th>
                                        <th>Presença</th>
                                        <th>Observações</th>
                                        <th>Ações</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <!-- dynamic functions rows -->
                                </tbody>
                            </table>
                        </div>
                    </div>
                `;
                
                const tbody = accordion.querySelector('tbody');
                
                funcoes.forEach(func => {
                    const escalasFunc = sectorEscalas.filter(e => e.funcao.toLowerCase().trim() === func.toLowerCase().trim());
                    
                    const isOutsideCulto = (
                        (cultoTipo === 'especial' && (sectorId === 'manutencao' || func === 'Integração')) ||
                        (cultoTipo !== 'especial' && (sectorId === 'limpeza' || sectorId === 'manutencao' || func === 'Integração'))
                    );
                    
                    if (escalasFunc.length > 0) {
                        escalasFunc.forEach((escalaFunc, idx) => {
                            const tr = document.createElement('tr');
                            
                            let pBadge = this.getPresenceBadgeHtml(escalaFunc.statusPresenca);
                            
                            let timeDetails = '';
                            if (isOutsideCulto) {
                                const dateParts = escalaFunc.data.split('-');
                                const d = new Date(dateParts[0], dateParts[1] - 1, dateParts[2]);
                                const diaFormatado = d.toLocaleDateString('pt-BR', { weekday: 'short', day: '2-digit', month: '2-digit' });
                                timeDetails = `<div style="font-size:0.75rem; color:var(--slate-gray); font-weight:normal; margin-top:2px;">
                                    <i class="fa-regular fa-calendar" style="margin-right:2px;"></i> ${diaFormatado} &nbsp;
                                    <i class="fa-regular fa-clock" style="margin-right:2px;"></i> ${escalaFunc.horarioInicio}-${escalaFunc.horarioFim}
                                </div>`;
                            }
                            
                            let funcColHtml = `<div>${func}</div>`;
                            if (idx === 0) {
                                funcColHtml += `
                                    ${timeDetails}
                                    <span onclick="App.openEscalaFormModalParaFuncao('${sectorId}', '${func}')" style="cursor:pointer; font-size:0.72rem; color:var(--teal-primary); font-weight:600; display:inline-flex; align-items:center; gap:3px; margin-top:5px; background:var(--teal-primary)10; padding:2px 6px; border-radius:4px; transition:all 0.2s;" class="hover-btn-scale-more">
                                        <i class="fa-solid fa-plus" style="font-size:0.65rem;"></i> Escalar outro
                                    </span>
                                `;
                            } else {
                                funcColHtml = `
                                    <div style="color:var(--slate-gray); font-weight:500;">${func} (Auxiliar)</div>
                                    ${timeDetails}
                                `;
                            }
                            
                            let obsContent = escalaFunc.observacoes || '-';
                            if (escalaFunc.observacoes && escalaFunc.observacoes.includes('🚨 Sem substituto')) {
                                obsContent = `
                                    <div style="display:flex; align-items:center; gap:6px;">
                                        <span style="max-width:160px; text-overflow:ellipsis; overflow:hidden; white-space:nowrap; font-size:0.8rem; font-weight:500;" title="${escalaFunc.observacoes}">${escalaFunc.observacoes}</span>
                                        <button onclick="App.clearEscalaObservacoes('${escalaFunc.id}')" title="Excluir mensagem de aviso" style="background:none; border:none; color:#EF4444; padding:2px; font-size:0.95rem; cursor:pointer; display:inline-flex; align-items:center; justify-content:center; transition:opacity 0.2s;" class="hover-opacity-btn">
                                            <i class="fa-solid fa-circle-xmark"></i>
                                        </button>
                                    </div>
                                `;
                            } else {
                                obsContent = `<div style="max-width:180px; font-size:0.8rem; text-overflow:ellipsis; overflow:hidden; white-space:nowrap;" title="${escalaFunc.observacoes || ''}">${escalaFunc.observacoes || '-'}</div>`;
                            }

                            tr.innerHTML = `
                                <td style="font-weight:600; vertical-align:middle;">${funcColHtml}</td>
                                <td style="vertical-align:middle;"><b>${escalaFunc.membroNome}</b></td>
                                <td style="vertical-align:middle;">${pBadge}</td>
                                <td style="vertical-align:middle;">${obsContent}</td>
                                <td style="vertical-align:middle;">
                                    <div class="action-buttons">
                                        <button class="btn-table-action" onclick="App.handleEditEscala('${escalaFunc.id}')" title="Editar"><i class="fa-solid fa-pen"></i></button>
                                        <button class="btn-table-action delete" onclick="App.handleDeleteEscala('${escalaFunc.id}')" title="Excluir"><i class="fa-solid fa-trash"></i></button>
                                    </div>
                                </td>
                            `;
                            tbody.appendChild(tr);
                        });
                    } else {
                        const tr = document.createElement('tr');
                        tr.className = 'row-available';
                        tr.innerHTML = `
                            <td style="font-weight:600; color:var(--slate-gray); vertical-align:middle;">${func}</td>
                            <td style="vertical-align:middle;"><span style="color:var(--mono-gray); font-style:italic;"><i class="fa-solid fa-circle-plus"></i> Disponível</span></td>
                            <td style="vertical-align:middle;">-</td>
                            <td style="vertical-align:middle;">-</td>
                            <td style="vertical-align:middle;">
                                <button class="btn-table-action add" onclick="App.openEscalaFormModalParaFuncao('${sectorId}', '${func}')" title="Escalar Voluntário" style="color:var(--teal-primary); font-weight:600; font-size:0.85rem; display:flex; align-items:center; gap:5px; background:none; border:none; cursor:pointer;">
                                    <i class="fa-solid fa-plus"></i> Escalar
                                </button>
                            </td>
                        `;
                        tbody.appendChild(tr);
                    }
                });
                
                // Render unmatched/legacy scales for this sector (if any)
                const funcoesLCase = funcoes.map(f => f.toLowerCase().trim());
                const unmatchedEscalas = sectorEscalas.filter(e => !funcoesLCase.includes(e.funcao.toLowerCase().trim()));
                
                unmatchedEscalas.forEach(escalaFunc => {
                    const tr = document.createElement('tr');
                    tr.style.background = '#FFFBEB'; // light amber highlight
                    
                    let pBadge = this.getPresenceBadgeHtml(escalaFunc.statusPresenca);
                    
                    tr.innerHTML = `
                        <td style="font-weight:600; vertical-align:middle;">
                            <div>${escalaFunc.funcao}</div>
                            <span style="font-size:0.65rem; color:#B45309; background:#FEF3C7; padding:2px 4px; border-radius:3px; font-weight:700;">Legada / Não Cadastrada</span>
                        </td>
                        <td style="vertical-align:middle;"><b>${escalaFunc.membroNome}</b></td>
                        <td style="vertical-align:middle;">${pBadge}</td>
                        <td style="vertical-align:middle;"><div style="max-width:180px; font-size:0.8rem; text-overflow:ellipsis; overflow:hidden; white-space:nowrap;" title="${escalaFunc.observacoes || ''}">${escalaFunc.observacoes || '-'}</div></td>
                        <td style="vertical-align:middle;">
                            <div class="action-buttons">
                                <button class="btn-table-action" onclick="App.handleEditEscala('${escalaFunc.id}')" title="Editar"><i class="fa-solid fa-pen"></i></button>
                                <button class="btn-table-action delete" onclick="App.handleDeleteEscala('${escalaFunc.id}')" title="Excluir"><i class="fa-solid fa-trash"></i></button>
                            </div>
                        </td>
                    `;
                    tbody.appendChild(tr);
                });
                
                container.appendChild(accordion);
            }
            
            const elTotalFunc = document.getElementById('summary-total-functions');
            const elTotalSched = document.getElementById('summary-total-scheduled');
            const elTotalPend = document.getElementById('summary-total-pending');
            const elTotalConf = document.getElementById('summary-total-confirmed');
            
            if (elTotalFunc) elTotalFunc.innerText = totalFunctions;
            if (elTotalSched) elTotalSched.innerText = totalScheduled;
            if (elTotalPend) elTotalPend.innerText = totalPending;
            if (elTotalConf) elTotalConf.innerText = totalConfirmed;
            
            const publishBtn = document.querySelector('.publish-scale-btn');
            if (publishBtn) {
                if (c && (c.status === 'Confirmado' || c.status === 'Finalizado')) {
                    publishBtn.innerText = 'Escala Publicada';
                    publishBtn.disabled = true;
                    publishBtn.style.opacity = '0.6';
                    publishBtn.style.cursor = 'not-allowed';
                } else {
                    publishBtn.innerText = 'Publicar Escala';
                    publishBtn.disabled = false;
                    publishBtn.style.opacity = '1';
                    publishBtn.style.cursor = 'pointer';
                }
            }
        } catch (e) {
            console.error("Erro ao carregar escalas do culto:", e);
            container.innerHTML = '<div style="color:red; text-align:center; padding: 20px;">Erro ao carregar as escalas do culto.</div>';
        }
    },
    
    toggleSectorAccordion(sectorId) {
        this.openAccordions[sectorId] = !this.openAccordions[sectorId];
        this.loadAndRenderAdminEscalas();
    },
    
    getSectorIcon(sectorId) {
        return this.sectorsData[sectorId]?.icon || 'fa-solid fa-calendar';
    },

    async renderEscalasOperacionais() {
        const container = document.getElementById('admin-escalas-operacionais-container');
        if (!container) return;

        container.innerHTML = '<div style="text-align:center; padding:40px;"><i class="fa-solid fa-spinner fa-spin fa-2x" style="color:var(--teal-primary);"></i><p style="margin-top:10px; font-size:0.9rem;">Buscando escalas operacionais...</p></div>';

        try {
            const todasEscalas = await DbService.getEscalas();
            const opSetores = Object.keys(this.sectorsData).filter(id => this.isOperationalSector(id));
            const escalasOp = todasEscalas.filter(e => opSetores.includes(e.setorId) && !e.cultoId);

            container.innerHTML = '';

            // Cabeçalho informativo
            const header = document.createElement('div');
            header.style.cssText = 'background: linear-gradient(135deg, #14b8a6, #0f172a); border-radius: 12px; padding: 16px 20px; color: white; margin-bottom: 20px; display: flex; align-items: center; gap: 12px;';
            header.innerHTML = '<i class="fa-solid fa-broom" style="font-size:1.4rem; opacity:0.9;"></i><div><div style="font-weight:700; font-size:1rem;">Escalas Operacionais Independentes</div><div style="font-size:0.8rem; opacity:0.85; margin-top:2px;">Limpeza e Manutenção — sem vínculo de culto</div></div>';
            container.appendChild(header);

            // Botão nova escala operacional
            const btnNew = document.createElement('div');
            btnNew.style.cssText = 'margin-bottom: 20px; text-align: right;';
            btnNew.innerHTML = '<button onclick="App.openEscalaFormModalOperacional()" style="background: var(--teal-primary); color: white; border: none; border-radius: 8px; padding: 10px 18px; font-size: 0.9rem; font-weight: 600; cursor: pointer; display: inline-flex; align-items: center; gap: 8px;"><i class="fa-solid fa-plus"></i> Nova Escala Operacional</button>';
            container.appendChild(btnNew);

            if (escalasOp.length === 0) {
                const empty = document.createElement('div');
                empty.style.cssText = 'text-align:center; padding:40px 20px; color:var(--slate-gray); font-size:0.9rem;';
                empty.innerHTML = '<i class="fa-solid fa-calendar-xmark" style="font-size:2rem; opacity:0.4; display:block; margin-bottom:12px;"></i>Nenhuma escala operacional cadastrada.';
                container.appendChild(empty);
                return;
            }

            // Agrupar por setor
            opSetores.forEach(sectorId => {
                const sector = this.sectorsData[sectorId];
                const escalasSetor = escalasOp.filter(e => e.setorId === sectorId);
                if (escalasSetor.length === 0) return;

                const section = document.createElement('div');
                section.style.cssText = 'margin-bottom: 20px; border: 1px solid #E2E8F0; border-radius: 12px; overflow: hidden;';
                section.style.borderLeft = `4px solid ${sector.cor}`;

                const secHeader = document.createElement('div');
                secHeader.style.cssText = `background: ${sector.cor}15; padding: 12px 16px; display: flex; align-items: center; gap: 10px; border-bottom: 1px solid #E2E8F0;`;
                secHeader.innerHTML = `<i class="${sector.icon}" style="color:${sector.cor}; font-size:1.1rem;"></i><span style="font-weight:700; font-size:0.95rem; color:var(--navy-dark);">${sector.nome}</span><span style="font-size:0.8rem; color:var(--slate-gray); margin-left:auto;">${escalasSetor.length} escala(s)</span>`;
                section.appendChild(secHeader);

                const tableWrap = document.createElement('div');
                tableWrap.style.cssText = 'overflow-x: auto;';
                const table = document.createElement('table');
                table.className = 'admin-table accordion-table';
                table.style.cssText = 'box-shadow:none; border-radius:0;';
                table.innerHTML = '<thead><tr><th>Data / Turno</th><th>Status da Escala</th><th>Voluntários</th><th>Ações</th></tr></thead>';
                const tbody = document.createElement('tbody');

                // Agrupar por data, horários e função
                const turnos = {};
                escalasSetor.forEach(e => {
                    const key = `${e.data}_${e.horarioInicio || ''}_${e.horarioFim || ''}_${e.funcao || ''}`;
                    if (!turnos[key]) {
                        turnos[key] = {
                            data: e.data,
                            horarioInicio: e.horarioInicio,
                            horarioFim: e.horarioFim,
                            funcao: e.funcao,
                            membros: []
                        };
                    }
                    turnos[key].membros.push({
                        id: e.id,
                        nome: e.membroNome,
                        statusPresenca: e.statusPresenca,
                        statusServico: e.statusServico
                    });
                });

                // Separar em memória: ativos e concluídos
                const todosOsTurnos    = Object.values(turnos);
                const turnosAtivos     = todosOsTurnos.filter(t => !(t.membros.length > 0 && t.membros.every(m => m.statusServico === 'Finalizado')));
                const turnosConcluidos = todosOsTurnos.filter(t =>   t.membros.length > 0 && t.membros.every(m => m.statusServico === 'Finalizado'));

                // Função auxiliar para construir uma linha de turno
                const buildTurnoRow = (t) => {
                    const dateParts = (t.data || '').split('-');
                    const dObj = dateParts.length === 3 ? new Date(dateParts[0], dateParts[1]-1, dateParts[2]) : null;
                    const dFormatado = dObj ? dObj.toLocaleDateString('pt-BR', { weekday: 'short', day: '2-digit', month: '2-digit' }) : (t.data || '-');

                    let confirmadosCount = 0;
                    let pendentesCount = 0;
                    let listaMembrosHtml = '';
                    let actionsHtml = '';

                    const isTurnoConcluido = t.membros.length > 0 && t.membros.every(m => m.statusServico === 'Finalizado');
                    const todosResponderam = t.membros.length > 0 && t.membros.every(m => m.statusPresenca && m.statusPresenca !== 'Pendente');
                    const turnoIds = JSON.stringify(t.membros.map(m => m.id));

                    t.membros.forEach(m => {
                        const isConf = m.statusPresenca === 'Confirmada';
                        if (isConf) confirmadosCount++; else pendentesCount++;
                        const iconHtml = isConf ? '<i class="fa-solid fa-check" style="color:var(--emerald-success);"></i>' : '<i class="fa-regular fa-clock" style="color:var(--amber-warning);"></i>';
                        const statusText = isConf ? 'Confirmado' : 'Pendente';
                        listaMembrosHtml += `<div style="margin-bottom: 6px; font-size: 0.9rem;"><b>${m.nome || '-'}</b> &nbsp; ${iconHtml} <span style="font-size:0.8rem; color:var(--slate-gray);">${statusText}</span></div>`;
                        actionsHtml += `<div style="margin-bottom: 6px; display: flex; gap: 4px;"><button class="btn-table-action" onclick="App.handleEditEscala('${m.id}')" title="Editar" style="padding: 4px 8px;"><i class="fa-solid fa-pen"></i></button><button class="btn-table-action delete" onclick="App.handleDeleteEscala('${m.id}')" title="Excluir" style="padding: 4px 8px;"><i class="fa-solid fa-trash"></i></button></div>`;
                    });

                    const totalMembros = t.membros.length;
                    const isFullyPending = pendentesCount === totalMembros && totalMembros > 0;

                    let statusColor, statusTextGeral;
                    if (isTurnoConcluido) {
                        statusColor = '#64748B'; statusTextGeral = 'Concluído';
                    } else if (todosResponderam) {
                        statusColor = 'var(--teal-primary)'; statusTextGeral = 'Todos responderam';
                    } else if (isFullyPending) {
                        statusColor = 'var(--amber-warning)'; statusTextGeral = 'Pendente';
                    } else {
                        statusColor = 'var(--blue-light)'; statusTextGeral = 'Parcial';
                    }

                    const btnEncerrar = isTurnoConcluido ? '' : `<div style="margin-top: 8px;"><button onclick="App.handleEncerrarTurnoOperacional('${turnoIds.replace(/'/g, "\\'")}')" style="background:#0f172a; color:white; border:none; border-radius:6px; padding:6px 12px; font-size:0.8rem; font-weight:600; cursor:pointer; display:inline-flex; align-items:center; gap:6px;"><i class="fa-solid fa-flag-checkered"></i> Encerrar Turno</button></div>`;

                    const tr = document.createElement('tr');
                    tr.style.cssText = isTurnoConcluido ? 'opacity:0.65;' : '';
                    tr.innerHTML = `
                        <td style="vertical-align:top; border-bottom: 1px solid #eee;">
                            <div style="font-weight:700; font-size:1rem; color:var(--navy-dark);">${dFormatado}</div>
                            <div style="font-size:0.85rem; color:var(--slate-gray); margin-top:4px;"><i class="fa-regular fa-clock"></i> ${t.horarioInicio || '-'} – ${t.horarioFim || '-'}</div>
                            <div style="font-size:0.85rem; color:var(--slate-gray); margin-top:2px;">${t.funcao || ''}</div>
                        </td>
                        <td style="vertical-align:top; border-bottom: 1px solid #eee;">
                            <div style="margin-bottom: 8px;"><span class="badge" style="background:${statusColor}; color:white;">${statusTextGeral}</span></div>
                            <div style="font-weight: 600; font-size:0.9rem;">${totalMembros} membro(s)</div>
                            <div style="font-size: 0.85rem; color: var(--emerald-success); margin-top:2px;">${confirmadosCount} confirmado(s)</div>
                            <div style="font-size: 0.85rem; color: var(--amber-warning); margin-top:2px;">${pendentesCount} pendente(s)</div>
                            ${btnEncerrar}
                        </td>
                        <td style="vertical-align:top; border-bottom: 1px solid #eee;">${listaMembrosHtml}</td>
                        <td style="vertical-align:top; border-bottom: 1px solid #eee;">${actionsHtml}</td>
                    `;
                    return tr;
                };

                // Renderizar escalas ativas
                turnosAtivos.forEach(t => tbody.appendChild(buildTurnoRow(t)));

                table.appendChild(tbody);
                tableWrap.appendChild(table);
                section.appendChild(tableWrap);

                // Renderizar seção Histórico (turnos concluídos) abaixo da tabela ativa
                if (turnosConcluidos.length > 0) {
                    const histHeader = document.createElement('div');
                    histHeader.style.cssText = 'padding: 10px 16px; background: #F8FAFC; border-top: 1px solid #E2E8F0; display: flex; align-items: center; gap: 8px; cursor: pointer; user-select: none;';
                    histHeader.id = `hist-header-${sectorId}`;
                    histHeader.innerHTML = `<i class="fa-solid fa-clock-rotate-left" style="color:#64748B; font-size:0.9rem;"></i><span style="font-weight:600; font-size:0.85rem; color:#64748B;">Histórico (${turnosConcluidos.length} turno(s) concluído(s))</span><i class="fa-solid fa-chevron-down" style="margin-left:auto; color:#94A3B8; font-size:0.8rem;" id="hist-icon-${sectorId}"></i>`;

                    const histBody = document.createElement('div');
                    histBody.id = `hist-body-${sectorId}`;
                    histBody.style.display = 'none';

                    const histTableWrap = document.createElement('div');
                    histTableWrap.style.cssText = 'overflow-x: auto; background: #F8FAFC;';
                    const histTable = document.createElement('table');
                    histTable.className = 'admin-table accordion-table';
                    histTable.style.cssText = 'box-shadow:none; border-radius:0; opacity:0.8;';
                    histTable.innerHTML = '<thead><tr><th>Data / Turno</th><th>Status</th><th>Voluntários</th><th>Ações</th></tr></thead>';
                    const histTbody = document.createElement('tbody');
                    turnosConcluidos.forEach(t => histTbody.appendChild(buildTurnoRow(t)));
                    histTable.appendChild(histTbody);
                    histTableWrap.appendChild(histTable);
                    histBody.appendChild(histTableWrap);

                    histHeader.addEventListener('click', () => {
                        const isOpen = histBody.style.display !== 'none';
                        histBody.style.display = isOpen ? 'none' : 'block';
                        const icon = document.getElementById(`hist-icon-${sectorId}`);
                        if (icon) icon.style.transform = isOpen ? '' : 'rotate(180deg)';
                    });

                    section.appendChild(histHeader);
                    section.appendChild(histBody);
                }

                container.appendChild(section);
            });
        } catch (e) {
            console.error('Erro ao carregar escalas operacionais:', e);
            container.innerHTML = '<div style="color:red; text-align:center; padding:20px;">Erro ao carregar escalas operacionais.</div>';
        }
    },

    async handleEncerrarTurnoOperacional(idsJson) {
        const ids = JSON.parse(idsJson);
        for (const id of ids) {
            await DbService.saveEscala(id, { statusServico: 'Finalizado' });
        }
        
        if (ids.length > 0) {
            // Dispara automação de mural caso seja limpeza (a validação de setor ocorre dentro da função)
            await this.triggerMuralLimpeza(ids[0]);
        }
        
        this.renderEscalasOperacionais();
    },

    async triggerMuralLimpeza(escalaId) {
        try {
            // Verifica se já postou hoje para evitar spam se múltiplas pessoas encerrarem o turno
            const avisos = await DbService.getAvisos();
            const todayStr = new Date().toISOString().split('T')[0];
            const alreadyPosted = avisos.some(a => 
                a.titulo === "🧹 Limpeza Finalizada" && 
                a.dataCriacao && 
                a.dataCriacao.startsWith(todayStr)
            );
            if (alreadyPosted) return;

            const todasEscalas = await DbService.getEscalas();
            const currentEscala = todasEscalas.find(e => e.id === escalaId);
            if (!currentEscala || !this.isOperationalSector(currentEscala.setorId)) return;

            // Busca cultos dos próximos 7 dias
            const cultos = await DbService.getCultos();
            const todayDate = new Date();
            todayDate.setHours(0,0,0,0);
            const nextWeekDate = new Date(todayDate);
            nextWeekDate.setDate(nextWeekDate.getDate() + 7);
            
            const cultosIds = cultos.filter(c => {
                if (!c.data) return false;
                const [y, m, d] = c.data.split('-');
                const cDate = new Date(y, m - 1, d);
                return cDate >= todayDate && cDate <= nextWeekDate;
            }).map(c => c.id);

            const obreiros = todasEscalas.filter(e => e.cultoId && cultosIds.includes(e.cultoId));
            
            // Remove nomes duplicados
            const nomesUnicos = [...new Set(obreiros.map(e => e.membroNome).filter(Boolean))];
            
            let nomesStr = "";
            if (nomesUnicos.length > 0) {
                nomesStr = `\n\nObreiros escalados na semana:\n• ${nomesUnicos.join('\n• ')}`;
            }

            const expDate = new Date();
            expDate.setDate(expDate.getDate() + 3);
            const dataExpiracao = expDate.toISOString().split('T')[0];

            await DbService.saveAviso({
                titulo: "🧹 Limpeza Finalizada",
                conteudo: `Igreja limpa, pedimos aos obreiros que ajudem a manter limpo e organizado. Informem à direção se algo faltar.${nomesStr}`,
                tipo: "info",
                dataCriacao: new Date().toISOString(),
                dataExpiracao: dataExpiracao
            });
        } catch(e) {
            console.error('Erro ao postar automação de limpeza no mural', e);
        }
    },

    async openEscalaFormModalOperacional() {
        document.getElementById('escala-modal-title').innerText = "Nova Escala Operacional";
        document.getElementById('escala-form-id').value = '';
        document.getElementById('escala-form').reset();
        document.getElementById('escala-cultoid').value = '';

        const dataInput = document.getElementById('escala-data');
        const horaInInput = document.getElementById('escala-horainicio');
        const horaFimInput = document.getElementById('escala-horafim');
        dataInput.value = this.formatLocalISOString(new Date()).split('T')[0];
        dataInput.disabled = false;
        horaInInput.value = '08:00';
        horaInInput.disabled = false;
        horaFimInput.value = '17:00';
        horaFimInput.disabled = false;

        this.populateEscalaSetorSelect('operacional');
        const setorSel = document.getElementById('escala-setor');
        setorSel.value = 'limpeza';
        await this.handleEscalaSetorChange('limpeza');

        document.getElementById('modal-escala-form').classList.add('active');
    },

    populateEscalaSetorSelect(filterType = 'all') {
        const setorSel = document.getElementById('escala-setor');
        if (!setorSel) return;
        setorSel.innerHTML = '<option value="" disabled selected>Escolha o setor</option>';
        Object.entries(this.sectorsData).forEach(([id, cfg]) => {
            let include = false;
            if (filterType === 'all') {
                include = true;
            } else if (filterType === 'operacional') {
                include = this.isOperationalSector(id);
            } else if (filterType === 'culto') {
                include = cfg.participaCulto === true;
            }
            if (include) {
                setorSel.innerHTML += `<option value="${id}">${cfg.nome}</option>`;
            }
        });
    },

    openEscalaFormModalParaFuncao(sectorId, funcao) {
        const c = this.cultosData.find(item => item.id === this.adminSelectedCultoId);
        if (!c) return;
        
        document.getElementById('escala-modal-title').innerText = `Escalar para ${funcao}`;
        document.getElementById('escala-form-id').value = '';
        document.getElementById('escala-form').reset();
        
        document.getElementById('escala-cultoid').value = this.adminSelectedCultoId;
        
        const dataInput = document.getElementById('escala-data');
        dataInput.value = c.data;
        
        const horaInInput = document.getElementById('escala-horainicio');
        horaInInput.value = c.horarioInicio;
        
        const horaFimInput = document.getElementById('escala-horafim');
        horaFimInput.value = c.horarioFim;
        
        this.populateEscalaSetorSelect('culto');
        document.getElementById('escala-setor').value = sectorId;
        this.handleEscalaSetorChange(sectorId).then(() => {
            document.getElementById('escala-funcao').value = funcao;
            this.adjustEscalaFormFields();
        });
        
        document.getElementById('modal-escala-form').classList.add('active');
    },

    // --- ESCALA FORM MODAL ---
    async openEscalaFormModal() {
        document.getElementById('escala-modal-title').innerText = "Montar Nova Escala";
        document.getElementById('escala-form-id').value = '';
        document.getElementById('escala-form').reset();
        
        const c = this.cultosData.find(item => item.id === this.adminSelectedCultoId);
        
        const dataInput = document.getElementById('escala-data');
        const horaInInput = document.getElementById('escala-horainicio');
        const horaFimInput = document.getElementById('escala-horafim');
        
        if (c) {
            document.getElementById('escala-cultoid').value = c.id;
            dataInput.value = c.data;
            horaInInput.value = c.horarioInicio;
            horaFimInput.value = c.horarioFim;
        } else {
            document.getElementById('escala-cultoid').value = '';
            dataInput.value = this.formatLocalISOString(new Date()).split('T')[0];
            horaInInput.value = '08:00';
            horaFimInput.value = '12:00';
        }
        
        this.populateEscalaSetorSelect('culto');
        document.getElementById('escala-setor').value = 'entrada';
        await this.handleEscalaSetorChange('entrada');
        
        document.getElementById('modal-escala-form').classList.add('active');
    },

    closeEscalaFormModal() {
        document.getElementById('escala-data').disabled = false;
        document.getElementById('escala-horainicio').disabled = false;
        document.getElementById('escala-horafim').disabled = false;
        
        document.getElementById('modal-escala-form').classList.remove('active');
    },

    async handleEscalaSetorChange(sectorId, currentMemberId = '') {
        const fSelect = document.getElementById('escala-funcao');
        fSelect.innerHTML = '<option value="" disabled selected>Escolha a função</option>';
        
        const mSelect = document.getElementById('escala-membro');
        if (mSelect) {
            mSelect.innerHTML = '<option value="" disabled selected>Escolha o voluntário</option>';
        }

        const sector = this.sectorsData[sectorId];
        if (!sector) return;

        const funcoes = this.getSectorFunctions(sectorId);
        funcoes.forEach(func => {
            fSelect.innerHTML += `<option value="${func}">${func}</option>`;
        });

        try {
            const membros = await DbService.getMembros();
            const dateVal = document.getElementById('escala-data').value;
            const timeVal = document.getElementById('escala-horainicio').value;
            const currentEscalaId = document.getElementById('escala-form-id').value || '';

            // Buscar escalas no dia para verificar conflito de horários
            let escalasNoDia = [];
            if (dateVal) {
                try {
                    escalasNoDia = await DbService.getEscalas(null, dateVal, dateVal);
                } catch (err) {
                    console.warn("Erro ao buscar escalas do dia para conflitos:", err);
                }
            }

            const sectorMembers = membros.filter(m => {
                if (m.status !== 'ativo') return false;
                if (m.perfil === 'admin') return false; // Supervisor/Admin não pode entrar em nenhuma escala
                if (m.id === currentMemberId) return true;

                if (sectorId === 'escala_livre') return true;
                if (Array.isArray(m.setores)) {
                    return m.setores.includes(sectorId);
                }
                return m.setor === sectorId;
            });

            // Store sectorMembers globally on App to support instant search filtering
            this._escalaSectorMembersCache = sectorMembers.map(m => {
                const isAfastado = (m.afastamentoInicio && m.afastamentoFim && dateVal >= m.afastamentoInicio && dateVal <= m.afastamentoFim) || 
                                  (m.statusOperacional && m.statusOperacional !== 'Disponível');
                let group = 'disponiveis';
                let labelSuffix = '';
                if (isAfastado) {
                    group = 'afastados';
                    labelSuffix = ` (${m.afastamentoMotivo || 'Afastado'})`;
                } else {
                    const hasConflict = dateVal && timeVal && escalasNoDia.some(e => e.membroId === m.id && e.horarioInicio === timeVal && e.id !== currentEscalaId);
                    const isDisponivelGeral = App.isMembroDisponivel(m, dateVal, timeVal);
                    if (hasConflict || !isDisponivelGeral) {
                        group = 'indisponiveis';
                        let motivo = 'Restrição';
                        if (hasConflict) {
                            motivo = 'Já escalado neste horário';
                        } else if (dateVal && m.indisponibilidades_mensais && m.indisponibilidades_mensais[dateVal] === 'nao_posso') {
                            motivo = 'Indisponibilidade declarada';
                        } else if (m.disponibilidade && m.disponibilidade !== 'Todos') {
                            motivo = `Restrição de turno: ${m.disponibilidade}`;
                        }
                        labelSuffix = ` (${motivo})`;
                    } else if (typeof m.scoreConfiabilidade === 'number') {
                        labelSuffix = ` (${m.scoreConfiabilidade}%)`;
                    }
                }
                return {
                    id: m.id,
                    nome: m.nome,
                    group,
                    label: `${m.nome}${labelSuffix}`,
                    score: typeof m.scoreConfiabilidade === 'number' ? m.scoreConfiabilidade : -1
                };
            });

            // Render current checkboxes list
            this.renderEscalaMembrosCheckboxesList(currentMemberId);

            // Exibição condicional da repetição da escala
            const repGroup = document.getElementById('escala-repeticao-group');
            if (repGroup) {
                const isNew = !document.getElementById('escala-form-id').value;
                if (isNew && this.isOperationalSector(sectorId)) {
                    repGroup.style.display = 'block';
                } else {
                    repGroup.style.display = 'none';
                }
            }

            this.adjustEscalaFormFields();
        } catch (e) {
            console.error("Error fetching members for scale select:", e);
        }
    },

    renderEscalaMembrosCheckboxesList(checkedId = '', query = '') {
        const container = document.getElementById('escala-membros-checkboxes-container');
        if (!container) return;

        const members = this._escalaSectorMembersCache || [];
        const normQuery = query.toLowerCase().trim();

        const filtered = members.filter(m => !normQuery || m.nome.toLowerCase().includes(normQuery));

        if (filtered.length === 0) {
            container.innerHTML = '<div style="font-size:0.8rem; color:#64748B; text-align:center; padding: 10px;">Nenhum membro encontrado</div>';
            return;
        }

        const groups = { disponiveis: [], indisponiveis: [], afastados: [] };
        filtered.forEach(m => groups[m.group].push(m));

        // Sort disponiveis by reliability score desc
        groups.disponiveis.sort((a, b) => b.score - a.score);

        let html = '';

        const renderGroup = (label, list, color) => {
            if (list.length === 0) return;
            html += `<div style="font-size:0.75rem; font-weight:700; color:${color}; margin-top:8px; border-bottom:1px solid #F1F5F9; padding-bottom:3px; text-transform:uppercase;">${label}</div>`;
            list.forEach(m => {
                const isChecked = m.id === checkedId ? 'checked' : '';
                html += `
                    <label style="display:flex; align-items:center; gap:8px; font-size:0.85rem; color:#1E293B; cursor:pointer; padding:3px 0;">
                        <input type="checkbox" value="${m.id}" data-nome="${m.nome}" ${isChecked} onchange="App.updateEscalaMembrosSelecionadosContador()" style="width:16px; height:16px; margin:0; cursor:pointer; accent-color:var(--teal-primary);">
                        <span>${m.label}</span>
                    </label>
                `;
            });
        };

        renderGroup('Disponíveis', groups.disponiveis, '#10B981');
        renderGroup('Indisponíveis / Restrição', groups.indisponiveis, '#F59E0B');
        renderGroup('Afastados / Licença', groups.afastados, '#EF4444');

        container.innerHTML = html;
        this.updateEscalaMembrosSelecionadosContador();
    },

    updateEscalaMembrosSelecionadosContador() {
        const count = document.querySelectorAll('#escala-membros-checkboxes-container input[type="checkbox"]:checked').length;
        const indicator = document.getElementById('escala-membros-selecionados-contador');
        if (indicator) {
            indicator.innerText = `${count} ${count === 1 ? 'selecionado' : 'selecionados'}`;
        }
    },

    filterEscalaMembrosList(query) {
        // Keep checked state for checked boxes during filter redraw
        const checkedList = Array.from(document.querySelectorAll('#escala-membros-checkboxes-container input[type="checkbox"]:checked')).map(cb => cb.value);
        this.renderEscalaMembrosCheckboxesList(checkedList[0] || '', query);
        
        // Ensure previously checked items remain checked
        checkedList.forEach(id => {
            const cb = document.querySelector(`#escala-membros-checkboxes-container input[value="${id}"]`);
            if (cb) cb.checked = true;
        });
        
        this.updateEscalaMembrosSelecionadosContador();
    },

    async handleEditEscala(id) {
        try {
            const scales = await DbService.getEscalas();
            const e = scales.find(item => item.id === id);
            if (!e) return;

            document.getElementById('escala-modal-title').innerText = "Editar Escala";
            document.getElementById('escala-form-id').value = e.id;
            document.getElementById('escala-cultoid').value = e.cultoId || '';
            
            this.populateEscalaSetorSelect('all');
            document.getElementById('escala-setor').value = e.setorId;
            await this.handleEscalaSetorChange(e.setorId, e.membroId);
            
            document.getElementById('escala-funcao').value = e.funcao;
            
            // Mark correct checkbox as checked
            const checkbox = document.querySelector(`#escala-membros-checkboxes-container input[value="${e.membroId}"]`);
            if (checkbox) checkbox.checked = true;
            
            const dataInput = document.getElementById('escala-data');
            dataInput.value = e.data;
            
            const horaInInput = document.getElementById('escala-horainicio');
            horaInInput.value = e.horarioInicio;
            
            const horaFimInput = document.getElementById('escala-horafim');
            horaFimInput.value = e.horarioFim;
            
            document.getElementById('escala-obs').value = e.observacoes || '';

            this.adjustEscalaFormFields();

            document.getElementById('modal-escala-form').classList.add('active');
        } catch (e) {
            this.showAlert('Erro ao carregar escala para edição.');
        }
    },

    async handleEscalaSave(event) {
        event.preventDefault();
        const id = document.getElementById('escala-form-id').value;
        const cultoId = document.getElementById('escala-cultoid').value;
        const setorId = document.getElementById('escala-setor').value;
        const funcao = document.getElementById('escala-funcao').value;
        
        const checkedBoxes = Array.from(document.querySelectorAll('#escala-membros-checkboxes-container input[type="checkbox"]:checked'));
        
        if (checkedBoxes.length === 0) {
            this.showAlert('Por favor, selecione ao menos um membro.');
            return;
        }

        if (id && checkedBoxes.length > 1) {
            this.showAlert('Ao editar uma escala existente, selecione apenas um membro.');
            return;
        }

        const data = document.getElementById('escala-data').value;
        const horarioInicio = document.getElementById('escala-horainicio').value;
        const horarioFim = document.getElementById('escala-horafim').value;
        const observacoes = document.getElementById('escala-obs').value.trim();
        const repSelect = document.getElementById('escala-repeticao');
        const repValue = repSelect ? repSelect.value : 'unica';

        try {
            const basePayload = {
                origem: 'manual',
                setorId,
                funcao,
                data,
                horarioInicio,
                horarioFim,
                observacoes,
            };
            
            if (cultoId) {
                basePayload.cultoId = cultoId;
                const c = this.cultosData.find(item => item.id === cultoId);
                if (c) {
                    basePayload.cultoNome = c.nome;
                }
            }

            let generatedDates = [];
            const baseDate = new Date(data + 'T12:00:00');
            
            if (!id && this.isOperationalSector(setorId) && repValue !== 'unica') {
                const occurrences = 12;
                for (let i = 0; i < occurrences; i++) {
                    if (repValue === 'mensal') {
                        const targetMonthStart = new Date(baseDate.getFullYear(), baseDate.getMonth() + i, 1, 12, 0, 0);
                        const expectedMonth = targetMonthStart.getMonth();
                        const weekOrdinal = Math.ceil(baseDate.getDate() / 7);
                        const dayOfWeek = baseDate.getDay();
                        
                        const firstDayOffset = (dayOfWeek - targetMonthStart.getDay() + 7) % 7;
                        
                        const occDate = new Date(targetMonthStart);
                        occDate.setDate(1 + firstDayOffset + (weekOrdinal - 1) * 7);
                        
                        if (occDate.getMonth() !== expectedMonth) {
                            occDate.setDate(occDate.getDate() - 7);
                        }
                        generatedDates.push(this.formatLocalISOString(occDate).split('T')[0]);
                    } else if (repValue === 'semanal') {
                        const occDate = new Date(baseDate);
                        occDate.setDate(occDate.getDate() + (i * 7));
                        generatedDates.push(this.formatLocalISOString(occDate).split('T')[0]);
                    }
                }
            } else {
                generatedDates.push(data);
            }

            if (setorId === 'limpeza') {
                const minDate = generatedDates.reduce((min, d) => d < min ? d : min, generatedDates[0]);
                const prevMinDateObj = new Date(minDate + 'T12:00:00');
                prevMinDateObj.setDate(prevMinDateObj.getDate() - 1);
                const queryMinDate = this.formatLocalISOString(prevMinDateObj).split('T')[0];

                const todasEscalasLimpeza = await DbService.getEscalas();
                const limpezaRecente = todasEscalasLimpeza.filter(e =>
                    e.setorId === 'limpeza' && e.data >= queryMinDate
                );

                const existingLimpezaDates = new Set();
                limpezaRecente.forEach(e => {
                    if (id && e.id === id) return;
                    existingLimpezaDates.add(e.data);
                });

                const allIntendedDates = new Set(generatedDates);

                for (let d of generatedDates) {
                    const dObj = new Date(d + 'T12:00:00');
                    const prevObj = new Date(dObj); prevObj.setDate(prevObj.getDate() - 1);
                    const nextObj = new Date(dObj); nextObj.setDate(nextObj.getDate() + 1);
                    
                    const prevStr = this.formatLocalISOString(prevObj).split('T')[0];
                    const nextStr = this.formatLocalISOString(nextObj).split('T')[0];

                    if (existingLimpezaDates.has(prevStr) || existingLimpezaDates.has(nextStr) ||
                        allIntendedDates.has(prevStr) || allIntendedDates.has(nextStr)) {
                        this.showAlert('Conflito na Limpeza: Não é permitido escalas em dias consecutivos. Deve haver pelo menos 1 dia livre entre as limpezas.');
                        return;
                    }
                }
            }
            const promises = [];

            for (const cb of checkedBoxes) {
                const membroId = cb.value;
                const membroNome = cb.dataset.nome;
                
                let scalePayload = {
                    ...basePayload,
                    membroId,
                    membroNome
                };

                if (!id) {
                    scalePayload.statusPresenca = 'Pendente';
                    scalePayload.statusServico = 'Agendado';
                } else {
                    try {
                        const docRef = await db.collection('escalas').doc(id).get();
                        if (docRef.exists) {
                            const existing = docRef.data();
                            if (existing.membroId !== membroId || 
                                existing.data !== data || 
                                existing.horarioInicio !== horarioInicio || 
                                existing.horarioFim !== horarioFim ||
                                existing.statusPresenca === 'Recusada') {
                                scalePayload.statusPresenca = 'Pendente';
                                scalePayload.statusServico = 'Agendado';
                                scalePayload.rejeicaoResolvida = false;
                            }
                        }
                    } catch (err) {
                        console.error("Error checking existing scale:", err);
                    }
                }

                if (!id && this.isOperationalSector(setorId) && repValue !== 'unica') {
                    for (const occDataStr of generatedDates) {
                        const payload = {
                            ...scalePayload,
                            data: occDataStr,
                            statusPresenca: 'Pendente',
                            statusServico: 'Agendado'
                        };
                        promises.push(DbService.saveEscala(null, payload));
                    }
                } else {
                    promises.push(DbService.saveEscala(id ? id : null, scalePayload));
                }
            }

            await Promise.all(promises);

            this.closeEscalaFormModal();
            this.showToast('Escala gravada com sucesso!', 'success');
            
            if (this.pendingStandbyIdToResolve) {
                try {
                    await DbService.deleteStandby(this.pendingStandbyIdToResolve);
                } catch (err) {
                    console.error("Error resolving standby:", err);
                }
                this.pendingStandbyIdToResolve = null;
            }

            this.loadAndRenderAdminEscalas();
        } catch (e) {
            console.error("Error saving scales:", e);
            this.showAlert('Erro ao gravar escala no banco de dados.');
        }
    },

    async handleDeleteEscala(id) {
        if (confirm('Deseja realmente remover esta escala?')) {
            try {
                await DbService.deleteEscala(id);
                this.showToast('Escala removida!', 'success');
                this.loadAndRenderAdminEscalas();
            } catch (e) {
                this.showAlert('Erro ao remover escala.');
            }
        }
    },
    
    async clearEscalaObservacoes(id) {
        try {
            await DbService.saveEscala(id, { observacoes: "" });
            this.showToast('Aviso removido com sucesso!', 'success');
            this.loadAndRenderAdminEscalas();
        } catch (e) {
            console.error("Erro ao limpar observações da escala:", e);
            this.showAlert('Erro ao remover o aviso.');
        }
    },
    
    // --- CULTOS OPERATIONS ---
    toggleVagasEscalaLivre() {
        const val = document.getElementById('culto-modelo-escala').value;
        const group = document.getElementById('grupo-vagas-escala-livre');
        if (group) {
            group.style.display = (val === 'Escala Livre') ? 'block' : 'none';
        }
    },

    openCultoFormModal(cultoId = null) {
        document.getElementById('culto-form').reset();
        document.getElementById('culto-form-id').value = '';
        
        if (cultoId) {
            const c = this.cultosData.find(item => item.id === cultoId);
            if (c) {
                document.getElementById('culto-form-id').value = c.id;
                document.getElementById('culto-nome').value = c.nome;
                document.getElementById('culto-data').value = c.data;
                document.getElementById('culto-horainicio').value = c.horarioInicio;
                document.getElementById('culto-horafim').value = c.horarioFim;
                document.getElementById('culto-tipo').value = c.tipo;
                document.getElementById('culto-status').value = c.status;
                document.getElementById('culto-modelo-escala').value = c.modeloEscala || 'Manter Existente';
                document.getElementById('culto-vagas-escala-livre').value = c.vagasEscalaLivre || 2;
                
                document.getElementById('btn-culto-delete').style.display = 'block';
            }
        } else {
            document.getElementById('culto-data').value = this.formatLocalISOString(new Date()).split('T')[0];
            document.getElementById('culto-modelo-escala').value = 'Manter Existente';
            document.getElementById('culto-vagas-escala-livre').value = 2;
            document.getElementById('btn-culto-delete').style.display = 'none';
        }
        
        this.toggleVagasEscalaLivre();
        this.updateCultoFormLabels();
        document.getElementById('modal-culto-form').classList.add('active');
    },
    
    updateCultoFormLabels() {
        const id = document.getElementById('culto-form-id').value;
        const tipo = document.getElementById('culto-tipo').value;
        const isEspecial = tipo === 'especial';
        
        const titleEl = document.getElementById('culto-modal-title');
        const deleteEl = document.getElementById('btn-culto-delete');
        const submitEl = document.getElementById('btn-culto-save-submit');
        
        if (id) {
            if (titleEl) titleEl.innerText = isEspecial ? "Editar Evento Especial" : "Editar Culto Regular";
            if (deleteEl) deleteEl.innerText = isEspecial ? "Excluir Evento" : "Excluir Culto";
            if (submitEl) submitEl.innerText = isEspecial ? "Salvar Evento" : "Salvar Culto";
        } else {
            if (titleEl) titleEl.innerText = isEspecial ? "Novo Evento Especial" : "Novo Culto Regular";
            if (submitEl) submitEl.innerText = isEspecial ? "Criar Evento" : "Criar Culto";
        }
    },
    
    closeCultoFormModal() {
        document.getElementById('modal-culto-form').classList.remove('active');
    },
    
    async handleCultoSave(event) {
        event.preventDefault();
        const id = document.getElementById('culto-form-id').value;
        const nome = document.getElementById('culto-nome').value.trim();
        const data = document.getElementById('culto-data').value;
        const horarioInicio = document.getElementById('culto-horainicio').value;
        const horarioFim = document.getElementById('culto-horafim').value;
        const tipo = document.getElementById('culto-tipo').value;
        const status = document.getElementById('culto-status').value;
        const modeloEscala = document.getElementById('culto-modelo-escala').value;
        const vagasEscalaLivre = parseInt(document.getElementById('culto-vagas-escala-livre').value, 10) || 2;
        
        try {
            const cultoPayload = {
                nome,
                data,
                horarioInicio,
                horarioFim,
                tipo,
                status,
                modeloEscala,
                vagasEscalaLivre: modeloEscala === 'Escala Livre' ? vagasEscalaLivre : null
            };
            
            const savedId = await DbService.saveCulto(id ? id : null, cultoPayload);
            
            if (!id) {
                this.adminSelectedCultoId = savedId;
            }
            
            this.closeCultoFormModal();
            const term = tipo === 'especial' ? 'Evento' : 'Culto';
            this.showToast(`${term} gravado com sucesso!`, 'success');
            this.loadAdminEscalas();
        } catch (e) {
            const term = tipo === 'especial' ? 'Evento' : 'Culto';
            this.showAlert(`Erro ao gravar ${term.toLowerCase()} no banco de dados.`);
        }
    },
    
    handleEditActiveCulto() {
        if (this.adminSelectedCultoId) {
            this.openCultoFormModal(this.adminSelectedCultoId);
        }
    },
    
    async handleDeleteActiveCulto() {
        if (!this.adminSelectedCultoId) return;
        
        const c = this.cultosData.find(item => item.id === this.adminSelectedCultoId);
        if (!c) return;
        
        const term = c.tipo === 'especial' ? 'evento' : 'culto';
        
        if (confirm(`Deseja realmente excluir este ${term}? ATENÇÃO: Todas as escalas de voluntários associadas a ele também serão excluídas.`)) {
            try {
                await DbService.deleteCulto(this.adminSelectedCultoId);
                this.showToast(`${term === 'evento' ? 'Evento' : 'Culto'} e escalas excluídos com sucesso!`, 'success');
                this.adminSelectedCultoId = null;
                this.loadAdminEscalas();
            } catch (e) {
                this.showAlert(`Erro ao excluir ${term}.`);
            }
        }
    },
    
    async handleDeleteCultoDoModal() {
        const id = document.getElementById('culto-form-id').value;
        if (!id) return;
        
        const c = this.cultosData.find(item => item.id === id);
        if (!c) return;
        
        const term = c.tipo === 'especial' ? 'evento' : 'culto';
        
        if (confirm(`Deseja realmente excluir este ${term}? ATENÇÃO: Todas as escalas de voluntários associadas a ele também serão excluídas.`)) {
            try {
                await DbService.deleteCulto(id);
                this.showToast(`${term === 'evento' ? 'Evento' : 'Culto'} e escalas excluídos com sucesso!`, 'success');
                this.closeCultoFormModal();
                if (this.adminSelectedCultoId === id) {
                    this.adminSelectedCultoId = null;
                }
                this.loadAdminEscalas();
            } catch (e) {
                this.showAlert(`Erro ao excluir ${term}.`);
            }
        }
    },
    
    openDuplicarCultoModal() {
        if (!this.adminSelectedCultoId) return;
        
        const c = this.cultosData.find(item => item.id === this.adminSelectedCultoId);
        if (!c) return;
        
        const actionsMenu = document.getElementById('active-culto-actions-menu');
        if (actionsMenu) actionsMenu.style.display = 'none';
        
        document.getElementById('duplicar-source-cultoid').value = c.id;
        document.getElementById('duplicar-source-nome').innerText = c.nome;
        document.getElementById('duplicar-source-horario').innerText = `${c.horarioInicio} às ${c.horarioFim}`;
        
        document.getElementById('duplicar-nova-data').value = this.formatLocalISOString(new Date()).split('T')[0];
        document.getElementById('duplicar-copiar-obreiros').checked = true;
        
        document.getElementById('modal-duplicar-culto').classList.add('active');
    },
    
    closeDuplicarCultoModal() {
        document.getElementById('modal-duplicar-culto').classList.remove('active');
    },
    
    async handleDuplicarCultoSubmit(event) {
        event.preventDefault();
        
        const sourceId = document.getElementById('duplicar-source-cultoid').value;
        const novaData = document.getElementById('duplicar-nova-data').value;
        const copiarObreiros = document.getElementById('duplicar-copiar-obreiros').checked;
        
        if (!sourceId || !novaData) {
            this.showAlert("Por favor, preencha todos os campos.");
            return;
        }
        
        const submitBtn = document.getElementById('btn-duplicar-culto-submit');
        const origBtnText = submitBtn.innerHTML;
        submitBtn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Duplicando...';
        submitBtn.disabled = true;
        
        try {
            const sourceCulto = this.cultosData.find(item => item.id === sourceId);
            if (!sourceCulto) {
                this.showAlert("Culto de origem não encontrado.");
                submitBtn.innerHTML = origBtnText;
                submitBtn.disabled = false;
                return;
            }
            
            const novoCultoPayload = {
                nome: sourceCulto.nome,
                data: novaData,
                horarioInicio: sourceCulto.horarioInicio,
                horarioFim: sourceCulto.horarioFim,
                tipo: sourceCulto.tipo,
                status: 'Planejado'
            };
            
            const novoCultoId = await DbService.saveCulto(null, novoCultoPayload);
            
            const sourceEscalas = await DbService.getEscalas(null, null, null, sourceId);
            
            const promises = sourceEscalas.map(async (escala) => {
                const novaEscalaPayload = {
                    setorId: escala.setorId,
                    funcao: escala.funcao,
                    data: novaData,
                    horarioInicio: escala.horarioInicio,
                    horarioFim: escala.horarioFim,
                    observacoes: escala.observacoes || '',
                    cultoId: novoCultoId,
                    cultoNome: sourceCulto.nome,
                    statusPresenca: 'Pendente',
                    statusServico: 'Agendado'
                };
                
                if (copiarObreiros && escala.membroId) {
                    novaEscalaPayload.membroId = escala.membroId;
                    novaEscalaPayload.membroNome = escala.membroNome;
                }
                
                return DbService.saveEscala(null, novaEscalaPayload);
            });
            
            await Promise.all(promises);
            
            this.adminSelectedCultoId = novoCultoId;
            this.closeDuplicarCultoModal();
            this.showToast('Culto e escalas duplicados com sucesso!', 'success');
            await this.loadAdminEscalas();
        } catch (e) {
            console.error("Error duplicating Culto:", e);
            this.showAlert("Erro ao duplicar culto e escalas.");
        } finally {
            submitBtn.innerHTML = origBtnText;
            submitBtn.disabled = false;
        }
    },
    
    async handlePublishActiveScale() {
        if (!this.adminSelectedCultoId) return;
        
        const c = this.cultosData.find(item => item.id === this.adminSelectedCultoId);
        if (!c) return;
        
        try {
            await DbService.saveCulto(c.id, { status: 'Confirmado' });
            
            const dateParts = c.data.split('-');
            const formattedDate = `${dateParts[2]}/${dateParts[1]}/${dateParts[0]}`;
            
            const term = c.tipo === 'especial' ? 'evento' : 'culto';
            
            // Removed: Do not create an Aviso for scale publication as per v3.10.4A requirements
            /*
            await DbService.saveAviso({
                titulo: `Escala Publicada - ${c.nome}`,
                conteudo: `A escala de voluntários para o ${term} "${c.nome}" no dia ${formattedDate} (${c.horarioInicio} às ${c.horarioFim}) foi publicada. Por favor, acesse o painel e confirme sua presença!`,
                autorNome: this.currentUser.nome,
                dataExpiracao: c.data
            });
            */
            
            this.showToast('Escala confirmada e publicada!', 'success');
            this.loadAdminEscalas();
        } catch (e) {
            this.showAlert('Erro ao publicar escala.');
        }
    },

    // --- TAB: REPOSIÇÕES (ADMIN) ---
    async loadAdminReposicoes() {
        const body = document.getElementById('admin-reposicoes-table-body');
        body.innerHTML = '<tr><td colspan="8" style="text-align:center;"><i class="fa-solid fa-spinner fa-spin"></i></td></tr>';

        try {
            const reqs = await DbService.getReposicoes();

            if (reqs.length === 0) {
                body.innerHTML = '<tr><td colspan="8" style="text-align:center; color: var(--slate-gray);">Nenhuma solicitação de reposição registrada.</td></tr>';
                return;
            }

            body.innerHTML = '';
            reqs.forEach(r => {
                let badgeStyle = '';
                if (r.status === 'Pendente') {
                    badgeStyle = 'background: #F1F5F9; color: #475569; border: 1px solid #CBD5E1;';
                } else if (r.status === 'Aguardando Compra') {
                    badgeStyle = 'background: #FEF3C7; color: #D97706; border: 1px solid #FCD34D;';
                } else if (r.status === 'Atendida') {
                    badgeStyle = 'background: #ECFDF5; color: #10B981; border: 1px solid #A7F3D0;';
                } else if (r.status === 'Rejeitado') {
                    badgeStyle = 'background: #FEE2E2; color: #EF4444; border: 1px solid #FCA5A5;';
                }

                const dt = r.dataSolicitacao.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' });
                const sectorColor = this.sectorsData[r.setorId]?.cor || '#1E4ED8';
                const sectorNome = r.setorNome || 'Limpeza';

                let actionBtn = '';
                if (r.status === 'Pendente') {
                    actionBtn = `<button class="btn-scale-action btn-confirm-presenca" style="padding:4px 8px; font-size:0.75rem; background-color:#6366F1; border-color:#6366F1; color:white; border-radius:6px; cursor:pointer;" onclick="App.openDesignarRepositorModal('${r.id}')"><i class="fa-solid fa-user-check"></i> Processar</button>`;
                } else if (r.status === 'Aguardando Compra') {
                    actionBtn = `
                        <div style="font-size:0.75rem; color:#D97706; font-weight:600; margin-bottom:4px;">Comprador: ${r.repositorNome}</div>
                        <button class="btn-scale-action btn-recusar-presenca" style="padding:2px 6px; font-size:0.7rem; background-color:#EF4444; border-color:#EF4444; color:white; border-radius:6px; cursor:pointer;" onclick="App.handleRejectReposicaoDeModal('${r.id}')"><i class="fa-solid fa-ban"></i> Rejeitar</button>
                    `;
                } else {
                    actionBtn = `<button class="btn-scale-action btn-confirm-presenca" style="padding:4px 8px; font-size:0.75rem; background-color:#475569; border-color:#475569; color:white; border-radius:6px; cursor:pointer;" onclick="App.openReposicaoRelatorioModal('${r.id}')"><i class="fa-solid fa-file-invoice-dollar"></i> Relatório</button>`;
                }

                const row = document.createElement('tr');
                row.innerHTML = `
                    <td>${dt}</td>
                    <td><b>${r.solicitadoPorNome}</b></td>
                    <td><span class="badge" style="background:${sectorColor}; color:#fff; font-weight:700;">${sectorNome}</span></td>
                    <td><b>${r.produtoNome}</b></td>
                    <td><span class="badge" style="background:#F1F5F9; color:var(--navy-dark);">${r.quantidade}</span></td>
                    <td><div style="max-width:180px; font-size:0.8rem; text-overflow:ellipsis; overflow:hidden; white-space:nowrap;" title="${r.observacao || ''}">${r.observacao || '-'}</div></td>
                    <td><span class="badge" style="${badgeStyle}">${r.status === 'Aguardando Compra' ? 'Em Compra' : r.status}</span></td>
                    <td>${actionBtn}</td>
                `;
                body.appendChild(row);
            });
        } catch (e) {
            body.innerHTML = '<tr><td colspan="8" style="color:red; text-align:center;">Erro ao carregar reposições.</td></tr>';
        }
    },

    async openDesignarRepositorModal(reposicaoId) {
        try {
            const repDoc = await db.collection('reposicoes').doc(reposicaoId).get();
            if (!repDoc.exists) return;
            const r = repDoc.data();

            document.getElementById('designar-reposicao-id').value = reposicaoId;
            document.getElementById('designar-solicitante-nome').textContent = r.solicitadoPorNome;
            document.getElementById('designar-produto-nome').textContent = r.produtoNome;
            document.getElementById('designar-produto-qtd').textContent = r.quantidade;

            const repositores = await DbService.getRepositores();
            const select = document.getElementById('designar-repositor-select');
            select.innerHTML = '<option value="" disabled selected>Selecione um repositor...</option>';
            
            if (repositores.length === 0) {
                select.innerHTML = '<option value="" disabled>Nenhum repositor cadastrado</option>';
            } else {
                repositores.forEach(rep => {
                    const opt = document.createElement('option');
                    opt.value = rep.id;
                    opt.textContent = `${rep.nome} (${(rep.setores || [rep.setor]).map(s => this.sectorsData[s]?.nome || s).join(', ')})`;
                    select.appendChild(opt);
                });
            }

            document.getElementById('modal-designar-repositor').style.display = 'flex';
        } catch (e) {
            console.error(e);
            this.showAlert('Erro ao carregar dados de designação.');
        }
    },

    closeDesignarRepositorModal() {
        document.getElementById('modal-designar-repositor').style.display = 'none';
    },

    async handleDesignarRepositorSubmit(event) {
        event.preventDefault();
        const reposicaoId = document.getElementById('designar-reposicao-id').value;
        const select = document.getElementById('designar-repositor-select');
        const repositorId = select.value;
        const repositorOption = select.options[select.selectedIndex];
        const repositorNome = repositorOption ? repositorOption.textContent.split(' (')[0] : '';

        if (!reposicaoId || !repositorId) {
            this.showAlert('Por favor, selecione um repositor.');
            return;
        }

        try {
            await db.collection('reposicoes').doc(reposicaoId).update({
                status: 'Aguardando Compra',
                repositorId,
                repositorNome,
                designadoEm: firebase.firestore.FieldValue.serverTimestamp()
            });

            const repDoc = await db.collection('reposicoes').doc(reposicaoId).get();
            if (repDoc.exists) {
                const repData = repDoc.data();
                
                await DbService.addNotificacao({
                    paraUsuarioId: repData.solicitadoPorId,
                    mensagem: `Seu pedido de "${repData.produtoNome}" (${repData.quantidade} unidades) foi aprovado pelo supervisor e designado para compra com ${repositorNome}.`,
                    reposicaoId: reposicaoId
                });
            }

            this.closeDesignarRepositorModal();
            this.showToast('Solicitação aprovada e designada para o comprador!', 'success');
            this.loadAdminReposicoes();
        } catch (e) {
            console.error(e);
            this.showAlert('Erro ao designar repositor.');
        }
    },

    async handleRejectReposicaoDeModal(reposicaoId) {
        const id = reposicaoId || document.getElementById('designar-reposicao-id').value;
        if (!id) return;

        const motivo = prompt('Por favor, digite o motivo da rejeição do pedido:');
        if (motivo === null) return;
        
        try {
            await db.collection('reposicoes').doc(id).update({
                status: 'Rejeitado',
                motivoRejeicao: motivo || 'Sem motivo informado',
                rejeitadoEm: firebase.firestore.FieldValue.serverTimestamp()
            });

            const repDoc = await db.collection('reposicoes').doc(id).get();
            if (repDoc.exists) {
                const repData = repDoc.data();
                
                await DbService.addNotificacao({
                    paraUsuarioId: repData.solicitadoPorId,
                    mensagem: `Seu pedido de "${repData.produtoNome}" foi rejeitado. Motivo: ${motivo || 'Sem motivo informado'}.`,
                    reposicaoId: id
                });
            }

            this.closeDesignarRepositorModal();
            this.showToast('Solicitação rejeitada e arquivada.', 'success');
            this.loadAdminReposicoes();
        } catch (e) {
            console.error(e);
            this.showAlert('Erro ao rejeitar solicitação.');
        }
    },

    async openReposicaoRelatorioModal(reposicaoId) {
        try {
            const repDoc = await db.collection('reposicoes').doc(reposicaoId).get();
            if (!repDoc.exists) return;
            const r = repDoc.data();

            const container = document.getElementById('reposicao-relatorio-conteudo');
            
            let statusBadgeStyle = '';
            if (r.status === 'Atendida') statusBadgeStyle = 'background: #ECFDF5; color: #10B981; border: 1px solid #A7F3D0;';
            else statusBadgeStyle = 'background: #FEE2E2; color: #EF4444; border: 1px solid #FCA5A5;';

            const dataSolicitada = r.dataSolicitacao ? (r.dataSolicitacao.toDate ? r.dataSolicitacao.toDate() : new Date(r.dataSolicitacao)) : new Date();
            const formattedDateSol = dataSolicitada.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' });

            let detailsHtml = `
                <div style="background: #F8FAFC; padding: 12px; border-radius: 8px; border: 1px solid #E2E8F0;">
                    <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom: 10px;">
                        <span style="font-size: 0.8rem; text-transform: uppercase; font-weight:700; color:var(--slate-gray);">Solicitação</span>
                        <span class="badge" style="${statusBadgeStyle} font-weight:700;">${r.status}</span>
                    </div>
                    <b>Solicitante:</b> ${r.solicitadoPorNome}<br>
                    <b>Setor:</b> ${r.setorNome || 'Limpeza'}<br>
                    <b>Produto:</b> ${r.produtoNome}<br>
                    <b>Qtd Solicitada:</b> ${r.quantidade}<br>
                    <b>Data:</b> ${formattedDateSol}<br>
                    <b>Observações:</b> ${r.observacao || '-'}<br>
                </div>
            `;

            if (r.repositorNome) {
                let compraHtml = '';
                if (r.status === 'Atendida') {
                    const dataCompra = r.dataCompra ? (r.dataCompra.toDate ? r.dataCompra.toDate() : new Date(r.dataCompra)) : new Date();
                    const formattedDateCompra = dataCompra.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' });
                    
                    compraHtml = `
                        <b>Comprador Designado:</b> ${r.repositorNome}<br>
                        <b>Data/Hora da Compra:</b> ${formattedDateCompra}<br>
                        <b>Qtd Real Comprada:</b> ${r.quantidadeComprada || r.quantidade}<br>
                        <b>Valor Total Gasto:</b> <span style="font-weight:700; color:#10B981;">R$ ${(r.valorGasto || 0).toFixed(2)}</span><br>
                        <b>Observação do Comprador:</b> ${r.compraObservacao || '-'}<br>
                    `;
                } else if (r.status === 'Rejeitado') {
                    compraHtml = `
                        <b>Comprador Designado:</b> ${r.repositorNome}<br>
                        <b>Motivo da Rejeição:</b> <span style="color:#EF4444;">${r.motivoRejeicao || 'Pedido recusado pelo comprador'}</span><br>
                    `;
                }
                
                detailsHtml += `
                    <div style="background: #FAF5FF; padding: 12px; border-radius: 8px; border: 1px solid #F3E8FF; margin-top: 10px;">
                        <div style="font-size: 0.8rem; text-transform: uppercase; font-weight:700; color:#5F388C; margin-bottom: 10px;">Processamento & Compra</div>
                        ${compraHtml}
                    </div>
                `;
            } else if (r.status === 'Rejeitado') {
                detailsHtml += `
                    <div style="background: #FEF2F2; padding: 12px; border-radius: 8px; border: 1px solid #FEE2E2; margin-top: 10px; color:#EF4444;">
                        <b>Rejeitado pelo Supervisor</b><br>
                        <b>Motivo:</b> ${r.motivoRejeicao || 'Sem justificativa'}
                    </div>
                `;
            }

            container.innerHTML = detailsHtml;
            document.getElementById('modal-reposicao-relatorio').style.display = 'flex';
        } catch (e) {
            console.error(e);
            this.showAlert('Erro ao abrir o relatório de reposição.');
        }
    },

    closeReposicaoRelatorioModal() {
        document.getElementById('modal-reposicao-relatorio').style.display = 'none';
    },

    // --- TAB: PRODUTOS (ADMIN) ---
    async loadAdminProdutos() {
        const body = document.getElementById('admin-produtos-table-body');
        body.innerHTML = '<tr><td colspan="4" style="text-align:center;"><i class="fa-solid fa-spinner fa-spin"></i></td></tr>';

        const filterSelect = document.getElementById('admin-products-sector-filter');
        if (filterSelect && filterSelect.options.length === 0) {
            filterSelect.innerHTML = '';
            for (const [key, sector] of Object.entries(this.sectorsData)) {
                const opt = document.createElement('option');
                opt.value = key;
                opt.textContent = sector.nome;
                filterSelect.appendChild(opt);
            }
        }
        const selectedSectorId = (filterSelect && filterSelect.value) ? filterSelect.value : 'limpeza';

        this.loadAdminStockHistory(selectedSectorId);

        try {
            const produtos = await DbService.getProdutos();
            const sectorProducts = produtos.filter(p => (p.setorId || 'limpeza') === selectedSectorId);

            if (sectorProducts.length === 0) {
                body.innerHTML = '<tr><td colspan="4" style="text-align:center; color: var(--slate-gray);">Nenhum produto cadastrado para este setor.</td></tr>';
                return;
            }

            body.innerHTML = '';
            sectorProducts.forEach((p) => {
                const statusBadge = p.status === 'ativo' ? '<span class="badge badge-active">Ativo</span>' : '<span class="badge badge-inactive">Inativo</span>';
                
                const qty = typeof p.quantidade === 'number' ? p.quantidade : 0;
                let qtyBadge = '';
                if (qty <= 5) {
                    qtyBadge = `<span class="badge badge-inactive" style="background: #FEE2E2; color: #EF4444; border-color: #FCA5A5; font-size: 0.85rem; font-weight: 700; padding: 4px 10px;">${qty} (Baixo)</span>`;
                } else if (qty <= 15) {
                    qtyBadge = `<span class="badge badge-warn" style="background: #FEF3C7; color: #D97706; border-color: #FCD34D; font-size: 0.85rem; font-weight: 700; padding: 4px 10px;">${qty}</span>`;
                } else {
                    qtyBadge = `<span class="badge badge-active" style="background: #ECFDF5; color: #10B981; border-color: #A7F3D0; font-size: 0.85rem; font-weight: 700; padding: 4px 10px;">${qty}</span>`;
                }

                const actionBtn = p.status === 'ativo' 
                    ? `<div style="display: flex; gap: 6px; justify-content: flex-end; flex-wrap: wrap;">
                           <button class="btn-scale-action btn-confirm-presenca" style="padding:4px 8px; font-size:0.75rem; background-color: #10B981; border-color: #10B981; color: white; flex: none; width: auto;" onclick="App.openStockMovementModal('${p.id}', 'entrada')"><i class="fa-solid fa-plus"></i> Entrada</button>
                           <button class="btn-scale-action btn-recusar-presenca" style="padding:4px 8px; font-size:0.75rem; background-color: #EF4444; border-color: #EF4444; color: white; flex: none; width: auto;" onclick="App.openStockMovementModal('${p.id}', 'saida')"><i class="fa-solid fa-minus"></i> Saída</button>
                           <button class="btn-scale-action btn-recusar-presenca" style="padding:4px 8px; font-size:0.75rem; flex: none; width: auto;" onclick="App.handleToggleProductStatus('${p.id}', 'inativo')">Desativar</button>
                       </div>`
                    : `<div style="display: flex; gap: 6px; justify-content: flex-end; flex-wrap: wrap;">
                           <button class="btn-scale-action btn-confirm-presenca" style="padding:4px 8px; font-size:0.75rem; flex: none; width: auto;" onclick="App.handleToggleProductStatus('${p.id}', 'ativo')">Ativar</button>
                       </div>`;

                const row = document.createElement('tr');
                row.innerHTML = `
                    <td><b>${p.nome}</b></td>
                    <td style="text-align: center;">${qtyBadge}</td>
                    <td>${statusBadge}</td>
                    <td style="text-align: right;">${actionBtn}</td>
                `;
                body.appendChild(row);
            });
        } catch (e) {
            console.error(e);
            body.innerHTML = '<tr><td colspan="4" style="color:red; text-align:center;">Erro ao carregar produtos.</td></tr>';
        }
    },

    async loadAdminStockHistory(setorId) {
        const listEl = document.getElementById('admin-stock-history-list');
        if (!listEl) return;
        listEl.innerHTML = '<div style="text-align:center; padding: 20px; color: var(--slate-gray);"><i class="fa-solid fa-spinner fa-spin"></i> Carregando...</div>';

        try {
            const movimentacoes = await DbService.getMovimentacoesEstoque(setorId);

            if (movimentacoes.length === 0) {
                listEl.innerHTML = '<div style="text-align:center; padding: 20px; color: var(--slate-gray); font-size: 0.9rem;">Nenhuma movimentação registrada.</div>';
                return;
            }

            listEl.innerHTML = '';
            movimentacoes.forEach(m => {
                const isEntrada = m.tipo === 'entrada';
                const typeIcon = isEntrada ? '<i class="fa-solid fa-circle-arrow-up" style="color: #10B981; font-size: 1.1rem;"></i>' : '<i class="fa-solid fa-circle-arrow-down" style="color: #EF4444; font-size: 1.1rem;"></i>';
                const badgeStyle = isEntrada ? 'background: #ECFDF5; color: #10B981;' : 'background: #FEE2E2; color: #EF4444;';
                const qtyPrefix = isEntrada ? '+' : '-';
                
                const dateOptions = { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' };
                const formattedDate = new Date(m.dataMovimentacao).toLocaleDateString('pt-BR', dateOptions);

                const item = document.createElement('div');
                item.style.cssText = "display: flex; gap: 12px; padding: 12px; background: #F8FAFC; border-radius: 8px; border-left: 4px solid " + (isEntrada ? "#10B981" : "#EF4444") + "; box-shadow: 0 1px 2px rgba(0,0,0,0.02);";
                item.innerHTML = `
                    <div style="display: flex; align-items: center; justify-content: center;">
                        ${typeIcon}
                    </div>
                    <div style="flex: 1; min-width: 0;">
                        <div style="display: flex; justify-content: space-between; align-items: baseline; gap: 5px;">
                            <span style="font-weight: 600; font-size: 0.9rem; color: var(--navy-dark); text-overflow: ellipsis; overflow: hidden; white-space: nowrap;">${m.produtoNome}</span>
                            <span class="badge" style="font-weight: 700; font-size: 0.8rem; padding: 2px 6px; ${badgeStyle}">${qtyPrefix}${m.quantidade}</span>
                        </div>
                        <div style="font-size: 0.8rem; color: var(--slate-gray); margin-top: 4px;">
                            ${m.observacao ? `<b>Motivo:</b> ${m.observacao}<br>` : ''}
                            <span style="font-size: 0.75rem; color: #94A3B8;">Por ${m.usuarioNome} • ${formattedDate}</span>
                        </div>
                    </div>
                `;
                listEl.appendChild(item);
            });
        } catch (e) {
            console.error(e);
            listEl.innerHTML = '<div style="text-align:center; padding: 20px; color: #EF4444; font-size: 0.9rem;">Erro ao carregar histórico.</div>';
        }
    },

    async handleProductAdd(event) {
        event.preventDefault();
        const input = document.getElementById('new-product-name');
        const qtyInput = document.getElementById('new-product-qty');
        
        const filterSelect = document.getElementById('admin-products-sector-filter');
        const sectorId = filterSelect ? filterSelect.value : 'limpeza';

        const nome = input.value.trim();
        const initialQty = qtyInput ? parseInt(qtyInput.value, 10) : 10;

        if (!nome) return;

        try {
            const docRef = await db.collection('produtos').add({
                nome: nome,
                setorId: sectorId,
                quantidade: isNaN(initialQty) ? 0 : initialQty,
                status: 'ativo'
            });

            if (initialQty > 0) {
                const usuarioNome = this.currentUser ? this.currentUser.nome : 'Supervisor';
                await db.collection('historico_estoque').add({
                    produtoId: docRef.id,
                    produtoNome: nome,
                    setorId: sectorId,
                    tipo: 'entrada',
                    quantidade: initialQty,
                    observacao: 'Carga inicial de estoque',
                    usuarioNome: usuarioNome,
                    dataMovimentacao: firebase.firestore.FieldValue.serverTimestamp()
                });
            }

            input.value = '';
            if (qtyInput) qtyInput.value = '10';
            this.showToast('Produto cadastrado com sucesso!', 'success');
            this.loadAdminProdutos();
        } catch (e) {
            console.error(e);
            this.showAlert('Erro ao adicionar produto.');
        }
    },

    async handleToggleProductStatus(id, newStatus) {
        try {
            await DbService.saveProduto(id, { status: newStatus });
            this.showToast(`Produto atualizado!`, 'success');
            this.loadAdminProdutos();
        } catch (e) {
            this.showAlert('Erro ao alterar status do produto.');
        }
    },

    async openStockMovementModal(produtoId, tipo) {
        try {
            const snap = await db.collection('produtos').doc(produtoId).get();
            if (!snap.exists) return;
            const p = snap.data();

            document.getElementById('movimentacao-produto-id').value = produtoId;
            document.getElementById('movimentacao-tipo').value = tipo;
            document.getElementById('movimentacao-quantidade').value = '';
            document.getElementById('movimentacao-observacao').value = '';

            const title = document.getElementById('movimentacao-estoque-titulo');
            const submitBtn = document.getElementById('btn-movimentacao-estoque-submit');
            const prodNameEl = document.getElementById('movimentacao-estoque-produto-nome');

            prodNameEl.textContent = `Produto: ${p.nome.toUpperCase()}`;

            if (tipo === 'entrada') {
                title.innerHTML = '<i class="fa-solid fa-circle-arrow-up" style="color: #10B981; margin-right: 5px;"></i> Registrar Entrada';
                submitBtn.className = 'btn-primary';
                submitBtn.style.backgroundColor = '#10B981';
                submitBtn.style.borderColor = '#10B981';
                submitBtn.textContent = 'Registrar Entrada';
            } else {
                title.innerHTML = '<i class="fa-solid fa-circle-arrow-down" style="color: #EF4444; margin-right: 5px;"></i> Registrar Saída';
                submitBtn.className = 'btn-primary';
                submitBtn.style.backgroundColor = '#EF4444';
                submitBtn.style.borderColor = '#EF4444';
                submitBtn.textContent = 'Registrar Saída';
            }

            document.getElementById('modal-movimentacao-estoque').style.display = 'flex';
        } catch (e) {
            console.error(e);
            this.showAlert('Erro ao abrir o modal de movimentação.');
        }
    },

    closeMovimentacaoEstoqueModal() {
        document.getElementById('modal-movimentacao-estoque').style.display = 'none';
    },

    async handleStockMovementSubmit(event) {
        event.preventDefault();
        const produtoId = document.getElementById('movimentacao-produto-id').value;
        const tipo = document.getElementById('movimentacao-tipo').value;
        const quantidade = parseInt(document.getElementById('movimentacao-quantidade').value, 10);
        const observacao = document.getElementById('movimentacao-observacao').value.trim();

        if (!produtoId || !tipo || isNaN(quantidade) || quantidade <= 0) {
            this.showAlert('Por favor, informe uma quantidade válida.');
            return;
        }

        try {
            const usuarioNome = this.currentUser ? this.currentUser.nome : 'Supervisor';
            await DbService.registrarMovimentacaoEstoque(produtoId, tipo, quantidade, observacao, usuarioNome);

            this.closeMovimentacaoEstoqueModal();
            this.showToast('Estoque atualizado com sucesso!', 'success');
            
            if (this.currentView === 'member') {
                this.loadAndRenderMemberReplenish();
            } else {
                this.loadAdminProdutos();
            }
        } catch (e) {
            console.error(e);
            this.showAlert(e.message || 'Erro ao registrar movimentação.');
        }
    },

    // --- TAB: RELATÓRIOS (ADMIN) ---
    async loadAdminRelatorios() {
        const select = document.getElementById('report-filter-month');
        
        // Populate Month options if empty
        if (select.innerHTML.trim() === '') {
            select.innerHTML = '';
            
            // Current month plus last 5 months
            const date = new Date();
            for (let i = 0; i < 6; i++) {
                const optDate = new Date(date.getFullYear(), date.getMonth() - i, 1);
                const val = this.formatLocalISOString(optDate).substring(0, 7); // YYYY-MM
                const label = optDate.toLocaleDateString('pt-BR', { month: 'long', year: 'numeric' });
                
                const opt = document.createElement('option');
                opt.value = val;
                opt.innerText = label.charAt(0).toUpperCase() + label.slice(1);
                select.appendChild(opt);
            }
        }

        this.loadAndRenderReports();
    },

    async loadAndRenderReports() {
        const selectedMonth = document.getElementById('report-filter-month').value; // format "YYYY-MM"
        
        const servedList = document.getElementById('report-list-served');
        const notServedList = document.getElementById('report-list-not-served');
        const historyBody = document.getElementById('admin-history-table-body');

        servedList.innerHTML = '<div style="text-align:center;"><i class="fa-solid fa-spinner fa-spin"></i></div>';
        notServedList.innerHTML = '<div style="text-align:center;"><i class="fa-solid fa-spinner fa-spin"></i></div>';
        historyBody.innerHTML = '<tr><td colspan="6" style="text-align:center;"><i class="fa-solid fa-spinner fa-spin"></i></td></tr>';

        try {
            // Get all members and active history
            const membros = await DbService.getMembros();
            const voluntáriosAtivos = membros.filter(m => m.perfil === 'membro' && m.status === 'ativo');
            
            const historico = await DbService.getHistoricoServicos();
            
            // Filter history for selected month
            const monthHistory = historico.filter(s => {
                if (!s.finalizadoEm) return false;
                const dateStr = this.formatLocalISOString(s.finalizadoEm).substring(0, 7); // YYYY-MM
                return dateStr === selectedMonth;
            });

            // 1. Identify who served and who hasn't
            const servedIds = new Set(monthHistory.map(s => s.membroId));
            
            const servedMembers = voluntáriosAtivos.filter(m => servedIds.has(m.id));
            const notServedMembers = voluntáriosAtivos.filter(m => !servedIds.has(m.id));

            // 2. Render Served List
            if (servedMembers.length === 0) {
                servedList.innerHTML = '<p style="text-align:center; color:var(--slate-gray); padding:20px; font-size:0.9rem;">Ninguém serviu ainda este mês.</p>';
            } else {
                servedList.innerHTML = '';
                servedMembers.forEach(m => {
                    const mSetores = m.setores || (m.setor ? [m.setor] : []);
                    const setoresText = mSetores.map(sId => this.sectorsData[sId]?.nome || sId).join(', ') || 'Sem Setor';
                    const div = document.createElement('div');
                    div.className = 'report-row';
                    div.innerHTML = `
                        <div>
                            <b>${m.nome}</b>
                            <div style="font-size:0.75rem; color:var(--slate-gray);">${setoresText}</div>
                        </div>
                        <span class="badge badge-active" style="border:none;"><i class="fa-solid fa-circle-check"></i> Serviu</span>
                    `;
                    servedList.appendChild(div);
                });
            }

            // 3. Render Not Served List
            if (notServedMembers.length === 0) {
                notServedList.innerHTML = '<p style="text-align:center; color:#10B981; padding:20px; font-size:0.9rem; font-weight:600;"><i class="fa-solid fa-circle-check"></i> Todos os voluntários já serviram!</p>';
            } else {
                notServedList.innerHTML = '';
                notServedMembers.forEach(m => {
                    const mSetores = m.setores || (m.setor ? [m.setor] : []);
                    const setoresText = mSetores.map(sId => this.sectorsData[sId]?.nome || sId).join(', ') || 'Sem Setor';
                    const div = document.createElement('div');
                    div.className = 'report-row';
                    div.innerHTML = `
                        <div>
                            <b>${m.nome}</b>
                            <div style="font-size:0.75rem; color:var(--slate-gray);">${setoresText}</div>
                        </div>
                        <span class="badge" style="background:#FEF3C7; color:#D97706;"><i class="fa-solid fa-circle-exmark"></i> Não Serviu</span>
                    `;
                    notServedList.appendChild(div);
                });
            }

            // 4. Render general finalized history
            if (historico.length === 0) {
                historyBody.innerHTML = '<tr><td colspan="6" style="text-align:center; color:var(--slate-gray);">Nenhum serviço finalizado no histórico.</td></tr>';
                return;
            }

            historyBody.innerHTML = '';
            historico.forEach(s => {
                if (!s.data) return; // Pula registros com campo 'data' ausente
                const dateParts = s.data.split('-');
                const formattedDate = `${dateParts[2]}/${dateParts[1]}/${dateParts[0]}`;
                const sector = this.sectorsData[s.setorId];

                // Compute service duration in minutes
                let durationText = '-';
                if (s.iniciadoEm && s.finalizadoEm) {
                    const diffMs = s.finalizadoEm - s.iniciadoEm;
                    const diffMins = Math.round(diffMs / 60000);
                    if (diffMins < 60) {
                        durationText = `${diffMins} min`;
                    } else {
                        const hrs = Math.floor(diffMins / 60);
                        const mins = diffMins % 60;
                        durationText = `${hrs}h ${mins}m`;
                    }
                }

                const row = document.createElement('tr');
                row.innerHTML = `
                    <td>${formattedDate}</td>
                    <td><span class="badge" style="background:${sector ? sector.cor + '22' : '#f1f5f9'}; color:${sector ? sector.cor : 'var(--navy-dark)'};">${sector ? sector.nome : s.setorId}</span></td>
                    <td><b>${s.membroNome}</b></td>
                    <td>${s.funcao}</td>
                    <td><span class="badge" style="background:#f1f5f9; color:var(--navy-dark); font-weight:600;"><i class="fa-regular fa-clock"></i> ${durationText}</span></td>
                    <td><div style="max-width:200px; font-size:0.8rem; text-overflow:ellipsis; overflow:hidden; white-space:nowrap;" title="${s.observacoes || ''}">${s.observacoes || '-'}</div></td>
                `;
                historyBody.appendChild(row);
            });

        } catch (e) {
            console.error("Relatorios rendering error:", e);
            // Exibe mensagem de erro nos 3 painéis para não ficarem presos no spinner
            const errMsg = '<p style="text-align:center; color:#EF4444; padding:20px; font-size:0.9rem;"><i class="fa-solid fa-triangle-exclamation" style="margin-right:6px;"></i>Erro ao carregar dados. Verifique a conexão.</p>';
            const errRow = '<tr><td colspan="6" style="color:#EF4444; text-align:center; padding:20px;"><i class="fa-solid fa-triangle-exclamation" style="margin-right:6px;"></i>Erro ao carregar histórico.</td></tr>';
            const sL = document.getElementById('report-list-served');
            const nL = document.getElementById('report-list-not-served');
            const hB = document.getElementById('admin-history-table-body');
            if (sL) sL.innerHTML = errMsg;
            if (nL) nL.innerHTML = errMsg;
            if (hB) hB.innerHTML = errRow;
        }
    },

    // ==========================================================================
    // UTILS & FLOATING NOTIFICATIONS
    // ==========================================================================
    
    // Toggle Password Visibility helper
    togglePasswordVisibility(fieldId, iconEl) {
        const input = document.getElementById(fieldId);
        if (input.type === 'password') {
            input.type = 'text';
            iconEl.className = 'fa-solid fa-eye';
        } else {
            input.type = 'password';
            iconEl.className = 'fa-solid fa-eye-slash';
        }
    },

    formatLocalISOString(date = new Date()) {
        const offsetMin = date.getTimezoneOffset();
        const localDate = new Date(date.getTime() - (offsetMin * 60 * 1000));
        return localDate.toISOString();
    },

    // Helper date ranges generator (Week / Month)
    getStartAndEndDates(baseDate, period) {
        const date = new Date(baseDate);
        if (period === 'week') {
            // Find Monday of the current week
            const day = date.getDay();
            const diff = date.getDate() - day + (day === 0 ? -6 : 1); // adjust when day is sunday
            const monday = new Date(date.setDate(diff));
            const sunday = new Date(date.setDate(diff + 6));
            
            const startStr = this.formatLocalISOString(monday).split('T')[0];
            const endStr = this.formatLocalISOString(sunday).split('T')[0];

            const mondayLbl = monday.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit' });
            const sundayLbl = sunday.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit' });

            return {
                start: startStr,
                end: endStr,
                label: `${mondayLbl} a ${sundayLbl}`
            };
        } else {
            // Monthly range: expanded to cover 3 months (previous month, current month, and next month)
            // This ensures members have at least 3 months active/accessible in their calendar.
            const firstDay = new Date(date.getFullYear(), date.getMonth() - 1, 1);
            const lastDay = new Date(date.getFullYear(), date.getMonth() + 2, 0);

            const startStr = this.formatLocalISOString(firstDay).split('T')[0];
            const endStr = this.formatLocalISOString(lastDay).split('T')[0];

            const currentFirstDay = new Date(date.getFullYear(), date.getMonth(), 1);
            const monthLbl = currentFirstDay.toLocaleDateString('pt-BR', { month: 'long', year: 'numeric' });

            return {
                start: startStr,
                end: endStr,
                label: monthLbl.charAt(0).toUpperCase() + monthLbl.slice(1)
            };
        }
    },

    // Custom alerts
    showAlert(message, title = 'Aviso') {
        document.getElementById('alert-title').innerText = title;
        const msgEl = document.getElementById('alert-message');
        if (message && (message.includes('<') || message.includes('\n'))) {
            // Replace newlines with <br> if it's plain text, otherwise render as HTML
            if (!message.includes('<div') && !message.includes('<p') && !message.includes('<span') && !message.includes('<br')) {
                msgEl.innerHTML = message.replace(/\n/g, '<br>');
            } else {
                msgEl.innerHTML = message;
            }
        } else {
            msgEl.innerText = message;
        }
        document.getElementById('custom-alert-modal').classList.add('active');
    },

    closeAlert() {
        document.getElementById('custom-alert-modal').classList.remove('active');
    },

    showLoading() {
        let loader = document.getElementById('global-app-loader');
        if (!loader) {
            loader = document.createElement('div');
            loader.id = 'global-app-loader';
            loader.style.cssText = `
                position: fixed;
                top: 0;
                left: 0;
                width: 100vw;
                height: 100vh;
                background: rgba(15, 23, 42, 0.6);
                backdrop-filter: blur(4px);
                display: flex;
                align-items: center;
                justify-content: center;
                z-index: 10000;
                opacity: 0;
                transition: opacity 0.25s ease;
            `;
            loader.innerHTML = `
                <div style="background: rgba(30, 41, 59, 0.9); padding: 24px; border-radius: 16px; display: flex; flex-direction: column; align-items: center; gap: 12px; border: 1px solid rgba(255,255,255,0.08); box-shadow: 0 20px 25px -5px rgb(0 0 0 / 0.5);">
                    <i class="fa-solid fa-circle-notch fa-spin" style="font-size: 2rem; color: var(--theme-color);"></i>
                    <span style="color: #fff; font-size: 0.88rem; font-weight: 600; font-family: inherit;">Processando...</span>
                </div>
            `;
            document.body.appendChild(loader);
        }
        loader.offsetHeight; // force reflow
        loader.style.opacity = '1';
    },

    hideLoading() {
        const loader = document.getElementById('global-app-loader');
        if (loader) {
            loader.style.opacity = '0';
            setTimeout(() => {
                if (loader.parentNode) {
                    loader.parentNode.removeChild(loader);
                }
            }, 250);
        }
    },

    // Toast alerts wrapper
    showToast(message, type = 'success') {
        const toast = document.createElement('div');
        toast.style.cssText = `
            position: fixed;
            bottom: 20px;
            right: 20px;
            background: ${type === 'success' ? '#10B981' : type === 'error' ? '#EF4444' : '#1E293B'};
            color: #fff;
            padding: 12px 24px;
            border-radius: 10px;
            font-size: 0.9rem;
            font-weight: 600;
            box-shadow: 0 4px 12px rgba(0,0,0,0.15);
            z-index: 9999;
            transform: translateY(100px);
            opacity: 0;
            transition: all 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275);
            display: flex;
            align-items: center;
            gap: 8px;
        `;
        
        let icon = '<i class="fa-solid fa-circle-check"></i>';
        if (type === 'error') icon = '<i class="fa-solid fa-triangle-exclamation"></i>';
        if (type === 'info') icon = '<i class="fa-solid fa-info-circle"></i>';

        toast.innerHTML = `${icon} <span>${message}</span>`;
        document.body.appendChild(toast);
        
        // Anim in
        setTimeout(() => {
            toast.style.transform = 'translateY(0)';
            toast.style.opacity = '1';
        }, 100);

        // Anim out
        setTimeout(() => {
            toast.style.transform = 'translateY(100px)';
            toast.style.opacity = '0';
            setTimeout(() => toast.remove(), 400);
        }, 3000);
    },

    // --- CES Diaconia v3.2 - STANDBY & VOLUNTARIADO ---
    async handleRegisterStandby(cultoId, cultoNome, dateStr, horario, nodeId) {
        try {
            App.showLoading();
            const standbys = await DbService.getStandbys();
            const alreadyRegistered = standbys.some(s => s.cultoId === cultoId && s.membroId === App.currentUser.id);
            if (alreadyRegistered) {
                App.hideLoading();
                App.showToast('Você já se candidatou como voluntário para este culto.', 'info');
                return;
            }
            
            let sectorId = App.activeSectorId;
            let funcao = App.currentUser.funcao || 'Voluntário';
            
            // Definir funcao padrao com base no nodeId
            const titleMap = {
                'recepcao': 'Check-in',
                'templo': 'Apoio Templo / Ronda Lado Direito',
                'ronda': 'Apoio Templo / Ronda Lado Direito',
                'acolhimento': 'Acolhimento'
            };
            funcao = titleMap[nodeId] || App.currentUser.funcao || 'Voluntário';

            // Carregar do select se houver
            const selectEl = document.getElementById('standby-role-select');
            if (selectEl) {
                funcao = selectEl.value;
            }

            // Mapear sectorId com base na funcao selecionada
            const funcLower = funcao.toLowerCase();
            if (funcLower.includes('entrada')) {
                sectorId = 'entrada';
            } else if (funcLower.includes('check')) {
                sectorId = 'check_in';
            } else if (funcLower.includes('acolhimento')) {
                sectorId = 'acolhimento';
            } else if (funcLower.includes('direito') || funcLower.includes('dir')) {
                sectorId = 'apoio_templo_ronda_dir';
            } else if (funcLower.includes('esquerdo') || funcLower.includes('esq')) {
                sectorId = 'apoio_templo_ronda_esq';
            } else {
                sectorId = App.activeSectorId;
            }
            
            const standbyData = {
                cultoId,
                cultoNome,
                dataCulto: dateStr,
                horario,
                membroId: App.currentUser.id,
                membroNome: App.currentUser.nome,
                membroFotoUrl: App.currentUser.fotoUrl || null,
                setorId: sectorId,
                funcao: funcao
            };
            
            await DbService.saveStandby(standbyData);
            
            await DbService.addNotificacao({
                paraUsuarioId: 'admin_default',
                paraUsuarioNome: 'Supervisor Geral',
                titulo: 'Novo Voluntário Disponível',
                mensagem: `${App.currentUser.nome} se colocou à disposição para trabalhar no culto ${cultoNome} (${dateStr}).`,
                tipo: 'standby'
            });
            
            App.hideLoading();
            App.showToast('Candidatura de voluntário registrada com sucesso!', 'success');
            
            App.openAreaDetail(nodeId);
        } catch (err) {
            App.hideLoading();
            console.error("Error registering standby:", err);
            App.showToast('Erro ao registrar candidatura.', 'danger');
        }
    },

    async handleCancelStandby(standbyId, nodeId) {
        if (!confirm('Deseja realmente cancelar sua disponibilidade para este culto?')) return;
        try {
            App.showLoading();
            await DbService.deleteStandby(standbyId);
            App.hideLoading();
            App.showToast('Disponibilidade cancelada.', 'success');
            if (nodeId) {
                App.openAreaDetail(nodeId);
            } else {
                App.loadAndRenderMemberScales();
            }
        } catch (err) {
            App.hideLoading();
            console.error("Error cancelling standby:", err);
            App.showToast('Erro ao cancelar disponibilidade.', 'danger');
        }
    },

    async handleCancelStandbyFromList(standbyId) {
        await App.handleCancelStandby(standbyId, null);
    },

    async handleRegisterStandbyFromList(cultoId, cultoNome, dateStr, horario) {
        try {
            App.showLoading();
            const standbys = await DbService.getStandbys();
            const alreadyRegistered = standbys.some(s => s.cultoId === cultoId && s.membroId === App.currentUser.id);
            if (alreadyRegistered) {
                App.hideLoading();
                App.showToast('Você já se candidatou como voluntário para este culto.', 'info');
                return;
            }
            
            const standbyData = {
                cultoId,
                cultoNome,
                dataCulto: dateStr,
                horario,
                membroId: App.currentUser.id,
                membroNome: App.currentUser.nome,
                membroFotoUrl: App.currentUser.fotoUrl || null,
                setorId: App.activeSectorId,
                funcao: App.currentUser.funcao || 'Voluntário'
            };
            
            await DbService.saveStandby(standbyData);
            
            await DbService.addNotificacao({
                paraUsuarioId: 'admin_default',
                paraUsuarioNome: 'Supervisor Geral',
                titulo: 'Novo Voluntário Disponível',
                mensagem: `${App.currentUser.nome} se colocou à disposição para trabalhar no culto ${cultoNome} (${dateStr}).`,
                tipo: 'standby'
            });
            
            App.hideLoading();
            App.showToast('Candidatura de voluntário registrada com sucesso!', 'success');
            
            App.loadAndRenderMemberScales();
        } catch (err) {
            App.hideLoading();
            console.error("Error registering standby:", err);
            App.showToast('Erro ao registrar candidatura.', 'danger');
        }
    },

    async handleSendSupervisionMessage(event) {
        event.preventDefault();
        const textarea = document.getElementById('supervision-msg-text');
        if (!textarea) return;
        
        const content = textarea.value.trim();
        if (!content) {
            App.showToast('Digite uma mensagem primeiro.', 'warning');
            return;
        }
        
        try {
            App.showLoading();
            await DbService.saveSupervisionMessage(App.currentUser.id, App.currentUser.nome, content);
            
            await DbService.addNotificacao({
                paraUsuarioId: 'admin_default',
                paraUsuarioNome: 'Supervisor Geral',
                titulo: 'Nova Mensagem para a Supervisão',
                mensagem: `${App.currentUser.nome} enviou uma mensagem para a supervisão: "${content.substring(0, 50)}..."`,
                tipo: 'mensagem'
            });
            
            App.hideLoading();
            textarea.value = '';
            App.showToast('Mensagem enviada com sucesso para a supervisão!', 'success');
        } catch (err) {
            App.hideLoading();
            console.error("Error sending supervision message:", err);
            App.showToast('Erro ao enviar mensagem.', 'danger');
        }
    },

    // --- FASE 3.1 & 3.2: IA DE SUBSTITUIÇÃO (MOTOR E VISUAL) ---
    async runIntelligentSubstitutionEngineSilently(rejections, allEscalas) {
        if (!rejections || rejections.length === 0) return {};
        
        // 1. Controle de permissão operacional (apenas Admin)
        if (!this.currentUser || this.currentUser.perfil !== 'admin') {
            return {};
        }

        // 2. Controle para evitar execuções repetidas no mesmo estado de pendências
        const currentHash = rejections.map(r => r.id).sort().join('_');
        if (this._lastRejectionsHash === currentHash && this._lastIaRecommendations) {
            return this._lastIaRecommendations; // Retorna cache em memória
        }
        this._lastRejectionsHash = currentHash;

        const results = {};

        try {
            console.log(`\n[IA SUBSTITUIÇÃO] Iniciando análise para ${rejections.length} pendências...`);
            
            // 3. Reaproveitamento do cache interno do DbService
            const membros = await DbService.getMembros();
            
            // Reaproveita escalas já em memória na renderização atual
            const escalas = allEscalas || await DbService.getEscalas();
            
            const hojeStr = new Date().toISOString().split('T')[0];

            for (const pendencia of rejections) {
                console.log(`[IA SUBSTITUIÇÃO] Pendência: culto ${pendencia.cultoNome || pendencia.cultoId} / função ${pendencia.funcao}`);
                
                // --- AJUSTE 03.3: Identificar o contexto do culto ---
                const cultoAssociado = this.cultosData ? this.cultosData.find(c => c.id === pendencia.cultoId) : null;
                const modeloEscala = cultoAssociado ? (cultoAssociado.modeloEscala || 'Manter Existente') : 'Manter Existente';
                const isLivreOuTodos = (modeloEscala === 'Escala Livre' || modeloEscala === 'Culto Completo');

                // Critérios eliminatórios
                const elegiveis = membros.filter(m => {
                    if (m.statusOperacional !== 'Disponível') return false;
                    
                    // --- AJUSTE 03.3: Regra de isolamento de setores de apoio ---
                    const setoresBloqueados = ['limpeza', 'manutencao'];
                    if (setoresBloqueados.includes(m.setor) && !setoresBloqueados.includes(pendencia.setorId)) {
                        return false;
                    }
                    
                    // --- AJUSTE 03.3: Flexibilidade para Escala Livre / Culto Completo ---
                    if (!isLivreOuTodos) {
                        const noSetor = m.setor === pendencia.setorId || (m.setores && m.setores.includes(pendencia.setorId));
                        if (!noSetor) return false;
                        
                        if (m.funcaoPrincipal !== pendencia.funcao && m.funcaoSecundaria !== pendencia.funcao && m.funcao !== pendencia.funcao) return false;
                    }

                    if (m.id === pendencia.membroId) return false;
                    if (m.participaSubstituicao === 'Não' || m.participaSubstituicao === false) return false;
                    
                    const conflito = escalas.some(esc => 
                        esc.membroId === m.id && 
                        (esc.cultoId === pendencia.cultoId || (esc.data === pendencia.data && esc.horarioInicio === pendencia.horarioInicio)) &&
                        esc.statusPresenca !== 'Recusada'
                    );
                    if (conflito) return false;
                    
                    if (m.disponibilidade && m.disponibilidade.indisponibilidades) {
                        const isIndisponivel = m.disponibilidade.indisponibilidades.some(ind => {
                            return pendencia.data >= ind.inicio && pendencia.data <= ind.fim;
                        });
                        if (isIndisponivel) return false;
                    }

                    return true;
                });

                console.log(`[IA SUBSTITUIÇÃO] Candidatos elegíveis: ${elegiveis.length}`);

                if (elegiveis.length === 0) {
                    console.log(`[IA SUBSTITUIÇÃO] Nenhum candidato elegível encontrado para a pendência ${pendencia.id}\n`);
                    results[pendencia.id] = null;
                    continue;
                }

                // Critérios classificatórios
                const candidatos = elegiveis.map(m => {
                    const isFuncaoPrincipal = m.funcaoPrincipal === pendencia.funcao || m.funcao === pendencia.funcao;
                    const funcaoPontos = isFuncaoPrincipal ? 50 : 20;
                    
                    const mEscalas = escalas.filter(esc => esc.membroId === m.id);
                    const scoreObj = DbService.calcularScoreConfiabilidade(mEscalas);
                    const scoreBase = scoreObj.emAvaliacao ? 22.5 : (scoreObj.score / 100) * 30;
                    const logScoreOriginal = scoreObj.emAvaliacao ? 'em avaliação (75%)' : `${scoreObj.score}%`;
                    
                    const escalasPassadas = mEscalas.filter(esc => esc.data < hojeStr && esc.statusPresenca === 'Confirmada');
                    escalasPassadas.sort((a, b) => new Date(b.data) - new Date(a.data));
                    
                    let diasSemServir = 999;
                    if (escalasPassadas.length > 0) {
                        const lastData = new Date(escalasPassadas[0].data);
                        const hojeData = new Date(hojeStr);
                        diasSemServir = Math.ceil(Math.abs(hojeData - lastData) / (1000 * 60 * 60 * 24));
                    }
                    
                    const data30diasAtras = new Date();
                    data30diasAtras.setDate(data30diasAtras.getDate() - 30);
                    const str30DiasAtras = data30diasAtras.toISOString().split('T')[0];
                    const escalasRecentesCount = escalasPassadas.filter(esc => esc.data >= str30DiasAtras).length;
                    
                    const penalidadeRecentes = escalasRecentesCount * 10;
                    const bonusDias = Math.min(diasSemServir, 60); 
                    
                    const scoreTotal = funcaoPontos + scoreBase + bonusDias - penalidadeRecentes;

                    return {
                        membro: m,
                        scoreTotal,
                        motivo: `função ${isFuncaoPrincipal ? 'principal' : 'secundária'}, score ${logScoreOriginal}, último serviço há ${diasSemServir === 999 ? 'nunca' : diasSemServir + ' dias'}, ${escalasRecentesCount} escalas recentes`
                    };
                });

                candidatos.sort((a, b) => b.scoreTotal - a.scoreTotal);
                const recomendado = candidatos[0];
                results[pendencia.id] = {
                    membro: recomendado.membro,
                    scoreTotal: recomendado.scoreTotal,
                    motivo: recomendado.motivo,
                    alternativas: candidatos.slice(1, 4).map(c => ({
                        membro: c.membro,
                        scoreTotal: c.scoreTotal,
                        motivo: c.motivo
                    }))
                };
                
                console.log(`[IA SUBSTITUIÇÃO] Recomendado: ${recomendado.membro.nome} | alternativas: ${results[pendencia.id].alternativas.length}\n`);
            }
        } catch (e) {
            console.error('[IA SUBSTITUIÇÃO] Erro no motor lógico da IA:', e);
        }
        
        this._lastIaRecommendations = results;
        return results;
    },

    getSectorFriendlyName(sectorId) {
        return this.sectorsData[sectorId]?.nome || sectorId || 'Sem Setor';
    },

    async loadAndRenderSupervisorAlerts() {
        const container = document.getElementById('admin-supervisor-alerts-container');
        const listContainer = document.getElementById('admin-supervisor-alerts-list');
        const badgeEl = document.getElementById('admin-supervisor-alerts-badge');
        
        if (!container || !listContainer) return;
        
        try {
            const standbys = await DbService.getStandbys();
            const allEscalas = await DbService.getEscalas();
            const hojeStr = new Date().toISOString().split('T')[0];
            const limiteData = new Date();
            limiteData.setDate(limiteData.getDate() - 60);
            const limiteDateStr = limiteData.toISOString().split('T')[0];

            // Separa: rejeições de cultos passados (auto-dispensar) vs. futuras (exibir)
            const rejectionsAll = allEscalas.filter(e => {
                if (e.statusPresenca !== 'Recusada') return false;
                if (e.rejeicaoResolvida === true) return false;
                if (e.rejeicaoResolvida === undefined || e.rejeicaoResolvida === null) {
                    return e.data && e.data >= limiteDateStr;
                }
                return true;
            });

            // Auto-dispensa silenciosa de cultos já realizados (data < hoje)
            const pastRejections = rejectionsAll.filter(e => e.data < hojeStr);
            if (pastRejections.length > 0) {
                pastRejections.forEach(e => {
                    DbService.saveEscala(e.id, { rejeicaoResolvida: true }).catch(() => {});
                });
            }

            // Apenas cultos futuros ou do dia de hoje ficam no painel
            const rejections = rejectionsAll.filter(e => e.data >= hojeStr);
            
            // FASE 3.2: Chamada assíncrona não bloqueante (IA renderizada após o painel)
            const escapeHtml = (unsafe) => {
                return (unsafe || '').toString()
                     .replace(/&/g, "&amp;")
                     .replace(/</g, "&lt;")
                     .replace(/>/g, "&gt;")
                     .replace(/"/g, "&quot;")
                     .replace(/'/g, "&#039;");
            };
            
            this.runIntelligentSubstitutionEngineSilently(rejections, allEscalas).then(iaRecommendations => {
                if (!iaRecommendations) return;
                
                rejections.forEach(escala => {
                    const container = document.getElementById(`ia-container-${escala.id}`);
                    if (!container) return;
                    
                    const recommendation = iaRecommendations[escala.id];
                    if (recommendation !== undefined) {
                        if (recommendation === null) {
                            container.innerHTML = `
                                <div style="margin-top: 12px; border-top: 1px solid #e5e7eb; padding-top: 10px;">
                                    <div style="font-size: 0.75rem; color: #8b5cf6; font-weight: 700; margin-bottom: 5px; text-transform: uppercase;"><i class="fa-solid fa-robot" style="margin-right: 4px;"></i>Sugestão da IA</div>
                                    <div style="font-size: 0.8rem; color: #6b7280;">Nenhum candidato elegível encontrado.</div>
                                </div>
                            `;
                        } else {
                            const recMotivosHtml = recommendation.motivo.split(', ').map(m => `<li style="margin-bottom: 2px;">${escapeHtml(m.charAt(0).toUpperCase() + m.slice(1))}</li>`).join('');
                            
                            const score = recommendation.membro.scoreConfiabilidade;
                            let badgeText = 'Sem Classificação';
                            let badgeColor = '#6b7280';
                            if (typeof score === 'number' && score >= 0) {
                                if (score >= 80) { badgeText = 'Excelente'; badgeColor = '#10b981'; }
                                else if (score >= 60) { badgeText = 'Bom'; badgeColor = '#3b82f6'; }
                                else if (score >= 40) { badgeText = 'Regular'; badgeColor = '#f59e0b'; }
                                else { badgeText = 'Crítico'; badgeColor = '#ef4444'; }
                            }
                            
                            let alternativesHtml = '';
                            if (recommendation.alternativas && recommendation.alternativas.length > 0) {
                                alternativesHtml += `<div style="margin-top: 10px; font-size: 0.72rem; color: #4b5563; font-weight: 700; text-transform: uppercase; margin-bottom: 4px;">Alternativas Secundárias:</div><div style="display:flex; gap:6px; flex-wrap:wrap;">`;
                                recommendation.alternativas.forEach(alt => {
                                    const altScore = alt.membro.scoreConfiabilidade;
                                    let altBadge = '';
                                    if (typeof altScore === 'number' && altScore >= 0) {
                                        altBadge = `(${altScore}%)`;
                                    }
                                    alternativesHtml += `
                                        <button class="btn-secondary btn-ia-alt" style="padding: 4px 8px; font-size: 0.7rem; width: auto; border: 1px solid #d1d5db; background: #f9fafb; display: flex; align-items: center; gap: 4px;" data-escala-id="${escala.id}" data-membro-id="${alt.membro.id}" data-membro-nome="${escapeHtml(alt.membro.nome)}">
                                            <i class="fa-solid fa-user-plus"></i> ${escapeHtml(alt.membro.nome)} ${altBadge}
                                        </button>
                                    `;
                                });
                                alternativesHtml += `</div>`;
                            }

                            container.innerHTML = `
                                <div style="margin-top: 12px; border-top: 1px solid #e5e7eb; padding-top: 10px;">
                                    <div style="font-size: 0.75rem; color: #8b5cf6; font-weight: 700; margin-bottom: 5px; text-transform: uppercase;"><i class="fa-solid fa-robot" style="margin-right: 4px;"></i>Sugestão da IA</div>
                                    <div style="display: flex; align-items: center; gap: 6px; margin-bottom: 4px;">
                                        <span style="font-size: 0.85rem; color: var(--navy-dark); font-weight: 700;">${escapeHtml(recommendation.membro.nome)}</span>
                                        <span style="font-size: 0.7rem; color: ${badgeColor}; font-weight: 700; padding: 2px 6px; border-radius: 4px; background: rgba(0,0,0,0.03); border: 1px solid rgba(0,0,0,0.05);">${badgeText}</span>
                                    </div>
                                    <ul style="margin: 0; padding-left: 18px; font-size: 0.78rem; color: #4b5563;">${recMotivosHtml}</ul>
                                    <button class="btn-primary btn-ia-direct" style="margin-top: 8px; font-size: 0.78rem; padding: 6px 12px; background-color: #8b5cf6; border: none; display: flex; align-items: center; gap: 4px; height: 32px; width: auto;" data-escala-id="${escala.id}" data-membro-id="${recommendation.membro.id}" data-membro-nome="${escapeHtml(recommendation.membro.nome)}">
                                        <i class="fa-solid fa-bolt"></i> Substituir por ${escapeHtml(recommendation.membro.nome)}
                                    </button>
                                    ${alternativesHtml}
                                </div>
                            `;
                        }
                    }
                });
            }).catch(e => console.error('[IA SUBSTITUIÇÃO]', e));

            const messages = await DbService.getSupervisionMessages();
            
            const totalAlerts = standbys.length + rejections.length + messages.length;
            
            if (badgeEl) badgeEl.innerText = totalAlerts;
            
            if (totalAlerts === 0) {
                container.style.display = 'none';
                listContainer.innerHTML = '';
                return;
            }
            
            container.style.display = 'block';
            listContainer.innerHTML = '';

            // Adicionar Listener Delegado para os botões de substituição com IA
            if (!listContainer.dataset.listenerAdded) {
                listContainer.addEventListener('click', (e) => {
                    const btn = e.target.closest('.btn-ia-direct, .btn-ia-alt');
                    if (btn) {
                        const escalaId = btn.getAttribute('data-escala-id');
                        const membroId = btn.getAttribute('data-membro-id');
                        const membroNome = btn.getAttribute('data-membro-nome');
                        if (escalaId && membroId && membroNome) {
                            App.applyDirectSubstitution(escalaId, membroId, membroNome);
                        }
                    }
                });
                listContainer.dataset.listenerAdded = 'true';
            }
            
            // Render Rejections
            rejections.forEach(escala => {
                const item = document.createElement('div');
                item.className = 'alert-item';
                item.id = `alert-rejection-${escala.id}`;
                item.style.cssText = 'background: #fff; border-left: 4px solid #ef4444; border-radius: 8px; padding: 12px; display: flex; align-items: center; justify-content: space-between; gap: 15px; box-shadow: 0 1px 3px rgba(0,0,0,0.05);';
                
                const dateParts = escala.data.split('-');
                const formattedDate = `${dateParts[2]}/${dateParts[1]}/${dateParts[0]}`;
                const isFutureCulto = escala.data >= hojeStr;
                
                // Botão "Escalar Substitutos" só disponível para cultos ainda não realizados
                const escalarBtn = isFutureCulto
                    ? `<button class="btn-primary" style="padding: 6px 12px; font-size: 0.78rem; width: auto; background: var(--teal-primary);" onclick="App.handleReplaceRejection('${escala.cultoId}', '${escala.id}')">
                            <i class="fa-solid fa-user-pen"></i> Escalar Substituto
                       </button>`
                    : `<span style="font-size: 0.75rem; color: #6b7280; font-style: italic; padding: 4px 8px; background: #f3f4f6; border-radius: 6px;"><i class="fa-solid fa-clock-rotate-left" style="margin-right:4px;"></i>Culto realizado — substituição automática já foi processada</span>`;

                item.innerHTML = `
                    <div style="flex: 1; text-align: left;">
                        <span style="font-weight: 700; color: #dc2626; font-size: 0.8rem; text-transform: uppercase; display: block; margin-bottom: 2px;"><i class="fa-solid fa-triangle-exclamation"></i> Presença Recusada</span>
                        <span style="font-size: 0.88rem; color: var(--navy-dark); font-weight: 600;">${escala.membroNome}</span> recusou a escala para <span style="font-weight: 600;">${escala.cultoNome}</span> (${formattedDate} das ${escala.horarioInicio} às ${escala.horarioFim}) no setor <span style="font-weight: 600;">${App.getSectorFriendlyName(escala.setorId)}</span> (Função: ${escala.funcao}).
                        <div id="ia-container-${escala.id}"></div>
                    </div>
                    <div style="display: flex; gap: 8px; flex-wrap: wrap; align-items: center; margin-top: 10px;">
                        ${escalarBtn}
                        <button class="btn-secondary" style="padding: 6px 12px; font-size: 0.78rem; width: auto;" onclick="App.handleDismissRejection('${escala.id}')">
                            <i class="fa-solid fa-check"></i> Dispensar Alerta
                        </button>
                    </div>
                `;
                listContainer.appendChild(item);
            });
            
            // Render Standbys
            standbys.forEach(s => {
                const item = document.createElement('div');
                item.className = 'alert-item';
                item.id = `alert-standby-${s.id}`;
                item.style.cssText = 'background: #fff; border-left: 4px solid #10b981; border-radius: 8px; padding: 12px; display: flex; align-items: center; justify-content: space-between; gap: 15px; box-shadow: 0 1px 3px rgba(0,0,0,0.05);';
                
                const dateParts = s.dataCulto.split('-');
                const formattedDate = `${dateParts[2]}/${dateParts[1]}/${dateParts[0]}`;
                
                item.innerHTML = `
                    <div style="flex: 1; text-align: left;">
                        <span style="font-weight: 700; color: #059669; font-size: 0.8rem; text-transform: uppercase; display: block; margin-bottom: 2px;"><i class="fa-solid fa-hand-holding-hand"></i> Obreiro Disponível (Voluntário)</span>
                        <span style="font-size: 0.88rem; color: var(--navy-dark); font-weight: 600;">${s.membroNome}</span> se voluntariou para o culto <span style="font-weight: 600;">${s.cultoNome}</span> (${formattedDate} - ${s.horario}) no setor <span style="font-weight: 600;">${App.getSectorFriendlyName(s.setorId)}</span>${s.funcao ? ` (Pref. Função: ${s.funcao})` : ''}.
                    </div>
                    <div style="display: flex; gap: 8px; flex-wrap: wrap;">
                        <button class="btn-primary" style="padding: 6px 12px; font-size: 0.78rem; width: auto; background: var(--teal-primary);" onclick="App.handleEscalarStandby('${s.cultoId}', '${s.membroId}', '${s.membroNome.replace(/'/g, "\\'")}', '${s.setorId}', '${(s.funcao || '').replace(/'/g, "\\'")}', '${s.id}')">
                            <i class="fa-solid fa-plus"></i> Escalar Obreiro
                        </button>
                        <button class="btn-secondary" style="padding: 6px 12px; font-size: 0.78rem; width: auto;" onclick="App.handleDismissStandby('${s.id}')">
                            <i class="fa-solid fa-check"></i> Dispensar Alerta
                        </button>
                    </div>
                `;
                listContainer.appendChild(item);
            });
            
            // Render Messages
            messages.forEach(msg => {
                const item = document.createElement('div');
                item.className = 'alert-item';
                item.id = `alert-message-${msg.id}`;
                item.style.cssText = 'background: #fff; border-left: 4px solid #3b82f6; border-radius: 8px; padding: 12px; display: flex; align-items: center; justify-content: space-between; gap: 15px; box-shadow: 0 1px 3px rgba(0,0,0,0.05);';
                
                const timeStr = msg.criadoEm ? msg.criadoEm.toLocaleDateString('pt-BR') + ' às ' + msg.criadoEm.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' }) : '';
                
                item.innerHTML = `
                    <div style="flex: 1; text-align: left;">
                        <span style="font-weight: 700; color: #2563eb; font-size: 0.8rem; text-transform: uppercase; display: block; margin-bottom: 2px;"><i class="fa-solid fa-comment"></i> Mensagem para Supervisão</span>
                        <div style="font-size: 0.88rem; color: var(--navy-dark);"><span style="font-weight: 700;">${msg.membroNome}</span>: "${msg.conteudo}"</div>
                        <span style="font-size: 0.7rem; color: var(--slate-gray); display: block; margin-top: 4px;">Enviado em ${timeStr}</span>
                    </div>
                    <div style="display: flex; gap: 8px;">
                        <button class="btn-primary" style="padding: 6px 12px; font-size: 0.78rem; width: auto; background: #3b82f6;" onclick="App.handleMarkMessageRead('${msg.id}')">
                            <i class="fa-solid fa-box-archive"></i> Arquivar
                        </button>
                    </div>
                `;
                listContainer.appendChild(item);
            });
        } catch (e) {
            console.error("Error loading supervisor alerts:", e);
        }
    },

    removeAlertFromDOM(alertId) {
        const element = document.getElementById(alertId);
        if (element) {
            element.remove();
        }
        
        const badgeEl = document.getElementById('admin-supervisor-alerts-badge');
        if (badgeEl) {
            const currentCount = parseInt(badgeEl.innerText) || 0;
            const newCount = Math.max(0, currentCount - 1);
            badgeEl.innerText = newCount;
            if (newCount === 0) {
                const container = document.getElementById('admin-supervisor-alerts-container');
                if (container) container.style.display = 'none';
            }
        }
    },

    handleReplaceRejection(cultoId, escalaId) {
        // Pre-select the culto so loadAdminEscalas will auto-navigate to it
        this.adminSelectedCultoId = cultoId;
        this.adminActiveTab = 'escalas';

        // Navigate to the admin view (renders the escalas tab with the correct culto)
        const views = document.querySelectorAll('.view-section');
        views.forEach(v => v.style.display = 'none');
        const adminView = document.getElementById('view-admin');
        if (adminView) adminView.style.display = 'block';

        // Apply correct menu highlight
        document.querySelectorAll('.admin-menu-item').forEach(item => item.classList.remove('active'));
        const escalasMenuItem = Array.from(document.querySelectorAll('.admin-menu-item')).find(item =>
            item.textContent.toLowerCase().includes('escala')
        );
        if (escalasMenuItem) escalasMenuItem.classList.add('active');

        this.loadAndRenderAdminPortal();
        App.showToast('Substitua o obreiro que recusou na escala.', 'info');
    },

    async handleDismissRejection(escalaId) {
        // Optimistically remove from DOM immediately
        this.removeAlertFromDOM(`alert-rejection-${escalaId}`);
        try {
            await DbService.saveEscala(escalaId, { rejeicaoResolvida: true });
            App.showToast('Alerta de recusa dispensado.', 'success');
        } catch (err) {
            console.error("Error dismissing rejection:", err);
            App.showToast('Erro ao dispensar alerta no servidor.', 'danger');
            // Restore original UI state if database write failed
            await App.loadAndRenderSupervisorAlerts();
        }
    },

    async handleDismissStandby(standbyId) {
        // Optimistically remove from DOM immediately
        this.removeAlertFromDOM(`alert-standby-${standbyId}`);
        try {
            await DbService.deleteStandby(standbyId);
            App.showToast('Alerta de voluntário dispensado.', 'success');
        } catch (err) {
            console.error("Error dismissing standby:", err);
            App.showToast('Erro ao dispensar voluntário no servidor.', 'danger');
            // Restore original UI state if database write failed
            await App.loadAndRenderSupervisorAlerts();
        }
    },

    async handleMarkMessageRead(msgId) {
        // Optimistically remove from DOM immediately
        this.removeAlertFromDOM(`alert-message-${msgId}`);
        try {
            await DbService.marcarMensagemComoLida(msgId);
            App.showToast('Mensagem marcada como lida.', 'success');
        } catch (err) {
            console.error("Error marking message as read:", err);
            App.showToast('Erro ao marcar mensagem no servidor.', 'danger');
            // Restore original UI state if database write failed
            await App.loadAndRenderSupervisorAlerts();
        }
    },

    async handleEscalarStandby(cultoId, membroId, membroNome, sectorId, funcao, standbyId) {
        App.adminSelectedCultoId = cultoId;
        const c = App.cultosData.find(item => item.id === cultoId);
        if (!c) {
            App.showToast('Culto não encontrado.', 'danger');
            return;
        }
        
        document.getElementById('escala-modal-title').innerText = `Escalar ${membroNome}`;
        document.getElementById('escala-form-id').value = '';
        document.getElementById('escala-form').reset();
        
        document.getElementById('escala-cultoid').value = cultoId;
        document.getElementById('escala-data').value = c.data;
        document.getElementById('escala-horainicio').value = c.horarioInicio;
        document.getElementById('escala-horafim').value = c.horarioFim;
        
        document.getElementById('escala-setor').value = sectorId;
        
        await App.handleEscalaSetorChange(sectorId, membroId);
        
        const fSelect = document.getElementById('escala-funcao');
        let matchedFuncao = '';
        const searchFun = (funcao || '').trim().toLowerCase();
        
        for (let option of fSelect.options) {
            if (!option.value) continue;
            const optVal = option.value.toLowerCase();
            if (searchFun && (optVal.includes(searchFun) || searchFun.includes(optVal))) {
                matchedFuncao = option.value;
                break;
            }
        }
        
        // Se nao encontrou match ou veio vazio/Voluntario genérico, tenta pegar a primeira opção válida
        if (!matchedFuncao) {
            for (let option of fSelect.options) {
                if (option.value !== "") {
                    matchedFuncao = option.value;
                    break;
                }
            }
        }
        
        if (matchedFuncao) {
            fSelect.value = matchedFuncao;
        }
        
        await App.adjustEscalaFormFields();
        
        const mSelect = document.getElementById('escala-membro');
        mSelect.value = membroId;
        
        document.getElementById('modal-escala-form').classList.add('active');
        
        App.pendingStandbyIdToResolve = standbyId;
    },

    async loadAdminAvisos() {
        const container = document.getElementById('admin-avisos-list');
        if (!container) return;
        container.innerHTML = '<div style="text-align: center; padding: 20px;"><i class="fa-solid fa-circle-notch fa-spin" style="font-size: 1.2rem; color: var(--teal-primary);"></i><p style="margin-top:8px; font-size:0.8rem; color:var(--slate-gray);">Buscando informativos...</p></div>';

        // Load Mural Configuration
        App.loadMuralConfigAdmin();

        try {
            const avisos = await DbService.getAvisos();
            if (avisos.length === 0) {
                container.innerHTML = '<div style="text-align: center; padding: 20px; color: var(--slate-gray); font-size: 0.88rem;">Nenhum informativo publicado ainda.</div>';
                return;
            }

            container.innerHTML = '';
            avisos.forEach(a => {
                const item = document.createElement('div');
                item.style.cssText = `
                    border: 1px solid #E2E8F0;
                    border-radius: 12px;
                    padding: 14px 16px;
                    display: flex;
                    justify-content: space-between;
                    align-items: flex-start;
                    gap: 15px;
                    background: #FFFFFF;
                    box-shadow: 0 1px 3px rgba(0,0,0,0.04);
                `;
                const dateObj = a.data && typeof a.data.toDate === 'function' ? a.data.toDate() : new Date(a.data);
                const dt = a.data ? dateObj.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '';
                const expStr = a.dataExpiracao ? ` · Expira em: ${a.dataExpiracao.split('-').reverse().join('/')}` : '';
                item.innerHTML = `
                    <div style="flex: 1; text-align: left; min-width: 0;">
                        <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 6px; flex-wrap: wrap; gap: 4px;">
                            <span style="font-size: 0.72rem; font-weight: 700; color: var(--teal-primary);"><i class="fa-solid fa-user-tie"></i> ${a.autorNome || 'Supervisor Geral'}</span>
                            <span style="font-size: 0.7rem; color: #64748B;">${dt}${expStr}</span>
                        </div>
                        <h5 style="font-size: 0.9rem; font-weight: 700; color: #1E293B; margin: 0 0 5px 0;">${a.titulo}</h5>
                        <p style="font-size: 0.83rem; color: #374151; margin: 0; line-height: 1.5; white-space: pre-wrap;">${a.conteudo}</p>
                    </div>
                    <button class="btn-icon" style="color: #ef4444; background: rgba(239, 68, 68, 0.08); border-radius: 8px; width: 32px; height: 32px; flex-shrink: 0; border: none; cursor: pointer;" onclick="if(confirm('Excluir este informativo?')) App.handleDeleteAvisoAdmin('${a.id}')" title="Excluir Informativo">
                        <i class="fa-solid fa-trash"></i>
                    </button>
                `;
                container.appendChild(item);
            });
        } catch (err) {
            console.error("Error loading admin notices:", err);
            container.innerHTML = '<div style="color:red; text-align:center; padding: 20px;">Erro ao carregar informativos.</div>';
        }
    },

    async handleSaveAvisoAdmin(event) {
        event.preventDefault();
        const titleInput = document.getElementById('aviso-titulo');
        const contentInput = document.getElementById('aviso-conteudo');
        const expInput = document.getElementById('aviso-expiracao');
        if (!titleInput || !contentInput) return;

        const titulo = titleInput.value.trim();
        const conteudo = contentInput.value.trim();
        const dataExpiracao = expInput ? expInput.value : '';

        if (!titulo || !conteudo) {
            App.showToast('Por favor, preencha todos os campos.', 'warning');
            return;
        }

        try {
            App.showLoading();
            const payload = {
                titulo,
                conteudo,
                autorNome: App.currentUser ? App.currentUser.nome : 'Supervisor Geral'
            };
            if (dataExpiracao) {
                payload.dataExpiracao = dataExpiracao;
            }
            await DbService.saveAviso(payload);
            App.hideLoading();
            App.showToast('Informativo publicado com sucesso!', 'success');
            
            titleInput.value = '';
            contentInput.value = '';
            if (expInput) expInput.value = '';
            
            await App.loadAdminAvisos();
        } catch (err) {
            App.hideLoading();
            console.error("Error publishing notice:", err);
            App.showToast('Erro ao publicar informativo.', 'danger');
        }
    },

    async handleDeleteAvisoAdmin(id) {
        if (!confirm('Deseja realmente excluir este informativo? Todos os obreiros deixarão de vê-lo.')) return;

        try {
            App.showLoading();
            await DbService.deleteAviso(id);
            App.hideLoading();
            App.showToast('Informativo excluído com sucesso!', 'success');
            await App.loadAdminAvisos();
        } catch (err) {
            App.hideLoading();
            console.error("Error deleting notice:", err);
            App.showToast('Erro ao excluir informativo.', 'danger');
        }
    },

    async loadAdminMessages() {
        const showArchived = document.getElementById('admin-msg-show-archived')?.checked || false;
        const container = document.getElementById('admin-messages-list-container');
        if (!container) return;
        container.innerHTML = '<div style="text-align:center;padding:20px;"><i class="fa-solid fa-circle-notch fa-spin"></i></div>';
        try {
            const membros = await DbService.getMembros();
            const allMessages = [];
            for (const m of membros) {
                if (m.mensagens && Array.isArray(m.mensagens)) {
                    m.mensagens.forEach(msg => allMessages.push({ ...msg, autorNome: m.nome }));
                }
            }
            const filtered = showArchived ? allMessages : allMessages.filter(msg => !msg.arquivado);
            filtered.sort((a, b) => (b.data?.seconds || 0) - (a.data?.seconds || 0));
            if (filtered.length === 0) {
                container.innerHTML = '<p style="text-align:center;color:var(--slate-gray);padding:20px;">Nenhuma mensagem encontrada.</p>';
                return;
            }
            container.innerHTML = filtered.map(msg => {
                const dateObj = msg.data && typeof msg.data.toDate === 'function' ? msg.data.toDate() : new Date(msg.data);
                const dt = msg.data ? dateObj.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '';
                return `<div style="border:1px solid #E2E8F0;border-radius:10px;padding:12px 15px;background:#FAF8F6;">
                    <div style="display:flex;justify-content:space-between;margin-bottom:4px;">
                        <span style="font-size:0.8rem;font-weight:700;color:var(--teal-primary);">${msg.autorNome || 'Obreiro'}</span>
                        <span style="font-size:0.75rem;color:var(--slate-gray);">${dt}</span>
                    </div>
                    <p style="margin:0;font-size:0.88rem;color:var(--navy-dark);">${msg.texto || msg.conteudo || ''}</p>
                </div>`;
            }).join('');
        } catch (err) {
            console.error('[loadAdminMessages] Erro:', err);
            container.innerHTML = '<p style="text-align:center;color:red;padding:20px;">Erro ao carregar mensagens.</p>';
        }
    },

    // --- MURAL INFORMATIVO FUNCTIONS (v3.4.9) ---
    async loadAndRenderSectorSelectMural(escalas, avisos) {
        let carouselItems = [];

        // 1. Announcements (Avisos / Comunicados) - Priority 1
        if (avisos && avisos.length > 0) {
            // Filter out only auto-generated scale announcements (not legitimate notices)
            const filteredAvisos = avisos.filter(a => {
                const contentLower = (a.texto || a.conteudo || '').toLowerCase();
                // Ignorar apenas publicações automáticas de escala (identificadas pelo conteúdo)
                if (contentLower.includes('escala de voluntário') || contentLower.includes('escala de voluntario') || contentLower.includes('confirme sua presença')) {
                    return false;
                }
                return true;
            });
            const topAvisos = filteredAvisos.slice(0, 3);
            topAvisos.forEach(a => {
                let dateObj = null;
                if (a.data) {
                    dateObj = typeof a.data.toDate === 'function' ? a.data.toDate() : new Date(a.data);
                    const today = new Date();
                    const diffTime = Math.abs(today - dateObj);
                    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24)); 
                    if (diffDays > 3) {
                        return; // Pula avisos mais velhos que 3 dias
                    }
                }
                const dateStr = dateObj ? dateObj.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '';
                carouselItems.push({
                    type: 'warning',
                    category: '📢 COMUNICADO',
                    title: a.titulo,
                    subtitle: 'Aviso Geral',
                    description: a.texto || a.conteudo || 'Toque para ver mais detalhes.',
                    date: dateStr,
                    action: 'App.showMuralAvisosDetail()'
                });
            });
            this.cachedAvisosList = avisos;
        } else {
            this.cachedAvisosList = [];
        }

        // 2. Pedidos de Oração (Prayer Requests) - Priority 2
        let prayers = JSON.parse(localStorage.getItem('diaconia_pedidos_oracao') || '[]');
        // Limpar mock legado se ainda existir no dispositivo do usuario
        const originalLength = prayers.length;
        prayers = prayers.filter(p => p.obreiro !== 'Supervisor André' && p.obreiro !== 'Diác. Lucas');
        if (prayers.length !== originalLength) {
            localStorage.setItem('diaconia_pedidos_oracao', JSON.stringify(prayers));
        }
        const activePrayers = prayers.filter(p => p.ativo);
        activePrayers.forEach(p => {
            carouselItems.push({
                type: 'prayer',
                category: '🙏 PEDIDO DE ORAÇÃO',
                title: p.obreiro,
                subtitle: 'Pedido de Intercessão',
                description: p.motivo,
                date: p.data,
                action: 'App.openPrayersModal()'
            });
        });

        // Update Prayers Card UI
        const prayersBadge = document.getElementById('smart-card-prayers-count');
        if (prayersBadge) {
            prayersBadge.innerText = activePrayers.length;
        }

        // 3. Birthdays (Aniversários) - Priority 3
        let birthdaysCount = 0;
        try {
            const members = await DbService.getMembros();
            const today = new Date();
            const currentMonth = today.getMonth(); // 0 to 11
            
            const birthdayMembers = members.filter(m => {
                if (m.status !== 'ativo') return false;
                if (!m.dataNascimento || m.dataNascimento === 'N/A') return false;
                const parts = m.dataNascimento.split('-');
                if (parts.length < 3) return false;
                const mMonth = parseInt(parts[1], 10) - 1;
                return mMonth === currentMonth;
            });
            birthdayMembers.sort((a, b) => this.getMemberBirthDayLocal(a) - this.getMemberBirthDayLocal(b));
            birthdaysCount = birthdayMembers.length;

            if (birthdayMembers.length > 0) {
                birthdayMembers.forEach(m => {
                    const parts = m.dataNascimento.split('-');
                    const day = parts[2];
                    const month = parts[1];
                    carouselItems.push({
                        type: 'birthday',
                        category: '🎂 ANIVERSARIANTE',
                        title: m.nome,
                        subtitle: 'Aniversariante do Mês',
                        description: 'Que tal enviar uma mensagem de parabéns e celebrar a vida deste obreiro?',
                        date: `${day}/${month}`,
                        action: 'App.showMuralBirthdaysDetail()'
                    });
                });
                this.cachedBirthdayMembers = birthdayMembers;
            } else {
                this.cachedBirthdayMembers = [];
            }
        } catch (e) { console.error("Error loading birthdays:", e); }

        // Update Birthday Card UI
        const birthdaysBadge = document.getElementById('smart-card-birthdays-count');
        if (birthdaysBadge) {
            birthdaysBadge.innerText = birthdaysCount;
        }

        // 4. Ausências da Semana (Away Members) - Priority 4
        let awayCount = 0;
        try {
            const members = await DbService.getMembros();
            const hojeStr = new Date().toISOString().split('T')[0];
            const away = members.filter(m => {
                if (m.status !== 'ativo') return false;
                if (!m.statusOperacional || m.statusOperacional === 'Disponível') return false;
                if (m.afastamentoInicio && m.afastamentoFim) {
                    return hojeStr >= m.afastamentoInicio && hojeStr <= m.afastamentoFim;
                }
                return true;
            });
            awayCount = away.length;

            if (away.length > 0) {
                const isOp = this.isOperationalSector(this.activeSectorId);
                const lSingular = isOp ? 'Voluntário' : 'Obreiro';
                const lPlural = isOp ? 'Voluntários' : 'Obreiros';
                carouselItems.push({
                    type: 'away',
                    category: '👥 AUSÊNCIAS DA SEMANA',
                    title: `${away.length} ${lSingular}(s) Ausente(s)`,
                    subtitle: 'Ausências da Semana',
                    description: `${lPlural} temporariamente indisponíveis: ${away.map(m => m.nome).join(', ')}`,
                    date: 'Esta semana',
                    action: 'App.showMuralAwayDetail()'
                });
            }
        } catch(e) { console.error("Error loading away members:", e); }

        // Update Away Card UI
        const awayBadge = document.getElementById('smart-card-away-count');
        if (awayBadge) {
            awayBadge.innerText = awayCount;
        }

        // Add dynamic system items
        const dynamicItems = this.getDynamicMuralItems(escalas);
        carouselItems.unshift(...dynamicItems);

        // Fallback slide
        if (carouselItems.length === 0) {
            carouselItems.push({
                type: 'default',
                category: 'MURAL',
                title: 'Tudo em dia!',
                subtitle: 'Sem novos avisos',
                description: 'Nenhum comunicado disponível no momento.',
                date: 'Hoje',
                action: ''
            });
        }

        this.initPremiumCarousel(carouselItems);
    },

    getDynamicMuralItems(escalas) {
        const dynamicItems = [];
        const now = new Date();
        const hojeStr = this.formatLocalISOString(now).split('T')[0];
        const dayOfWeek = now.getDay();
        const currentHour = now.getHours();
        const currentMinute = now.getMinutes();
        const currentTotalMinutes = currentHour * 60 + currentMinute;
        
        const myScalesToday = escalas.filter(e => e.membroId === this.currentUser.id && e.data === hojeStr && e.statusServico !== 'Finalizado' && e.statusPresenca !== 'Recusada');
        const isScheduledToday = myScalesToday.length > 0;
        
        let hasCultoToday = false;
        let activeUserCultos = [];
        
        if (isScheduledToday) {
            myScalesToday.forEach(s => {
                if (s.cultoId) {
                    const c = this.cultosData.find(culto => culto.id === s.cultoId);
                    if (c && c.status !== 'Finalizado') {
                        activeUserCultos.push(c);
                        hasCultoToday = true;
                    }
                }
            });
        }

        // 1. User Area Checklist (Only if Scheduled)
        if (isScheduledToday) {
            const mySectors = [...new Set(myScalesToday.map(e => e.setorId))];
            const myFuncs = myScalesToday.map(e => (e.funcao || '').toLowerCase());
            
            const hasPortaria = mySectors.includes('entrada') || myFuncs.some(f => f.includes('portaria') || f.includes('entrada'));
            const hasCheckin = mySectors.includes('check_in') || myFuncs.some(f => f.includes('check'));
            
            const hasTemplo = mySectors.includes('apoio_templo_ronda_dir') || mySectors.includes('apoio_templo_ronda_esq') || myFuncs.some(f => f.includes('apoio') || f.includes('templo'));
            const hasRonda = mySectors.includes('apoio_templo_ronda_dir') || mySectors.includes('apoio_templo_ronda_esq') || myFuncs.some(f => f.includes('ronda'));

            if (hasPortaria) {
                dynamicItems.push({
                    type: 'system',
                    category: '📋 SUA ÁREA',
                    title: 'Checklist: Portaria',
                    subtitle: 'Suas responsabilidades de hoje',
                    description: 'Toque para ver a lista completa de atribuições e o que nunca fazer na Portaria.',
                    date: 'Sua Escala',
                    action: "App.showChecklistDetail('portaria')"
                });
            }

            if (hasCheckin) {
                dynamicItems.push({
                    type: 'system',
                    category: '📋 SUA ÁREA',
                    title: 'Checklist: Check-in',
                    subtitle: 'Suas responsabilidades de hoje',
                    description: 'Toque para ver a lista completa de responsabilidades do Check-in.',
                    date: 'Sua Escala',
                    action: "App.showChecklistDetail('checkin')"
                });
            }

            if (hasTemplo && hasRonda) {
                dynamicItems.push({
                    type: 'system',
                    category: '📋 SUA ÁREA',
                    title: 'Checklist: Templo & Ronda',
                    subtitle: 'Suas responsabilidades de hoje',
                    description: 'Toque para ver a lista completa de atribuições de Templo e Ronda.',
                    date: 'Sua Escala',
                    action: "App.showChecklistDetail('templo_ronda')"
                });
            } else {
                if (hasTemplo) {
                    dynamicItems.push({
                        type: 'system',
                        category: '📋 SUA ÁREA',
                        title: 'Checklist: Templo',
                        subtitle: 'Suas responsabilidades de hoje',
                        description: 'Toque para ver a lista completa de atribuições do Templo.',
                        date: 'Sua Escala',
                        action: "App.showChecklistDetail('templo')"
                    });
                }
                if (hasRonda) {
                    dynamicItems.push({
                        type: 'system',
                        category: '📋 SUA ÁREA',
                        title: 'Checklist: Ronda',
                        subtitle: 'Suas responsabilidades de hoje',
                        description: 'Toque para ver a lista completa de atribuições da Ronda.',
                        date: 'Sua Escala',
                        action: "App.showChecklistDetail('ronda')"
                    });
                }
            }
        }

        // 2. Welcome Message (45 mins before Culto) & 3. Encerramento (10 mins before end)
        if (hasCultoToday) {
            activeUserCultos.forEach(c => {
                const [sH, sM] = (c.horarioInicio || '00:00').split(':').map(Number);
                const cultoStartMinutes = sH * 60 + sM;
                const [eH, eM] = (c.horarioFim || '23:59').split(':').map(Number);
                const cultoEndMinutes = eH * 60 + eM;
                
                const timeUntilStart = cultoStartMinutes - currentTotalMinutes;
                if (timeUntilStart > 0 && timeUntilStart <= 45) {
                    dynamicItems.push({
                        type: 'system',
                        category: '👋 BEM VINDO',
                        title: 'Bem vindo ao Serviço Diaconal',
                        subtitle: 'Preparação para o Culto das ' + c.horarioInicio,
                        description: 'Não esqueça de orar com seus companheiros de trabalho, e organizar seu setor de trabalho antes do culto começar.',
                        date: 'Agora',
                        action: ''
                    });
                }
                
                const timeUntilEnd = cultoEndMinutes - currentTotalMinutes;
                if (timeUntilEnd > 0 && timeUntilEnd <= 10) {
                    dynamicItems.push({
                        type: 'system',
                        category: '🔚 ENCERRAMENTO',
                        title: 'Encerramento do Culto das ' + c.horarioInicio,
                        subtitle: 'Procedimentos Finais',
                        description: 'Antes de ir embora: Verificar templo, banheiros, salas, estacionamento, recolher objetos perdidos, ajudar na saída dos membros e fazer oração final com a equipe.',
                        date: 'Agora',
                        action: ''
                    });
                }
            });
        }

        // 4. Atendimento em Emergências (Culto Days)
        if (hasCultoToday) {
            dynamicItems.push({
                type: 'system',
                category: '🚨 EMERGÊNCIAS',
                title: 'Atendimento em Emergências',
                subtitle: 'Diretrizes de Segurança',
                description: 'Caso alguém passe mal: Manter calma, Chamar líder, Acionar equipe médica, Liberar espaço, Não gerar tumulto. Incêndio: Comunicar liderança, Auxiliar evacuação, Não correr.',
                date: 'Dia de Culto',
                action: ''
            });
        }

        // 5. Atendimento ao Público (Saturday and Sunday)
        if (dayOfWeek === 0 || dayOfWeek === 6) {
            dynamicItems.push({
                type: 'system',
                category: '🤝 ATENDIMENTO',
                title: 'Atendimento ao Público',
                subtitle: 'Excelência e Simpatia',
                description: 'Sempre sorria, seja educado, ouça antes de responder. Evite frases como "Não sei", prefira "Vou verificar para o senhor". Resolva ou encaminhe.',
                date: 'Fim de Semana',
                action: ''
            });
        }

        // 6. Quarta-feira Pledge
        if (dayOfWeek === 3) {
            dynamicItems.push({
                type: 'system',
                category: '📖 COMPROMISSO',
                title: 'Nosso Chamado',
                subtitle: 'Compromisso Diaconal',
                description: '"Comprometo-me a servir ao Senhor e à Sua Igreja com amor, fidelidade, integridade e excelência, honrando meu chamado e servindo ao próximo com dedicação."',
                date: 'Hoje',
                action: ''
            });
        }

        return dynamicItems;
    },

    // --- PREMIUM CAROUSEL LOGIC ---
    initPremiumCarousel(items) {
        this.carouselItems = items;
        this.carouselIndex = 0;
        this.renderCarousel();
        this.startCarouselAutoPlay();

        // Add touch/swipe support
        const track = document.getElementById('mural-carousel-track');
        if (track && !this.carouselTouchInit) {
            this.carouselTouchInit = true;
            let touchStartX = 0;
            track.addEventListener('touchstart', e => { touchStartX = e.changedTouches[0].screenX; }, {passive: true});
            track.addEventListener('touchend', e => {
                let touchEndX = e.changedTouches[0].screenX;
                if (touchStartX - touchEndX > 50) this.carouselNext(); // Swipe left
                if (touchEndX - touchStartX > 50) this.carouselPrev(); // Swipe right
            }, {passive: true});
        }
    },

    renderCarousel() {
        const track = document.getElementById('mural-carousel-track');
        const dotsContainer = document.getElementById('mural-carousel-dots');
        if (!track || !dotsContainer) return;

        track.innerHTML = '';
        dotsContainer.innerHTML = '';

        this.carouselItems.forEach((item, index) => {
            track.innerHTML += `
                <div class="carousel-slide premium-dark-slide" onclick="App.handleCarouselInteraction(); ${item.action}">
                    <div class="slide-content-dark" style="height: 100%; display: flex; flex-direction: column; justify-content: space-between;">
                        <div>
                            <span class="slide-tag-dark" style="font-size: 0.8rem; font-weight: 800; text-transform: uppercase; color: var(--teal-primary, #0F766E); letter-spacing: 1.5px; display: block; margin-bottom: 6px;">${item.category}</span>
                            <h4 class="slide-title-dark" style="margin-bottom: 6px; font-size: 1.25rem; line-height: 1.25;">${item.title}</h4>
                            <span class="slide-subtitle-dark" style="display: block; margin-bottom: 8px; font-size: 0.95rem; color: #64748B;">${item.subtitle}</span>
                            <p class="slide-desc-dark" style="margin-bottom: 8px; font-size: 0.95rem; color: #475569; display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden;">${item.description}</p>
                        </div>
                        <div style="display: flex; justify-content: space-between; align-items: center; border-top: 1px solid #E2E8F0; padding-top: 10px; margin-top: auto;">
                            <span style="font-size: 0.85rem; color: #94A3B8; font-weight: 600;">${item.date}</span>
                            <span class="slide-action-link" style="margin-top: 0; font-size: 0.9rem; font-weight: 700; color: var(--teal-primary, #0F766E);">Ler mais →</span>
                        </div>
                    </div>
                </div>
            `;
            
            dotsContainer.innerHTML += `
                <div class="carousel-dot ${index === 0 ? 'active' : ''}" onclick="event.stopPropagation(); App.carouselGoTo(${index})"></div>
            `;
        });
        
        this.updateCarouselView();
    },

    updateCarouselView() {
        const track = document.getElementById('mural-carousel-track');
        if (track) {
            track.style.transform = `translateX(-${this.carouselIndex * 100}%)`;
        }
        
        const dots = document.querySelectorAll('.carousel-dot');
        dots.forEach((dot, idx) => {
            if (idx === this.carouselIndex) dot.classList.add('active');
            else dot.classList.remove('active');
        });
    },

    carouselNext() {
        this.handleCarouselInteraction();
        if (!this.carouselItems || this.carouselItems.length === 0) return;
        this.carouselIndex = (this.carouselIndex + 1) % this.carouselItems.length;
        this.updateCarouselView();
    },

    carouselPrev() {
        this.handleCarouselInteraction();
        if (!this.carouselItems || this.carouselItems.length === 0) return;
        this.carouselIndex = (this.carouselIndex - 1 + this.carouselItems.length) % this.carouselItems.length;
        this.updateCarouselView();
    },

    carouselGoTo(index) {
        this.handleCarouselInteraction();
        this.carouselIndex = index;
        this.updateCarouselView();
    },

    handleCarouselInteraction() {
        // Pause and reset autoplay on interaction
        this.startCarouselAutoPlay(15000);
    },

    startCarouselAutoPlay(delay = 8000) {
        if (this.carouselInterval) clearInterval(this.carouselInterval);
        this.carouselInterval = setInterval(() => {
            if (!this.carouselItems || this.carouselItems.length <= 1) return;
            this.carouselIndex = (this.carouselIndex + 1) % this.carouselItems.length;
            this.updateCarouselView();
        }, delay);
    },


    getMemberBirthDayLocal(m) {
        if (m.dataNascimento && m.dataNascimento !== 'N/A') {
            const parts = m.dataNascimento.split('-');
            if (parts.length >= 3) {
                return parseInt(parts[2], 10);
            }
        }
        return 1;
    },

    showMuralAvisosDetail() {
        const avisos = this.cachedAvisosList || [];
        if (avisos.length === 0) {
            this.showAlert('Nenhum aviso importante no momento.', 'Mural de Avisos');
            return;
        }
        
        let html = '<div class="mural-reader-container">';
        avisos.forEach(a => {
            const dateStr = a.data && typeof a.data.toDate === 'function' ? a.data.toDate().toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit', year: 'numeric' }) + ' • ' + a.data.toDate().toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' }) : (a.data ? new Date(a.data).toLocaleDateString('pt-BR') : '');
            html += `
                <div class="mural-reader-card">
                    <div class="mural-accent-bar"></div>
                    <div class="mural-card-content">
                        <span class="mural-card-tag">RESUMO</span>
                        <h3 class="mural-card-title">${a.titulo}</h3>
                        ${a.subtitulo ? `<h4 class="mural-card-subtitle">${a.subtitulo}</h4>` : ''}
                        
                        <hr class="mural-card-divider">
                        
                        <div class="mural-card-body">${a.conteudo || a.texto || ''}</div>
                        
                        <hr class="mural-card-divider">
                        
                        <span class="mural-card-date">${dateStr}</span>
                    </div>
                </div>
            `;
        });
        html += '</div>';
        
        this.showAlert(html, 'Mural de Avisos');
    },

    showChecklistDetail(type) {
        let title = '';
        let html = '';
        
        const cardStyle = `<div class="mural-reader-container"><div class="mural-reader-card"><div class="mural-card-content"><div class="mural-card-body">`;
        const endCardStyle = `</div></div></div></div>`;

        if (type === 'portaria') {
            title = 'Checklist: Portaria';
            html = cardStyle + `
                <p><strong>Função:</strong> Recepcionar todos os visitantes e membros.</p>
                <p><strong>Responsabilidades:</strong></p>
                <ul style="margin-left: 20px; margin-bottom: 15px;">
                    <li>Dar boas-vindas.</li>
                    <li>Abrir portas.</li>
                    <li>Auxiliar idosos.</li>
                    <li>Auxiliar pessoas com deficiência.</li>
                    <li>Orientar visitantes.</li>
                    <li>Manter entrada organizada.</li>
                    <li>Observar qualquer situação suspeita.</li>
                </ul>
                <p style="color: #E11D48;"><strong>Nunca:</strong></p>
                <ul style="margin-left: 20px; color: #E11D48;">
                    <li>Deixar a porta sem responsável.</li>
                    <li>Criar barreiras para visitantes.</li>
                </ul>
            ` + endCardStyle;
        } else if (type === 'checkin') {
            title = 'Checklist: Check-in';
            html = cardStyle + `
                <p><strong>Responsabilidades da equipe:</strong></p>
                <ul style="margin-left: 20px;">
                    <li>Registrar a entrada das crianças no aplicativo da igreja.</li>
                    <li>Confirmar os dados dos responsáveis durante o check-in infantil.</li>
                    <li>Realizar cadastro de novos membros e visitantes.</li>
                    <li>Atualizar cadastros existentes.</li>
                    <li>Efetuar inscrições para eventos, cursos e conferências.</li>
                    <li>Orientar sobre horários e ministérios.</li>
                    <li>Manter o sigilo dos dados informados.</li>
                </ul>
            ` + endCardStyle;
        } else if (type === 'templo') {
            title = 'Checklist: Templo';
            html = cardStyle + `
                <p><strong>Responsabilidades da equipe:</strong></p>
                <ul style="margin-left: 20px; margin-bottom: 15px;">
                    <li>Organizar o ambiente interno do templo antes do culto.</li>
                    <li>Acomodar pessoas nos assentos (reservar lugares para autoridades se necessário).</li>
                    <li>Prestar auxílio direto a Idosos, Gestantes, PCDs e Visitantes.</li>
                    <li>Evitar circulação desnecessária durante o culto.</li>
                    <li>Auxiliar em emergências ou mal-estar de membros.</li>
                </ul>
            ` + endCardStyle;
        } else if (type === 'ronda') {
            title = 'Checklist: Ronda';
            html = cardStyle + `
                <p><strong>Responsabilidades da equipe:</strong></p>
                <ul style="margin-left: 20px; margin-bottom: 15px;">
                    <li>Garantir ordem e segurança nas dependências internas e externas.</li>
                    <li>Observar ativamente banheiros, corredores, salas anexas e estacionamento.</li>
                    <li>Verificar se portas estão devidamente fechadas.</li>
                    <li>Ficar atento a crianças desacompanhadas.</li>
                    <li>Monitorar movimentação de pessoas desconhecidas.</li>
                </ul>
                <p style="color: #E11D48;"><strong>Nunca:</strong></p>
                <ul style="margin-left: 20px; color: #E11D48;">
                    <li>Agir sozinho em caso de risco iminente ou situação perigosa (sempre chame a liderança).</li>
                </ul>
            ` + endCardStyle;
        } else if (type === 'templo_ronda') {
            title = 'Checklist: Templo & Ronda';
            html = cardStyle + `
                <p><strong>TEMPLO - Responsabilidades:</strong></p>
                <ul style="margin-left: 20px; margin-bottom: 15px;">
                    <li>Organizar ambiente, acomodar pessoas.</li>
                    <li>Auxiliar Idosos, Gestantes e PCDs.</li>
                    <li>Evitar circulação durante a ministração.</li>
                </ul>
                <p><strong>RONDA - Responsabilidades:</strong></p>
                <ul style="margin-left: 20px; margin-bottom: 15px;">
                    <li>Garantir segurança (corredores, salas e área externa).</li>
                    <li>Monitorar movimentação estranha e relatar atitudes incomuns.</li>
                </ul>
                <p style="color: #E11D48;"><strong>Nunca:</strong></p>
                <ul style="margin-left: 20px; color: #E11D48;">
                    <li>Agir sozinho em caso de risco.</li>
                </ul>
            ` + endCardStyle;
        }

        this.showAlert(html, title);
    },

    showMuralBirthdaysDetail() {
        const members = this.cachedBirthdayMembers || [];
        if (members.length === 0) {
            this.showAlert('Nenhum aniversariante registrado para este mês.', 'Aniversariantes do Mês');
            return;
        }
        
        const currentMonthName = new Date().toLocaleDateString('pt-BR', { month: 'long' });
        const currentMonthCapitalized = currentMonthName.charAt(0).toUpperCase() + currentMonthName.slice(1);
        const currentMonthNumStr = (new Date().getMonth() + 1).toString().padStart(2, '0');
        
        let html = `<div style="text-align: left; display: flex; flex-direction: column; gap: 12px; max-height: 350px; overflow-y: auto; padding-right: 5px;">`;
        html += `<p style="margin: 0 0 10px 0; color: #94a3b8; font-size: 0.85rem;">Lista de aniversariantes de <strong>${currentMonthCapitalized}</strong>:</p>`;
        
        members.forEach(m => {
            const day = this.getMemberBirthDayLocal(m).toString().padStart(2, '0');
            html += `
                <div style="display: flex; align-items: center; justify-content: space-between; border-bottom: 1px solid #E2E8F0; padding-bottom: 8px;">
                    <div style="display: flex; align-items: center; gap: 10px;">
                        <div style="width: 32px; height: 32px; border-radius: 50%; background: linear-gradient(135deg, var(--teal-primary), var(--navy-primary)); color: #ffffff; display: flex; align-items: center; justify-content: center; font-weight: 800; font-size: 0.72rem; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                            ${m.fotoUrl ? `<img src="${m.fotoUrl}" style="width:100%; height:100%; object-fit:cover;">` : m.nome.substring(0, 2).toUpperCase()}
                        </div>
                        <span style="color: var(--navy-dark); font-size: 0.95rem; font-weight: 700;">${m.nome}</span>
                    </div>
                    <span style="color: var(--teal-primary); font-size: 0.85rem; font-weight: 800; background: rgba(18, 115, 105, 0.1); padding: 4px 8px; border-radius: 6px;"><i class="fa-regular fa-calendar" style="margin-right: 4px;"></i>${day}/${currentMonthNumStr}</span>
                </div>
            `;
        });
        html += '</div>';
        
        this.showAlert(html, 'Aniversariantes do Mês');
    },

    async checkAndCreateAutomatedPosts() {
        const today = new Date();
        const y = today.getFullYear();
        const m = String(today.getMonth() + 1).padStart(2, '0');
        const d = String(today.getDate()).padStart(2, '0');
        const todayStr = `${y}-${m}-${d}`;
        const dayOfWeek = today.getDay(); // 0 = Sunday, 2 = Tuesday
        
        // Only run on Sundays or Tuesdays
        if (dayOfWeek !== 0 && dayOfWeek !== 2) return;
        
        const hour = today.getHours();
        const min = today.getMinutes();
        const currentTime = hour * 60 + min; // Time in minutes from midnight
        
        const lsKeyPrefix = `mural_auto_${todayStr}`;
        
        const postsToCreate = [];
        
        // DOMINGO (0 = Sunday)
        if (dayOfWeek === 0) {
            // Lembrete Antes do Culto (45 min antes, ex: 08:45)
            // Culto costuma ser de manhã? Vamos considerar que sim se passar das 08:00.
            if (currentTime >= 8 * 60 + 0 && !localStorage.getItem(`${lsKeyPrefix}_domingo_inicio`)) {
                postsToCreate.push({
                    key: `${lsKeyPrefix}_domingo_inicio`,
                    aviso: {
                        titulo: "📋 Lembrete: Checklist do Domingo",
                        conteudo: "Bom dia, obreiros e obreiras! O culto de hoje começará em breve. Por favor, revisem o seu checklist de atividades no aplicativo e estejam preparados em seus postos. Um ótimo culto a todos!",
                        tipo: "aviso",
                        dataCriacao: today.toISOString()
                    }
                });
            }
            // Lembrete Fim do Culto (12:00)
            if (currentTime >= 12 * 60 + 0 && !localStorage.getItem(`${lsKeyPrefix}_domingo_fim`)) {
                postsToCreate.push({
                    key: `${lsKeyPrefix}_domingo_fim`,
                    aviso: {
                        titulo: "🗑️ Ajude a Limpeza",
                        conteudo: "Graça e paz! O culto de domingo encerrou. Lembrem-se de retirar o lixo de seus setores e manter o espaço organizado para ajudar a equipe de limpeza. Deus abençoe!",
                        tipo: "info",
                        dataCriacao: today.toISOString()
                    }
                });
            }
        }
        
        // TERÇA (2 = Tuesday)
        if (dayOfWeek === 2) {
            // Lembrete Antes do Culto (15 min antes, ex: 19:45)
            if (currentTime >= 19 * 60 + 30 && !localStorage.getItem(`${lsKeyPrefix}_terca_inicio`)) {
                postsToCreate.push({
                    key: `${lsKeyPrefix}_terca_inicio`,
                    aviso: {
                        titulo: "📋 Lembrete: Checklist da Terça",
                        conteudo: "Boa noite, equipe! Nosso culto de ensino começará em breve. Revise as tarefas do seu setor pelo app e ocupe seu posto. Bom culto!",
                        tipo: "aviso",
                        dataCriacao: today.toISOString()
                    }
                });
            }
            // Lembrete Fim do Culto (21:00)
            if (currentTime >= 21 * 60 + 0 && !localStorage.getItem(`${lsKeyPrefix}_terca_fim`)) {
                postsToCreate.push({
                    key: `${lsKeyPrefix}_terca_fim`,
                    aviso: {
                        titulo: "🗑️ Ajude a Limpeza",
                        conteudo: "Fim de culto! Por favor, lembrem-se de retirar o lixo de seus setores e organizar o ambiente para facilitar o trabalho da nossa equipe de limpeza e manutenção. Obrigado!",
                        tipo: "info",
                        dataCriacao: today.toISOString()
                    }
                });
            }
        }
        
        for (const post of postsToCreate) {
            try {
                // To avoid race conditions across multiple users logging in simultaneously,
                // we check the DB directly before inserting (though slightly heavier).
                const avisos = await DbService.getAvisos();
                const alreadyExists = avisos.some(a => a.titulo === post.aviso.titulo && a.dataCriacao.startsWith(todayStr));
                
                if (!alreadyExists) {
                    await DbService.addAviso(post.aviso);
                }
                
                // Always set local storage so this specific user's browser stops checking DB
                localStorage.setItem(post.key, "true");
                
            } catch (e) {
                console.error("Erro ao criar post automático:", e);
            }
        }
    },

    async loadMuralConfigAdmin() {
        try {
            const config = await DbService.getMuralConfig();
            const txtVersiculo = document.getElementById('mural-config-versiculo');
            const txtReferencia = document.getElementById('mural-config-referencia');
            const txtLembrete = document.getElementById('mural-config-lembrete');
            
            if (txtVersiculo && txtReferencia && txtLembrete) {
                if (config) {
                    txtVersiculo.value = config.versiculoTexto || '';
                    txtReferencia.value = config.versiculoReferencia || '';
                    txtLembrete.value = config.lembrete || '';
                } else {
                    txtVersiculo.value = "Tudo posso naquele que me fortalece.";
                    txtReferencia.value = "Filipenses 4:13";
                    txtLembrete.value = "Cada serviço é uma oportunidade de amar e servir a Deus!";
                }
            }
        } catch (e) {
            console.error("Error loading mural config in admin:", e);
        }
    },

    async handleSaveMuralConfig(event) {
        event.preventDefault();
        const txtVersiculo = document.getElementById('mural-config-versiculo');
        const txtReferencia = document.getElementById('mural-config-referencia');
        const txtLembrete = document.getElementById('mural-config-lembrete');
        
        if (!txtVersiculo || !txtReferencia || !txtLembrete) return;
        
        try {
            App.showLoading();
            await DbService.saveMuralConfig({
                versiculoTexto: txtVersiculo.value.trim(),
                versiculoReferencia: txtReferencia.value.trim(),
                lembrete: txtLembrete.value.trim()
            });
            App.hideLoading();
            App.showToast('Configurações do Mural salvas com sucesso!', 'success');
            
            // Reload select screen if loaded
            if (document.getElementById('view-setor-select').classList.contains('active')) {
                App.renderSectorSelectionScreen();
            }
        } catch (e) {
            App.hideLoading();
            console.error("Error saving mural config:", e);
            App.showToast('Erro ao salvar configurações do Mural.', 'danger');
        }
    },

    async openMinhasEscalasModal() {
        if (!this.currentUser) return;
        
        const container = document.getElementById('minhas-escalas-list-container');
        if (!container) return;
        
        container.innerHTML = '<div style="text-align:center; padding: 40px;"><i class="fa-solid fa-circle-notch fa-spin" style="font-size: 2rem; color: var(--teal-primary);"></i><p style="margin-top:15px; color:var(--slate-gray); font-weight: 600;">Buscando suas escalas...</p></div>';
        document.getElementById('modal-minhas-escalas').classList.add('active');
        
        try {
            const escalas = await DbService.getEscalasDoMembro(this.currentUser.id);
            
            const now = new Date();
            const parseScaleDate = (dataStr, horaStr) => {
                if (!dataStr) return new Date(0);
                // The dataStr is usually 'YYYY-MM-DD' from the HTML5 input
                let parts = dataStr.split('-');
                if (parts.length === 3) {
                    const hParts = (horaStr || '00:00').split(':');
                    return new Date(parts[0], parts[1] - 1, parts[2], hParts[0], hParts[1]);
                }
                // Fallback if someone used 'DD/MM/YYYY' manually
                parts = dataStr.split('/');
                if (parts.length === 3) {
                    const hParts = (horaStr || '00:00').split(':');
                    return new Date(parts[2], parts[1] - 1, parts[0], hParts[0], hParts[1]);
                }
                return new Date(0);
            };
            
            const sortedEscalas = escalas.filter(e => {
                const scaleDate = parseScaleDate(e.data, '23:59'); // Keep if today
                return scaleDate >= new Date(now.setHours(0,0,0,0));
            }).sort((a, b) => {
                return parseScaleDate(a.data, a.horarioInicio) - parseScaleDate(b.data, b.horarioInicio);
            });
            
            if (sortedEscalas.length === 0) {
                container.innerHTML = `
                    <div style="text-align:center; padding: 50px 20px; background: white; border-radius: 16px; border: 1px dashed #CBD5E1;">
                        <i class="fa-solid fa-calendar-xmark" style="font-size: 2.5rem; color: #94A3B8; margin-bottom: 15px;"></i>
                        <h4 style="color: var(--navy-primary); font-size: 1.1rem; margin-bottom: 5px;">Nenhuma escala agendada</h4>
                        <p style="color: var(--slate-gray); font-size: 0.9rem;">Você não possui serviços previstos para os próximos dias.</p>
                    </div>
                `;
                return;
            }
            
            let html = '<div style="display: flex; flex-direction: column; gap: 16px;">';
            
            sortedEscalas.forEach(e => {
                const isConfirmed = e.status === 'confirmado';
                const statusBadge = isConfirmed 
                    ? `<span style="background: rgba(16, 185, 129, 0.15); color: #059669; padding: 4px 10px; border-radius: 6px; font-size: 0.75rem; font-weight: 700; border: 1px solid rgba(16, 185, 129, 0.3);"><i class="fa-solid fa-check" style="margin-right: 4px;"></i> Confirmada</span>`
                    : `<span style="background: rgba(245, 158, 11, 0.15); color: #D97706; padding: 4px 10px; border-radius: 6px; font-size: 0.75rem; font-weight: 700; border: 1px solid rgba(245, 158, 11, 0.3);"><i class="fa-solid fa-hourglass-half" style="margin-right: 4px;"></i> Pendente</span>`;
                
                const dateObj = parseScaleDate(e.data, e.horarioInicio);
                const dayNum = String(dateObj.getDate()).padStart(2, '0');
                const monthName = dateObj.toLocaleDateString('pt-BR', { month: 'short' }).replace('.', '').toUpperCase();

                const isToday = dateObj.toDateString() === new Date().toDateString();
                const dayLabel = isToday ? '<span style="color: #EF4444; font-weight: 800; font-size: 0.75rem; text-transform: uppercase; letter-spacing: 1px; display: block; margin-bottom: 4px;">HOJE</span>' : '';
                
                html += `
                    <div style="background: white; border-radius: 16px; padding: 20px; box-shadow: 0 4px 15px rgba(0,0,0,0.03); border: 1px solid #E2E8F0; display: flex; gap: 15px; align-items: stretch;">
                        <div style="display: flex; flex-direction: column; align-items: center; justify-content: center; min-width: 65px; border-right: 1px dashed #E2E8F0; padding-right: 15px;">
                            ${dayLabel}
                            <span style="font-size: 1.8rem; font-weight: 900; color: var(--navy-primary); line-height: 1;">${dayNum}</span>
                            <span style="font-size: 0.85rem; font-weight: 600; color: var(--slate-gray); text-transform: uppercase;">${monthName}</span>
                        </div>
                        <div style="flex: 1; display: flex; flex-direction: column; justify-content: center;">
                            <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 8px;">
                                <h4 style="margin: 0; font-size: 1.05rem; font-weight: 800; color: var(--navy-dark);">${e.cultoNome || 'Serviço'}</h4>
                                ${statusBadge}
                            </div>
                            <div style="display: flex; align-items: center; gap: 15px; color: var(--slate-gray); font-size: 0.85rem; font-weight: 500; margin-bottom: 10px;">
                                <span><i class="fa-regular fa-clock" style="color: var(--teal-primary); margin-right: 4px;"></i> ${e.horarioInicio || '--'} às ${e.horarioFim || '--'}</span>
                            </div>
                            <div style="background: #F8FAFC; padding: 8px 12px; border-radius: 8px; border: 1px solid #F1F5F9; font-size: 0.85rem; color: var(--navy-primary); font-weight: 600; display: inline-block; align-self: flex-start; margin-bottom: 10px;">
                                <i class="fa-solid fa-user-tag" style="color: #64748B; margin-right: 6px;"></i> ${e.funcao || 'Voluntário'}
                            </div>
                            ${e.statusPresenca === 'Pendente' ? `
                            <div style="display: flex; gap: 8px; margin-top: auto;">
                                <button class="btn-scale-action btn-confirm-presenca" onclick="App.handleConfirmPresenca('${e.id}', 'Confirmada')" style="flex: 1; padding: 8px; font-size: 0.8rem;">
                                    <i class="fa-solid fa-check"></i> Aceitar
                                </button>
                                <button class="btn-scale-action btn-recusar-presenca" onclick="App.handleConfirmPresenca('${e.id}', 'Recusada')" style="flex: 1; padding: 8px; font-size: 0.8rem;">
                                    <i class="fa-solid fa-xmark"></i> Recusar
                                </button>
                            </div>
                            ` : ''}
                        </div>
                    </div>
                `;
            });
            
            html += '</div>';
            container.innerHTML = html;
            
        } catch (error) {
            console.error("Error loading user scales:", error);
            container.innerHTML = '<div style="text-align:center; padding: 20px; color: #EF4444;"><i class="fa-solid fa-triangle-exclamation" style="margin-bottom: 10px; font-size: 1.5rem;"></i><br>Erro ao carregar escalas. Tente novamente.</div>';
        }
    },

    async openMeuPerfilModal() {
        if (!this.currentUser) return;
        
        const headerContainer = document.getElementById('meu-perfil-header-container');
        const statsContainer = document.getElementById('meu-perfil-stats-container');
        const toolsContainer = document.getElementById('meu-perfil-tools-container');
        
        if (!headerContainer || !statsContainer) return;
        
        const initials = this.currentUser.nome ? this.currentUser.nome.substring(0, 2).toUpperCase() : 'UI';
        headerContainer.innerHTML = `
            <div style="width: 80px; height: 80px; border-radius: 50%; background: linear-gradient(135deg, var(--teal-primary), var(--navy-primary)); color: white; display: flex; align-items: center; justify-content: center; font-size: 2rem; font-weight: 800; margin: 0 auto 15px auto; box-shadow: 0 8px 20px rgba(0,0,0,0.1);">
                ${initials}
            </div>
            <h2 style="margin: 0 0 5px 0; color: var(--navy-dark); font-size: 1.3rem; font-weight: 800;">${this.currentUser.nome || 'Usuário'}</h2>
            <p style="margin: 0; color: var(--slate-gray); font-size: 0.9rem; font-weight: 500;">Membro Ativo</p>
        `;
        
        // FASE 3.5: Detecção de Limpeza / Conservação
        if (toolsContainer) {
            const checkLimpeza = (val) => {
                if (!val) return false;
                const normalized = val.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
                return normalized.includes('limpeza') || normalized.includes('conservacao');
            };
            const isLimpeza = checkLimpeza(this.currentUser.setor) || (Array.isArray(this.currentUser.setores) && this.currentUser.setores.some(checkLimpeza));
            
            if (isLimpeza) {
                toolsContainer.innerHTML = `
                    <h4 style="font-size: 1rem; color: var(--navy-dark); margin-bottom: 15px; font-weight: 700;">Ferramentas do Setor</h4>
                    <div style="background: white; border-radius: 16px; padding: 20px; box-shadow: 0 4px 15px rgba(0,0,0,0.03); border: 1px solid #E2E8F0; margin-bottom: 30px;">
                        <button onclick="App.openPedirMaterialModal()" class="btn-primary" style="width: 100%; border-radius: 10px; padding: 12px; font-weight: 600; background: var(--navy-primary); border-color: var(--navy-primary); display: flex; align-items: center; justify-content: center;"><i class="fa-solid fa-broom" style="margin-right: 8px;"></i> Pedir Material</button>
                    </div>
                `;
                toolsContainer.style.display = 'block';
            } else {
                toolsContainer.innerHTML = '';
                toolsContainer.style.display = 'none';
            }
        }
        
        statsContainer.innerHTML = `
            <div style="background: white; border-radius: 16px; padding: 15px; border: 1px solid #E2E8F0; display: flex; flex-direction: column; align-items: center;">
                <i class="fa-solid fa-circle-notch fa-spin" style="color: var(--teal-primary); font-size: 1.2rem; margin-bottom: 10px;"></i>
                <span style="font-size: 0.8rem; color: var(--slate-gray);">Carregando...</span>
            </div>
        `;
        
        document.getElementById('modal-meu-perfil').classList.add('active');
        
        try {
            const escalas = await DbService.getEscalasDoMembro(this.currentUser.id);
            const stats = escalas.reduce((acc, curr) => {
                acc.total++;
                if (curr.status === 'confirmado') acc.confirmadas++;
                else acc.pendentes++;
                return acc;
            }, { total: 0, confirmadas: 0, pendentes: 0 });
            
            statsContainer.innerHTML = `
                <div style="background: white; border-radius: 16px; padding: 20px 15px; border: 1px solid #E2E8F0; display: flex; flex-direction: column; align-items: center; box-shadow: 0 4px 10px rgba(0,0,0,0.02);">
                    <div style="width: 40px; height: 40px; border-radius: 12px; background: rgba(16, 185, 129, 0.1); color: #059669; display: flex; align-items: center; justify-content: center; font-size: 1.2rem; margin-bottom: 10px;">
                        <i class="fa-solid fa-check-double"></i>
                    </div>
                    <span style="font-size: 1.5rem; font-weight: 800; color: var(--navy-dark); line-height: 1;">${stats.confirmadas}</span>
                    <span style="font-size: 0.75rem; color: var(--slate-gray); font-weight: 600; text-transform: uppercase; margin-top: 5px;">Confirmadas</span>
                </div>
                <div style="background: white; border-radius: 16px; padding: 20px 15px; border: 1px solid #E2E8F0; display: flex; flex-direction: column; align-items: center; box-shadow: 0 4px 10px rgba(0,0,0,0.02);">
                    <div style="width: 40px; height: 40px; border-radius: 12px; background: rgba(59, 130, 246, 0.1); color: #3B82F6; display: flex; align-items: center; justify-content: center; font-size: 1.2rem; margin-bottom: 10px;">
                        <i class="fa-solid fa-clipboard-list"></i>
                    </div>
                    <span style="font-size: 1.5rem; font-weight: 800; color: var(--navy-dark); line-height: 1;">${stats.total}</span>
                    <span style="font-size: 0.75rem; color: var(--slate-gray); font-weight: 600; text-transform: uppercase; margin-top: 5px;">Total</span>
                </div>
            `;
            
        } catch(e) {
            console.error("Error loading profile stats:", e);
        }
    },

    async handleSendMeuPerfilMessage(event) {
        event.preventDefault();
        const textarea = document.getElementById('meu-perfil-supervision-msg-text');
        if (!textarea) return;
        
        const content = textarea.value.trim();
        if (!content) return;
        
        try {
            App.showLoading();
            await DbService.saveSupervisionMessage(this.currentUser.id, this.currentUser.nome, content);
            App.hideLoading();
            App.showToast('Mensagem enviada com sucesso para a supervisão!', 'success');
            textarea.value = '';
            document.getElementById('modal-meu-perfil').classList.remove('active');
        } catch (e) {
            App.hideLoading();
            console.error("Error sending supervision message from profile:", e);
            App.showToast('Erro ao enviar mensagem. Tente novamente.', 'danger');
        }
    },

    // --- NAV NAVIGATION AND MODAL HANDLERS (v3.10) ---
    setActiveNavBtn(btnId) {
        document.querySelectorAll('.nav-action-btn').forEach(btn => {
            btn.classList.remove('active');
            btn.style.color = '#94A3B8';
        });
        const activeBtn = document.getElementById(btnId);
        if (activeBtn) {
            activeBtn.classList.add('active');
            activeBtn.style.color = 'var(--teal-primary)';
        }
    },
    openMaisModal() {
        const modal = document.getElementById('modal-mais');
        if (modal) modal.classList.add('active');
    },
    openConfiguracoes() {
        this.showToast('Configurações acessadas.', 'info');
    },
    showSobre() {
        this.showAlert(
            `<div style="text-align: center; font-family: inherit;">
                <h4 style="margin: 0 0 10px 0; color: var(--navy-dark); font-weight: 800;">Diaconato v3.10.5</h4>
                <p style="font-size: 0.9rem; color: var(--slate-gray); line-height: 1.5; margin: 0;">
                    Aplicativo inteligente para gerenciamento, escalas e comunicação do Diaconato.
                </p>
                <div style="font-size: 0.78rem; color: #94A3B8; border-top: 1px solid #E2E8F0; padding-top: 10px;">
                    Desenvolvido com ❤️ para a Catedral.
                </div>
            </div>`,
            'Sobre o Aplicativo'
        );
    },
    openAdminPortalDirect() {
        const isAdmin = this.currentUser && this.currentUser.perfil === 'admin';
        if (!isAdmin) {
            console.error('[Segurança] Tentativa de navegar direto para Admin bloqueada.');
            this.showToast('Acesso negado. Esta é uma área administrativa.', 'danger');
            return;
        }
        this.navigateTo('view-admin');
    },
    openDisponibilidadeModal() {
        this.showAlert("Para ajustar sua disponibilidade ou candidatar-se a voluntariado, utilize a aba de Escalas do aplicativo.", "Disponibilidade");
    },
    openSolicitarFeriasModal() {
        const msgModal = document.getElementById('modal-meu-perfil');
        if (msgModal) msgModal.classList.remove('active');
        this.showAlert(
            `<div style="text-align: left;">
                <p style="font-size: 0.88rem; margin-bottom: 15px; color: var(--slate-gray);">Solicite suas férias ou período de afastamento enviando uma mensagem direta para a supervisão:</p>
                <textarea id="solicitar-ferias-texto" rows="4" placeholder="Ex: Solicito afastamento das escalas entre 10/07 e 25/07 por motivo de viagem." style="width:100%; border: 1px solid #E2E8F0; border-radius:12px; padding:10px; font-family:inherit; font-size:0.88rem; box-sizing:border-box; resize:none;"></textarea>
                <button onclick="App.enviarSolicitacaoFerias()" class="btn-primary" style="width:100%; margin-top:15px; padding:12px; border-radius:10px; font-weight:700;">Enviar Solicitação</button>
            </div>`,
            "Solicitar Férias / Ausência"
        );
    },
    async enviarSolicitacaoFerias() {
        const txt = document.getElementById('solicitar-ferias-texto');
        if (!txt) return;
        const val = txt.value.trim();
        if (!val) {
            this.showToast('Preencha o motivo/datas do afastamento.', 'warning');
            return;
        }
        try {
            this.showLoading();
            await DbService.saveSupervisionMessage(this.currentUser.id, this.currentUser.nome, `[SOLICITAÇÃO DE FÉRIAS] ${val}`);
            this.hideLoading();
            this.closeAlert();
            this.showToast('Solicitação de férias enviada para a supervisão!', 'success');
        } catch(e) {
            this.hideLoading();
            this.showToast('Erro ao enviar solicitação.', 'danger');
        }
    },
    openSolicitarSubstituicaoModal() {
        const msgModal = document.getElementById('modal-meu-perfil');
        if (msgModal) msgModal.classList.remove('active');
        this.showAlert(
            `<div style="text-align: left;">
                <p style="font-size: 0.88rem; margin-bottom: 15px; color: var(--slate-gray);">Solicite substituição de escala enviando detalhes para a supervisão:</p>
                <textarea id="solicitar-substituicao-texto" rows="4" placeholder="Ex: Preciso de substituição na escala do dia 28/06 no culto da noite." style="width:100%; border: 1px solid #E2E8F0; border-radius:12px; padding:10px; font-family:inherit; font-size:0.88rem; box-sizing:border-box; resize:none;"></textarea>
                <button onclick="App.enviarSolicitacaoSubstituicao()" class="btn-primary" style="width:100%; margin-top:15px; padding:12px; border-radius:10px; font-weight:700;">Enviar Solicitação</button>
            </div>`,
            "Solicitar Substituição"
        );
    },
    async enviarSolicitacaoSubstituicao() {
        const txt = document.getElementById('solicitar-substituicao-texto');
        if (!txt) return;
        const val = txt.value.trim();
        if (!val) {
            this.showToast('Preencha os detalhes da substituição.', 'warning');
            return;
        }
        try {
            this.showLoading();
            await DbService.saveSupervisionMessage(this.currentUser.id, this.currentUser.nome, `[SOLICITAÇÃO DE SUBSTITUIÇÃO] ${val}`);
            this.hideLoading();
            this.closeAlert();
            this.showToast('Solicitação de substituição enviada para a supervisão!', 'success');
        } catch(e) {
            this.hideLoading();
            this.showToast('Erro ao enviar solicitação.', 'danger');
        }
    },
    openSupervisionMsgModal() {
        const msgModal = document.getElementById('modal-meu-perfil');
        if (msgModal) msgModal.classList.remove('active');
        this.showAlert(
            `<div style="text-align: left;">
                <p style="font-size: 0.88rem; margin-bottom: 15px; color: var(--slate-gray);">Envie uma mensagem direta para a supervisão do Diaconato:</p>
                <textarea id="mensagem-supervisao-texto" rows="4" placeholder="Escreva sua mensagem aqui..." style="width:100%; border: 1px solid #E2E8F0; border-radius:12px; padding:10px; font-family:inherit; font-size:0.88rem; box-sizing:border-box; resize:none;"></textarea>
                <button onclick="App.enviarMensagemSupervisaoDirect()" class="btn-primary" style="width:100%; margin-top:15px; padding:12px; border-radius:10px; font-weight:700;">Enviar Mensagem</button>
            </div>`,
            "Mensagem para Supervisão"
        );
    },
    async enviarMensagemSupervisaoDirect() {
        const txt = document.getElementById('mensagem-supervisao-texto');
        if (!txt) return;
        const val = txt.value.trim();
        if (!val) {
            this.showToast('Preencha a mensagem antes de enviar.', 'warning');
            return;
        }
        try {
            this.showLoading();
            await DbService.saveSupervisionMessage(this.currentUser.id, this.currentUser.nome, val);
            this.hideLoading();
            this.closeAlert();
            this.showToast('Mensagem enviada com sucesso!', 'success');
        } catch(e) {
            this.hideLoading();
            this.showToast('Erro ao enviar mensagem.', 'danger');
        }
    },
    openFeedbackModal() {
        const msgModal = document.getElementById('modal-meu-perfil');
        if (msgModal) msgModal.classList.remove('active');
        this.showAlert(
            `<div style="text-align: left;">
                <p style="font-size: 0.88rem; margin-bottom: 15px; color: var(--slate-gray);">Ajude-nos a melhorar o Diaconato! Deixe suas sugestões ou relate problemas:</p>
                <textarea id="feedback-app-texto" rows="4" placeholder="Escreva seu feedback..." style="width:100%; border: 1px solid #E2E8F0; border-radius:12px; padding:10px; font-family:inherit; font-size:0.88rem; box-sizing:border-box; resize:none;"></textarea>
                <button onclick="App.enviarFeedbackApp()" class="btn-primary" style="width:100%; margin-top:15px; padding:12px; border-radius:10px; font-weight:700;">Enviar Feedback</button>
            </div>`,
            "Enviar Feedback"
        );
    },
    async enviarFeedbackApp() {
        const txt = document.getElementById('feedback-app-texto');
        if (!txt) return;
        const val = txt.value.trim();
        if (!val) {
            this.showToast('Preencha o feedback antes de enviar.', 'warning');
            return;
        }
        try {
            this.showLoading();
            await DbService.saveSupervisionMessage(this.currentUser.id, this.currentUser.nome, `[FEEDBACK APP] ${val}`);
            this.hideLoading();
            this.closeAlert();
            this.showToast('Muito obrigado! Seu feedback foi enviado.', 'success');
        } catch(e) {
            this.hideLoading();
            this.showToast('Erro ao enviar feedback.', 'danger');
        }
    },
    openNotificationPreferences() {
        const msgModal = document.getElementById('modal-meu-perfil');
        if (msgModal) msgModal.classList.remove('active');
        this.showAlert(
            `<div style="text-align: left; font-size: 0.88rem; color: var(--navy-dark);">
                <div style="margin-bottom: 12px; display: flex; align-items: center; justify-content: space-between;">
                    <span>Alertas de Escalas por WhatsApp</span>
                    <input type="checkbox" checked style="width: 18px; height: 18px; accent-color: var(--teal-primary);">
                </div>
                <div style="margin-bottom: 12px; display: flex; align-items: center; justify-content: space-between;">
                    <span>Alertas de Escalas no App (Push)</span>
                    <input type="checkbox" checked style="width: 18px; height: 18px; accent-color: var(--teal-primary);">
                </div>
                <div style="margin-bottom: 15px; display: flex; align-items: center; justify-content: space-between;">
                    <span>Lembrete de aniversariantes diários</span>
                    <input type="checkbox" style="width: 18px; height: 18px; accent-color: var(--teal-primary);">
                </div>
                <button onclick="App.closeAlert(); App.showToast('Preferências de notificação salvas!', 'success');" class="btn-primary" style="width: 100%; padding: 12px; border-radius: 10px; font-weight: 700;">Salvar Preferências</button>
            </div>`,
            "Preferências de Notificação"
        );
    },
    async openParabenizarModal() {
        const msgModal = document.getElementById('modal-meu-perfil');
        if (msgModal) msgModal.classList.remove('active');
        this.showLoading();
        try {
            const members = await DbService.getMembros();
            const activeMembers = members.filter(m => m.status === 'ativo' && m.id !== this.currentUser.id);
            let selectOptions = activeMembers.map(m => `<option value="${m.nome}">${m.nome}</option>`).join('');
            this.hideLoading();
            this.showAlert(
                `<div style="text-align: left;">
                    <label style="font-size: 0.85rem; font-weight: 700; display: block; margin-bottom: 6px;">Selecione o Aniversariante</label>
                    <select id="parabenizar-membro" style="width: 100%; border: 1px solid #E2E8F0; border-radius: 12px; padding: 10px; font-family: inherit; font-size: 0.88rem; box-sizing: border-box; margin-bottom: 15px; background: white;">
                        ${selectOptions}
                    </select>
                    <label style="font-size: 0.85rem; font-weight: 700; display: block; margin-bottom: 6px;">Mensagem de Parabéns</label>
                    <textarea id="parabenizar-mensagem" rows="3" placeholder="Feliz aniversário, meu irmão! Que Deus te abençoe..." style="width:100%; border: 1px solid #E2E8F0; border-radius:12px; padding:10px; font-family:inherit; font-size:0.88rem; box-sizing:border-box; resize:none;"></textarea>
                    <button onclick="App.enviarMensagemReconhecimento('Parabenizar')" class="btn-primary" style="width:100%; margin-top:15px; padding:12px; border-radius:10px; font-weight:700; background: #EC4899; border-color: #EC4899;">Enviar Mensagem 🎂</button>
                </div>`,
                "Parabenizar Aniversariante"
            );
        } catch(e) {
            this.hideLoading();
            this.showToast('Erro ao carregar membros.', 'danger');
        }
    },
    async openAgradecerModal() {
        const msgModal = document.getElementById('modal-meu-perfil');
        if (msgModal) msgModal.classList.remove('active');
        this.showLoading();
        try {
            const members = await DbService.getMembros();
            const activeMembers = members.filter(m => m.status === 'ativo' && m.id !== this.currentUser.id);
            let selectOptions = activeMembers.map(m => `<option value="${m.nome}">${m.nome}</option>`).join('');
            this.hideLoading();
            this.showAlert(
                `<div style="text-align: left;">
                    <label style="font-size: 0.85rem; font-weight: 700; display: block; margin-bottom: 6px;">Selecione o Obreiro</label>
                    <select id="parabenizar-membro" style="width: 100%; border: 1px solid #E2E8F0; border-radius: 12px; padding: 10px; font-family: inherit; font-size: 0.88rem; box-sizing: border-box; margin-bottom: 15px; background: white;">
                        ${selectOptions}
                    </select>
                    <label style="font-size: 0.85rem; font-weight: 700; display: block; margin-bottom: 6px;">Agradecimento</label>
                    <textarea id="parabenizar-mensagem" rows="3" placeholder="Obrigado pelo seu apoio e serviço no último culto..." style="width:100%; border: 1px solid #E2E8F0; border-radius:12px; padding:10px; font-family:inherit; font-size:0.88rem; box-sizing:border-box; resize:none;"></textarea>
                    <button onclick="App.enviarMensagemReconhecimento('Agradecer')" class="btn-primary" style="width:100%; margin-top:15px; padding:12px; border-radius:10px; font-weight:700; background: #F59E0B; border-color: #F59E0B;">Agradecer Obreiro 👏</button>
                </div>`,
                "Agradecer um Obreiro"
            );
        } catch(e) {
            this.hideLoading();
            this.showToast('Erro ao carregar membros.', 'danger');
        }
    },
    async openIncentivarModal() {
        const msgModal = document.getElementById('modal-meu-perfil');
        if (msgModal) msgModal.classList.remove('active');
        this.showLoading();
        try {
            const members = await DbService.getMembros();
            const activeMembers = members.filter(m => m.status === 'ativo' && m.id !== this.currentUser.id);
            let selectOptions = activeMembers.map(m => `<option value="${m.nome}">${m.nome}</option>`).join('');
            this.hideLoading();
            this.showAlert(
                `<div style="text-align: left;">
                    <label style="font-size: 0.85rem; font-weight: 700; display: block; margin-bottom: 6px;">Selecione o Obreiro</label>
                    <select id="parabenizar-membro" style="width: 100%; border: 1px solid #E2E8F0; border-radius: 12px; padding: 10px; font-family: inherit; font-size: 0.88rem; box-sizing: border-box; margin-bottom: 15px; background: white;">
                        ${selectOptions}
                    </select>
                    <label style="font-size: 0.85rem; font-weight: 700; display: block; margin-bottom: 6px;">Mensagem de Incentivo</label>
                    <textarea id="parabenizar-mensagem" rows="3" placeholder="Deus te abençoe, continue firme no serviço!" style="width:100%; border: 1px solid #E2E8F0; border-radius:12px; padding:10px; font-family:inherit; font-size:0.88rem; box-sizing:border-box; resize:none;"></textarea>
                    <button onclick="App.enviarMensagemReconhecimento('Incentivar')" class="btn-primary" style="width:100%; margin-top:15px; padding:12px; border-radius:10px; font-weight:700; background: #10B981; border-color: #10B981;">Enviar Mensagem 🎉</button>
                </div>`,
                "Enviar Mensagem de Incentivo"
            );
        } catch(e) {
            this.hideLoading();
            this.showToast('Erro ao carregar membros.', 'danger');
        }
    },
    async enviarMensagemReconhecimento(tipo) {
        const select = document.getElementById('parabenizar-membro');
        const txt = document.getElementById('parabenizar-mensagem');
        if (!select || !txt) return;
        const paraMembro = select.value;
        const msg = txt.value.trim();
        if (!msg) {
            this.showToast('Escreva sua mensagem antes de enviar.', 'warning');
            return;
        }
        try {
            this.showLoading();
            await DbService.saveSupervisionMessage(this.currentUser.id, this.currentUser.nome, `[RECONHECIMENTO - ${tipo.toUpperCase()}] Para: ${paraMembro} - Mensagem: ${msg}`);
            this.hideLoading();
            this.closeAlert();
            this.showToast(`Mensagem enviada com sucesso para ${paraMembro}!`, 'success');
        } catch(e) {
            this.hideLoading();
            this.showToast('Erro ao enviar mensagem.', 'danger');
        }
    },
    openPrayersModal() {
        const msgModal = document.getElementById('modal-meu-perfil');
        if (msgModal) msgModal.classList.remove('active');
        
        let prayers = JSON.parse(localStorage.getItem('diaconia_pedidos_oracao') || '[]');
        if (prayers.length === 0) {
            prayers = [
                { id: '1', obreiro: 'Diác. Lucas', motivo: 'Intercessão pela saúde da mãe dele', data: '22/06/2026', ativo: true },
                { id: '2', obreiro: 'Supervisor André', motivo: 'Oração pela nova escala e proteção das famílias', data: '21/06/2026', ativo: true }
            ];
            localStorage.setItem('diaconia_pedidos_oracao', JSON.stringify(prayers));
        }
        
        let listHtml = prayers.map(p => `
            <div style="background: white; border-radius: 12px; padding: 12px; border: 1px solid #E2E8F0; margin-bottom: 10px; text-align: left;">
                <div style="display: flex; justify-content: space-between; margin-bottom: 4px;">
                    <span style="font-weight: 700; font-size: 0.88rem; color: var(--navy-dark);">${p.obreiro}</span>
                    <span style="font-size: 0.75rem; color: #94A3B8;">${p.data}</span>
                </div>
                <p style="margin: 0; font-size: 0.85rem; color: var(--slate-gray);">${p.motivo}</p>
            </div>
        `).join('');
        
        this.showAlert(
            `<div style="text-align: left; max-height: 400px; overflow-y: auto;">
                <div style="margin-bottom: 15px;">
                    ${listHtml}
                </div>
                <hr style="border: 0; border-top: 1px solid #E2E8F0; margin: 15px 0;">
                <label style="font-size: 0.85rem; font-weight: 700; display: block; margin-bottom: 6px;">Novo Pedido de Oração</label>
                <textarea id="novo-pedido-oracao-texto" rows="3" placeholder="Escreva seu pedido de oração..." style="width:100%; border: 1px solid #E2E8F0; border-radius:12px; padding:10px; font-family:inherit; font-size:0.88rem; box-sizing:border-box; resize:none;"></textarea>
                <button onclick="App.salvarNovoPedidoOracao()" class="btn-primary" style="width:100%; margin-top:15px; padding:12px; border-radius:10px; font-weight:700;">Publicar Pedido 🙏</button>
            </div>`,
            "Pedidos de Oração"
        );
    },
    async salvarNovoPedidoOracao() {
        const txt = document.getElementById('novo-pedido-oracao-texto');
        if (!txt) return;
        const val = txt.value.trim();
        if (!val) {
            this.showToast('Escreva o motivo da oração.', 'warning');
            return;
        }
        try {
            let prayers = JSON.parse(localStorage.getItem('diaconia_pedidos_oracao') || '[]');
            const todayStr = new Date().toLocaleDateString('pt-BR');
            const newPrayer = {
                id: Date.now().toString(),
                obreiro: this.currentUser.nome || 'Diácono',
                motivo: val,
                data: todayStr,
                ativo: true
            };
            prayers.unshift(newPrayer);
            localStorage.setItem('diaconia_pedidos_oracao', JSON.stringify(prayers));
            
            try {
                await DbService.saveSupervisionMessage(this.currentUser.id, this.currentUser.nome, `[NOVO PEDIDO ORAÇÃO] ${val}`);
            } catch(e) { console.error(e); }
            
            this.closeAlert();
            this.showToast('Pedido de oração publicado!', 'success');
            
            const escalas = await DbService.getEscalasDoMembro(this.currentUser.id);
            const avisos = await DbService.getAvisos();
            this.loadAndRenderSectorSelectMural(escalas, avisos);
        } catch(e) {
            this.showToast('Erro ao salvar pedido de oração.', 'danger');
        }
    },
    async showMuralAwayDetail() {
        this.showLoading();
        try {
            const members = await DbService.getMembros();
            const hojeStr = new Date().toISOString().split('T')[0];
            const away = members.filter(m => {
                if (m.status !== 'ativo') return false;
                if (!m.statusOperacional || m.statusOperacional === 'Disponível') return false;
                if (m.afastamentoInicio && m.afastamentoFim) {
                    return hojeStr >= m.afastamentoInicio && hojeStr <= m.afastamentoFim;
                }
                return true;
            });
            if (away.length === 0) {
                this.hideLoading();
                const lSingular = this.isOperationalSector(this.activeSectorId) ? 'voluntário' : 'obreiro';
                this.showAlert(`Nenhum ${lSingular} ausente registrado para esta semana.`, 'Ausências da Semana');
                return;
            }
            let listHtml = away.map(m => `
                <div style="background: white; border-radius: 12px; padding: 12px; border: 1px solid #E2E8F0; margin-bottom: 10px; text-align: left;">
                    <div style="font-weight: 700; font-size: 0.9rem; color: var(--navy-dark);">${m.nome}</div>
                    <div style="font-size: 0.8rem; color: #EF4444; margin-top: 4px;">Afastado temporariamente</div>
                </div>
            `).join('');
            this.hideLoading();
            this.showAlert(`<div style="max-height: 350px; overflow-y: auto;">${listHtml}</div>`, 'Ausências da Semana');
        } catch(e) {
            this.hideLoading();
            this.showToast('Erro ao carregar ausências.', 'danger');
        }
    },

    async openPedirMaterialModal() {
        const container = document.getElementById('pedir-material-list-container');
        if (!container) return;
        
        container.innerHTML = '<div style="text-align:center; padding: 40px;"><i class="fa-solid fa-circle-notch fa-spin" style="font-size: 2rem; color: var(--teal-primary);"></i><p style="margin-top:15px; color:var(--slate-gray); font-weight: 600;">Buscando materiais...</p></div>';
        document.getElementById('modal-pedir-material').classList.add('active');
        
        try {
            const produtos = await DbService.getProdutos();
            
            const checkLimpeza = (val) => {
                if (!val) return true;
                const normalized = val.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
                return normalized.includes('limpeza') || normalized.includes('conservacao');
            };
            
            const ativos = produtos.filter(p => p.status === 'ativo' && checkLimpeza(p.setorId || 'limpeza'));
            
            if (ativos.length === 0) {
                container.innerHTML = `
                    <div style="text-align:center; padding: 50px 20px; background: white; border-radius: 16px; border: 1px dashed #CBD5E1;">
                        <i class="fa-solid fa-box-open" style="font-size: 2.5rem; color: #94A3B8; margin-bottom: 15px;"></i>
                        <h4 style="color: var(--navy-primary); font-size: 1.1rem; margin-bottom: 5px;">Nenhum material</h4>
                        <p style="color: var(--slate-gray); font-size: 0.9rem;">Não há materiais cadastrados no momento.</p>
                    </div>
                `;
                return;
            }
            
            let html = '<div style="display: flex; flex-direction: column; gap: 12px;">';
            
            ativos.forEach(p => {
                const safeName = p.nome ? p.nome.replace(/'/g, "\\'") : 'Material';
                html += `
                    <div style="background: white; border-radius: 16px; padding: 15px 20px; border: 1px solid #E2E8F0; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 2px 8px rgba(0,0,0,0.02);">
                        <div style="flex: 1; padding-right: 15px;">
                            <h4 style="margin: 0 0 5px 0; font-size: 1rem; color: var(--navy-dark); font-weight: 700;">${p.nome}</h4>
                            <span style="font-size: 0.8rem; color: var(--slate-gray);"><i class="fa-solid fa-layer-group" style="margin-right: 4px;"></i>${p.unidadeMedida || 'Unidade'}</span>
                        </div>
                        <button onclick="App.solicitarReposicao('${p.id}', '${safeName}')" class="btn-primary" style="padding: 8px 16px; font-size: 0.85rem; border-radius: 8px; font-weight: 600; white-space: nowrap;"><i class="fa-solid fa-plus" style="margin-right: 6px;"></i> Pedir</button>
                    </div>
                `;
            });
            
            html += '</div>';
            container.innerHTML = html;
            
        } catch(e) {
            console.error("Error loading cleaning materials:", e);
            container.innerHTML = '<div style="text-align:center; padding: 20px; color: #EF4444;"><i class="fa-solid fa-triangle-exclamation" style="margin-bottom: 10px; font-size: 1.5rem;"></i><br>Erro ao carregar materiais.</div>';
        }
    },

    openCommunicationModal() {
        const modal = document.getElementById('modal-communication');
        if (modal) modal.style.display = 'block';
    },

    closeCommunicationModal() {
        const modal = document.getElementById('modal-communication');
        if (modal) modal.style.display = 'none';
    },

    async handleSendSupervisionMessageModal(event) {
        event.preventDefault();
        const textarea = document.getElementById('modal-supervision-msg-text');
        if (!textarea) return;
        
        const content = textarea.value.trim();
        if (!content) return;
        
        try {
            App.showLoading();
            await DbService.saveSupervisionMessage(this.currentUser.id, this.currentUser.nome, content);
            App.hideLoading();
            App.showToast('Mensagem enviada com sucesso para a supervisão!', 'success');
            textarea.value = '';
            this.closeCommunicationModal();
        } catch (e) {
            App.hideLoading();
            console.error("Error sending supervision message from modal:", e);
            App.showToast('Erro ao enviar mensagem. Tente novamente.', 'danger');
        }
    },

    renderNoScalesActionCards(container) {
        container.innerHTML = `
            <div style="display: flex; flex-direction: column; gap: 15px; width: 100%; margin-top: 15px;">
                <div class="panel-card" style="padding: 24px 20px; text-align: center; border: 1.5px solid rgba(255,255,255,0.06); background: rgba(255,255,255,0.02); border-radius: 20px; cursor: pointer; transition: all 0.2s ease;" onclick="App.handleShowAllScales()">
                    <div style="width: 50px; height: 50px; border-radius: 50%; background: rgba(138, 166, 163, 0.1); border: 1px solid rgba(138, 166, 163, 0.2); color: #8AA6A3; display: flex; align-items: center; justify-content: center; font-size: 1.5rem; margin: 0 auto 12px;">
                        <i class="fa-solid fa-calendar-xmark"></i>
                    </div>
                    <div style="font-size: 0.95rem; font-weight: 800; color: #fff; margin-bottom: 5px;">Você não está na escala nos próximos cultos</div>
                    <div style="font-size: 0.78rem; color: #8AA6A3;">Clique para ver quem está escalado ou ver a escala geral do mês.</div>
                </div>

                <div class="panel-card" style="padding: 24px 20px; text-align: center; border: 1.5px solid rgba(18, 115, 105, 0.2); background: rgba(18, 115, 105, 0.05); border-radius: 20px; cursor: pointer; transition: all 0.2s ease;" onclick="App.openQuickStandbyModal()">
                    <div style="width: 50px; height: 50px; border-radius: 50%; background: rgba(18, 115, 105, 0.15); border: 1px solid rgba(18, 115, 105, 0.3); color: var(--theme-color); display: flex; align-items: center; justify-content: center; font-size: 1.5rem; margin: 0 auto 12px;">
                        <i class="fa-solid fa-hand-holding-hand"></i>
                    </div>
                    <div style="font-size: 0.95rem; font-weight: 800; color: #fff; margin-bottom: 5px;">Estou disponível no próximo culto</div>
                    <div style="font-size: 0.78rem; color: #8AA6A3;">Se candidate como voluntário. Você pode escolher o setor ou deixar em aberto.</div>
                </div>
            </div>
        `;
    },

    handleShowAllScales() {
        this.forceShowFullScales = true;
        this.loadAndRenderMemberScales();
    },

    async openQuickStandbyModal() {
        let optionsHtml = '<option value="Qualquer:Qualquer">Qualquer um / Deixar em aberto</option>';
        for (const [key, sector] of Object.entries(this.sectorsData)) {
            sector.funcoes.forEach(fun => {
                optionsHtml += `<option value="${key}:${fun}">${sector.nome} - ${fun}</option>`;
            });
        }

        const html = `
            <div style="text-align: left; display: flex; flex-direction: column; gap: 15px;">
                <p style="font-size: 0.82rem; color: #8aa6a3; margin: 0 0 10px 0;">Selecione o setor em que deseja trabalhar no próximo culto. Se preferir não escolher, selecione "Qualquer um / Deixar em aberto".</p>
                
                <div style="display: flex; flex-direction: column; gap: 5px;">
                    <label style="font-size: 0.72rem; color: #8aa6a3; font-weight: 700; text-transform: uppercase;">Setor / Função:</label>
                    <select id="quick-standby-sector" style="width: 100%; height: 42px; border-radius: 12px; background: rgba(15, 23, 42, 0.8); border: 1px solid rgba(255,255,255,0.08); color: #fff; padding: 0 10px; font-size: 0.85rem; outline: none; cursor: pointer;">
                        ${optionsHtml}
                    </select>
                </div>
                
                <div style="display: flex; gap: 10px; margin-top: 15px;">
                    <button class="btn-primary" onclick="App.handleQuickRegisterStandby()" style="flex: 1; height: 44px; border-radius: 12px; background: var(--theme-color); color: #fff; border: none; font-weight: 700; font-size: 0.88rem; cursor: pointer; text-transform: uppercase;">Confirmar</button>
                    <button class="btn-secondary" onclick="App.closeAlert()" style="width: 90px; height: 44px; border-radius: 12px; border: 1px solid rgba(255,255,255,0.1); background: transparent; color: #fff; font-weight: 600; font-size: 0.85rem; cursor: pointer;">Cancelar</button>
                </div>
            </div>
        `;
        this.showAlert(html, 'Disponibilidade de Voluntário');
    },

    async handleQuickRegisterStandby() {
        const selector = document.getElementById('quick-standby-sector');
        if (!selector) return;
        const value = selector.value;
        const [setorId, func] = value.split(':');
        
        const now = new Date();
        const tzOffset = now.getTimezoneOffset() * 60000;
        const hojeStr = new Date(Date.now() - tzOffset).toISOString().split('T')[0];
        
        try {
            App.showLoading();
            const cultos = await DbService.getCultos();
            const futureCultos = cultos.filter(c => c.data >= hojeStr);
            if (futureCultos.length === 0) {
                App.hideLoading();
                App.showToast('Nenhum culto futuro encontrado para se candidatar.', 'warning');
                return;
            }
            const nextCulto = futureCultos[0];
            
            App.closeAlert();
            
            let nodeId = 'recepcao';
            const funcLower = func.toLowerCase();
            if (funcLower.includes('acolhimento')) {
                nodeId = 'acolhimento';
            } else if (funcLower.includes('apoio') || funcLower.includes('ronda')) {
                nodeId = 'templo';
            }
            
            this.activeSectorId = setorId === 'Qualquer' ? 'entrada' : setorId;
            
            await this.handleRegisterStandby(
                nextCulto.id,
                nextCulto.nome,
                nextCulto.data,
                `${nextCulto.horarioInicio} - ${nextCulto.horarioFim}`,
                nodeId
            );
        } catch(err) {
            App.hideLoading();
            console.error(err);
            App.showToast('Erro ao registrar voluntariado.', 'danger');
        }
    },

    // --- AUTO SCALING ASSISTANT SYSTEM (DIRECT IA GENERATOR) ---
    async openAutoGeneratorWizard() {
        const c = this.cultosData.find(item => item.id === this.adminSelectedCultoId);
        if (!c) return;

        const model = c.modeloEscala || 'Manter Existente';
        if (model === 'Manter Existente') {
            this.showAlert("Este culto está configurado como 'Manter Existente'. Mude o Modelo de Escala nas propriedades do culto para permitir geração automática.");
            return;
        }

        try {
            App.showLoading();
            await this.runAutoScaleAndPublish(c);
            App.hideLoading();
            this.showToast("Escala gerada e publicada com sucesso pela I.A!", "success");
            this.loadAdminEscalas();
        } catch(e) {
            App.hideLoading();
            console.error(e);
            this.showAlert("Erro ao processar e salvar a escala automática.");
        }
    },

    async normalizarEscalasDuplicadas() {
        const c = this.cultosData.find(item => item.id === this.adminSelectedCultoId);
        if (!c) return;

        const confirmText = "Esta operação irá remover apenas escalas automáticas duplicadas deste culto.\n\nEscalas adicionadas manualmente permanecerão intactas.\n\nDeseja continuar?";
        if (!confirm(confirmText)) return;

        App.showLoading();
        try {
            const model = c.modeloEscala || 'Manter Existente';
            const escalas = await DbService.getEscalas();
            const membros = await DbService.getMembros();
            const escalasDoCulto = escalas.filter(e => e.cultoId === c.id);

            let baseBlueprint = [];
            if (model === 'Culto Completo') {
                baseBlueprint = [
                    { setorId: 'entrada', funcao: 'Portaria' },
                    { setorId: 'check_in', funcao: 'Check-in' },
                    { setorId: 'apoio_templo_ronda_dir', funcao: 'Apoio Templo / Ronda Lado Direito', sexoExigido: 'Masculino' },
                    { setorId: 'apoio_templo_ronda_dir', funcao: 'Apoio Templo / Ronda Lado Direito', sexoExigido: 'Feminino' },
                    { setorId: 'apoio_templo_ronda_esq', funcao: 'Apoio Templo / Ronda Lado Esquerdo', sexoExigido: 'Masculino' },
                    { setorId: 'apoio_templo_ronda_esq', funcao: 'Apoio Templo / Ronda Lado Esquerdo', sexoExigido: 'Feminino' },
                    { setorId: 'acolhimento', funcao: 'Conduzir ao Acolhimento' },
                    { setorId: 'acolhimento', funcao: 'Recepcionar' },
                    { setorId: 'acolhimento', funcao: 'Servir' }
                ];
            } else if (model === 'Culto Menor') {
                baseBlueprint = [
                    { setorId: 'check_in', funcao: 'Check-in' },
                    { setorId: 'acolhimento', funcao: 'Acolhimento' }
                ];
            } else if (model === 'Personalizado') {
                baseBlueprint = c.funcoesPersonalizadas || [
                    { setorId: 'entrada', funcao: 'Entrada' },
                    { setorId: 'check_in', funcao: 'Check-in' },
                    { setorId: 'acolhimento', funcao: 'Acolhimento' }
                ];
            } else if (model === 'Escala Livre') {
                const numVagas = c.vagasEscalaLivre || 2;
                for (let i = 0; i < numVagas; i++) {
                    baseBlueprint.push({ setorId: 'escala_livre', funcao: 'Escala Livre' });
                }
            }

            let usedEscalaIds = new Set();

            for (let bp of baseBlueprint) {
                let matched = null;
                
                if (bp.sexoExigido) {
                    matched = escalasDoCulto.find(e => {
                        if (usedEscalaIds.has(e.id)) return false;
                        if (e.setorId !== bp.setorId || e.funcao !== bp.funcao) return false;
                        if (e.membroId && e.membroNome !== 'Vaga Pendente' && e.statusPresenca !== 'Recusado' && e.statusPresenca !== 'Recusada') {
                            const mInfo = membros.find(m => m.id === e.membroId);
                            const sexo = mInfo ? (mInfo.sexo || 'Masculino') : 'Masculino';
                            return sexo === bp.sexoExigido;
                        }
                        return false;
                    });
                }

                if (!matched) {
                    matched = escalasDoCulto.find(e => {
                        if (usedEscalaIds.has(e.id)) return false;
                        if (e.setorId !== bp.setorId || e.funcao !== bp.funcao) return false;
                        
                        const isEmpty = !e.membroId || e.membroNome === 'Vaga Pendente' || e.statusPresenca === 'Recusado' || e.statusPresenca === 'Recusada';
                        if (!isEmpty) {
                            if (bp.sexoExigido) return false; 
                            return true; 
                        }
                        return true;
                    });
                }

                if (matched) {
                    usedEscalaIds.add(matched.id);
                }
            }

            const blueprintFunctions = new Set(baseBlueprint.map(bp => bp.funcao));
            let deletedCount = 0;
            
            for (let e of escalasDoCulto) {
                if (!usedEscalaIds.has(e.id)) {
                    if (blueprintFunctions.has(e.funcao)) {
                        await DbService.deleteEscala(e.id);
                        deletedCount++;
                    }
                }
            }

            App.hideLoading();
            
            if (deletedCount > 0) {
                alert(`Normalização concluída.\nForam removidas ${deletedCount} escalas automáticas duplicadas.`);
                this.loadAdminEscalas();
            } else {
                alert('Normalização concluída.\nNão foram encontradas escalas duplicadas para este culto.');
            }

        } catch(e) {
            App.hideLoading();
            console.error(e);
            this.showAlert("Erro ao processar a normalização das escalas.");
        }
    },

    async runAutoScaleAndPublish(culto) {
        const model = culto.modeloEscala;
        const membros = await DbService.getMembros();
        const escalas = await DbService.getEscalas();

        const scheduledMemberIds = new Set();
        const escalasDoCulto = escalas.filter(e => e.cultoId === culto.id);

        let baseBlueprint = [];
        
        if (model === 'Culto Completo') {
            baseBlueprint = [
                { setorId: 'entrada', funcao: 'Portaria' },
                { setorId: 'check_in', funcao: 'Check-in' },
                { setorId: 'apoio_templo_ronda_dir', funcao: 'Apoio Templo / Ronda Lado Direito', sexoExigido: 'Masculino' },
                { setorId: 'apoio_templo_ronda_dir', funcao: 'Apoio Templo / Ronda Lado Direito', sexoExigido: 'Feminino' },
                { setorId: 'apoio_templo_ronda_esq', funcao: 'Apoio Templo / Ronda Lado Esquerdo', sexoExigido: 'Masculino' },
                { setorId: 'apoio_templo_ronda_esq', funcao: 'Apoio Templo / Ronda Lado Esquerdo', sexoExigido: 'Feminino' },
                { setorId: 'acolhimento', funcao: 'Conduzir ao Acolhimento' },
                { setorId: 'acolhimento', funcao: 'Recepcionar' },
                { setorId: 'acolhimento', funcao: 'Servir' }
            ];
        } else if (model === 'Culto Menor') {
            baseBlueprint = [
                { setorId: 'check_in', funcao: 'Check-in' },
                { setorId: 'acolhimento', funcao: 'Acolhimento' }
            ];
        } else if (model === 'Personalizado') {
            baseBlueprint = culto.funcoesPersonalizadas || [
                { setorId: 'entrada', funcao: 'Entrada' },
                { setorId: 'check_in', funcao: 'Check-in' },
                { setorId: 'acolhimento', funcao: 'Acolhimento' }
            ];
        } else if (model === 'Escala Livre') {
            const numVagas = culto.vagasEscalaLivre || 2;
            for (let i = 0; i < numVagas; i++) {
                baseBlueprint.push({ setorId: 'escala_livre', funcao: 'Escala Livre' });
            }
        }

        // Registrar todos os membros validos ja escalados no culto
        escalasDoCulto.forEach(e => {
            if (e.membroId && e.membroNome !== 'Vaga Pendente' && e.statusPresenca !== 'Recusado' && e.statusPresenca !== 'Recusada') {
                scheduledMemberIds.add(e.membroId);
            }
        });

        // 1. MAPEAMENTO IDEMPOTENTE E DEDUPLICAÇÃO
        let usedEscalaIds = new Set();
        let matchedSlots = [];

        for (let bp of baseBlueprint) {
            let matched = null;
            
            // Prioridade 1: Tentar casar com escala existente que tenha membro do sexo exigido
            if (bp.sexoExigido) {
                matched = escalasDoCulto.find(e => {
                    if (usedEscalaIds.has(e.id)) return false;
                    if (e.setorId !== bp.setorId || e.funcao !== bp.funcao) return false;
                    if (e.membroId && e.membroNome !== 'Vaga Pendente' && e.statusPresenca !== 'Recusado' && e.statusPresenca !== 'Recusada') {
                        const mInfo = membros.find(m => m.id === e.membroId);
                        const sexo = mInfo ? (mInfo.sexo || 'Masculino') : 'Masculino';
                        return sexo === bp.sexoExigido;
                    }
                    return false;
                });
            }

            // Prioridade 2: Tentar casar com escala existente vazia/pendente (ou que não tenha conflito de sexo)
            if (!matched) {
                matched = escalasDoCulto.find(e => {
                    if (usedEscalaIds.has(e.id)) return false;
                    if (e.setorId !== bp.setorId || e.funcao !== bp.funcao) return false;
                    
                    const isEmpty = !e.membroId || e.membroNome === 'Vaga Pendente' || e.statusPresenca === 'Recusado' || e.statusPresenca === 'Recusada';
                    if (!isEmpty) {
                        if (bp.sexoExigido) return false; // Falhou na prioridade 1, não serve para essa vaga de sexo especifico
                        return true; 
                    }
                    return true;
                });
            }

            if (matched) {
                usedEscalaIds.add(matched.id);
                const isFilled = matched.membroId && matched.membroNome !== 'Vaga Pendente' && matched.statusPresenca !== 'Recusado' && matched.statusPresenca !== 'Recusada';
                matchedSlots.push({
                    id: matched.id,
                    setorId: bp.setorId,
                    funcao: bp.funcao,
                    sexoExigido: bp.sexoExigido,
                    alreadyFilled: isFilled
                });
            } else {
                matchedSlots.push({
                    id: null,
                    setorId: bp.setorId,
                    funcao: bp.funcao,
                    sexoExigido: bp.sexoExigido,
                    alreadyFilled: false
                });
            }
        }
        // 2. FILTRAR SOMENTE VAGAS PENDENTES PARA A IA
        let slots = matchedSlots.filter(s => !s.alreadyFilled);

        if (slots.length === 0) {
            alert('A escala automática já está completa e distribuída. Não há vagas pendentes para gerar.');
            return;
        }

        let isEditingExisting = escalasDoCulto.length > 0;

        // Mapear último serviço de cada membro
        const lastScaledMap = {};
        escalas.forEach(e => {
            if (e.membroId && e.statusPresenca === 'Confirmada') {
                if (!lastScaledMap[e.membroId] || e.data > lastScaledMap[e.membroId]) {
                    lastScaledMap[e.membroId] = e.data;
                }
            }
        });

        // Calcular domingo anterior relativo à data do culto
        const getPreviousSundayStr = (dateStr) => {
            const d = new Date(dateStr + 'T12:00:00');
            const day = d.getDay();
            const daysToSubtract = day === 0 ? 7 : day;
            const prevSunday = new Date(d.getTime() - daysToSubtract * 24 * 60 * 60 * 1000);
            const yyyy = prevSunday.getFullYear();
            const mm = String(prevSunday.getMonth() + 1).padStart(2, '0');
            const dd = String(prevSunday.getDate()).padStart(2, '0');
            return `${yyyy}-${mm}-${dd}`;
        };
        const prevSundayStr = getPreviousSundayStr(culto.data);

        // Mapear membros escalados no domingo anterior
        const membersOnPrevSunday = new Set();
        escalas.forEach(e => {
            if (e.data === prevSundayStr && e.membroId && e.statusPresenca !== 'Recusado' && e.statusPresenca !== 'Recusada') {
                membersOnPrevSunday.add(e.membroId);
            }
        });

        // Mapear membros escalados na mesma data em outros cultos
        const membersScaledOnSameDate = new Set();
        escalas.forEach(e => {
            if (e.data === culto.data && e.cultoId !== culto.id && e.membroId && e.statusPresenca !== 'Recusado' && e.statusPresenca !== 'Recusada') {
                membersScaledOnSameDate.add(e.membroId);
            }
        });

        const assignments = [];

        for (let slot of slots) {
            let eligible = membros.filter(m => {
                if (m.perfil === 'admin') return false;
                if (m.status !== 'ativo') return false;
                
                // Excluir de escala automática se precisar consultar primeiro
                const mDisp = (m.disponibilidade || '').toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
                if (mDisp.includes('consultar primeiro')) return false;
                
                if (!App.isMembroDisponivel(m, culto.data, culto.horarioInicio)) return false;
                if (scheduledMemberIds.has(m.id)) return false;

                // Bypass setor e funcao se for Escala Livre
                if (slot.setorId === 'escala_livre') {
                    return true;
                }
                
                const mSectors = m.setores || (m.setor ? [m.setor] : []);
                if (!mSectors.includes(slot.setorId)) return false;

                const fPrincipal = (m.funcaoPrincipal || '').toLowerCase().trim();
                const fSecundaria = (m.funcaoSecundaria || '').toLowerCase().trim();
                const fSlot = slot.funcao.toLowerCase().trim();
                
                const principalMatch = fPrincipal && (fPrincipal.includes(fSlot) || fSlot.includes(fPrincipal));
                const secundariaMatch = fSecundaria && (fSecundaria.includes(fSlot) || fSlot.includes(fSecundaria));
                
                const isAcolhimentoBypass = slot.setorId === 'acolhimento' && 
                    (fPrincipal.includes('acolhimento') || fSecundaria.includes('acolhimento'));
                const isPortariaBypass = slot.setorId === 'entrada' && 
                    (fPrincipal.includes('portaria') || fPrincipal.includes('entrada') || 
                     fSecundaria.includes('portaria') || fSecundaria.includes('entrada'));
                
                return principalMatch || secundariaMatch || isAcolhimentoBypass || isPortariaBypass;
            });

            // Evitar obreiros que já estão escalados na mesma data em outros cultos, a menos que queiram servir sempre
            let sameDateEligible = eligible.filter(m => {
                const wasOnSameDate = membersScaledOnSameDate.has(m.id);
                if (!wasOnSameDate) return true;

                const mDisp = (m.disponibilidade || '').toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
                const mObs = (m.funcao || '').toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
                const querTodoCulto = mDisp.includes('todos cultos') || mDisp.includes('todo culto') || mDisp.includes('dias de culto') ||
                                      mObs.includes('todos cultos') || mObs.includes('todo culto') || mObs.includes('dias de culto');
                return querTodoCulto;
            });

            if (sameDateEligible.length > 0) {
                eligible = sameDateEligible;
            }

            // Evitar obreiros que serviram no domingo anterior, a menos que queiram servir sempre (Disponibilidade Geral ou Função / Obs)
            let primaryEligible = eligible.filter(m => {
                const wasOnPrevSunday = membersOnPrevSunday.has(m.id);
                if (!wasOnPrevSunday) return true;

                const mDisp = (m.disponibilidade || '').toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
                const mObs = (m.funcao || '').toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
                const querTodoCulto = mDisp.includes('todos cultos') || mDisp.includes('todo culto') || mDisp.includes('dias de culto') ||
                                      mObs.includes('todos cultos') || mObs.includes('todo culto') || mObs.includes('dias de culto');
                return querTodoCulto;
            });

            if (primaryEligible.length > 0) {
                eligible = primaryEligible;
            }

            // Regra de Gênero Explícita
            if (slot.sexoExigido) {
                eligible = eligible.filter(m => m.sexo === slot.sexoExigido);
            }

            // Calcular score
            const candidatesWithScore = eligible.map(m => {
                let rodizioPontos = 40;
                if (lastScaledMap[m.id]) {
                    const diffTime = Math.abs(new Date(culto.data) - new Date(lastScaledMap[m.id]));
                    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
                    rodizioPontos = diffDays >= 30 ? 40 : (diffDays / 30) * 40;
                }

                const mEscalas = escalas.filter(e => e.membroId === m.id);
                const scoreObj = DbService.calcularScoreConfiabilidade(mEscalas);
                let scoreConfiabilidadePoints = 22.5;
                if (!scoreObj.emAvaliacao) {
                    scoreConfiabilidadePoints = (scoreObj.score / 100) * 30;
                }

                let funcaoPontos = 10;
                if ((m.funcaoPrincipal || '').toLowerCase().trim().includes(slot.funcao.toLowerCase().trim())) {
                    funcaoPontos = 20;
                }

                let penalidades = 0;
                if (m.indisponibilidades_mensais && m.indisponibilidades_mensais[culto.data]) {
                    const indState = m.indisponibilidades_mensais[culto.data];
                    if (indState === 'pode_restricao' || indState === 'preferia_nao') {
                        penalidades = 15;
                    }
                }

                const totalScore = Math.max(0, rodizioPontos + scoreConfiabilidadePoints + funcaoPontos + 10 - penalidades);

                return {
                    member: m,
                    score: totalScore
                };
            });

            // Ordenação por rodízio justo (nunca serviu primeiro, depois quem serviu há mais tempo, desempate por score)
            candidatesWithScore.sort((a, b) => {
                const hasA = !!lastScaledMap[a.member.id];
                const hasB = !!lastScaledMap[b.member.id];
                if (!hasA && hasB) return -1;
                if (hasA && !hasB) return 1;

                if (hasA && hasB) {
                    const dateA = lastScaledMap[a.member.id];
                    const dateB = lastScaledMap[b.member.id];
                    if (dateA !== dateB) {
                        return dateA.localeCompare(dateB);
                    }
                }

                return b.score - a.score;
            });

            if (candidatesWithScore.length > 0) {
                const best = candidatesWithScore[0];
                const chosen = best.member;
                scheduledMemberIds.add(chosen.id);

                assignments.push({
                    id: slot.id || null,
                    setorId: slot.setorId,
                    funcao: slot.funcao,
                    membroId: chosen.id,
                    membroNome: chosen.nome,
                    sexo: chosen.sexo || 'Masculino'
                });
            } else {
                assignments.push({
                    id: slot.id || null,
                    setorId: slot.setorId,
                    funcao: slot.funcao,
                    membroId: '',
                    membroNome: 'Vaga Pendente',
                    sexo: '-'
                });
            }
        }

        // Salvar ou atualizar escalas no Firestore
        for (let item of assignments) {
            const escalaPayload = {
                origem: 'ia',
                cultoId: culto.id,
                cultoNome: culto.nome,
                data: culto.data,
                horarioInicio: culto.horarioInicio,
                horarioFim: culto.horarioFim,
                setorId: item.setorId,
                funcao: item.funcao,
                membroId: item.membroId,
                membroNome: item.membroNome,
                statusPresenca: 'Pendente',
                statusServico: 'Planejado'
            };
            if (!item.membroId) {
                escalaPayload.observacoes = "🚨 Sem substituto disponível na fila de rodízio. Sob responsabilidade da Supervisão.";
            } else {
                escalaPayload.observacoes = "";
            }

            if (isEditingExisting && item.id) {
                await DbService.saveEscala(item.id, escalaPayload);
            } else {
                await DbService.saveEscala(null, escalaPayload);
            }
        }
    },

    // --- AUTOMATIC PREDICTIVE SUBSTITUTION ---
    async tentarSubstituicaoAutomatica(escalaId) {
        try {
            console.log(`Iniciando algoritmo de substituição preditiva para escala: ${escalaId}`);
            const escalas = await DbService.getEscalas();
            const escalaRefused = escalas.find(e => e.id === escalaId);
            if (!escalaRefused) return;

            const membros = await DbService.getMembros();
            const refusedMemberId = escalaRefused.membroId;
            const refusedMember = membros.find(m => m.id === refusedMemberId);
            const refusedMemberNome = refusedMember ? refusedMember.nome : 'Voluntário';

            // Calcular domingo anterior relativo à data do culto recusado
            const getPreviousSundayStr = (dateStr) => {
                const d = new Date(dateStr + 'T12:00:00');
                const day = d.getDay();
                const daysToSubtract = day === 0 ? 7 : day;
                const prevSunday = new Date(d.getTime() - daysToSubtract * 24 * 60 * 60 * 1000);
                const yyyy = prevSunday.getFullYear();
                const mm = String(prevSunday.getMonth() + 1).padStart(2, '0');
                const dd = String(prevSunday.getDate()).padStart(2, '0');
                return `${yyyy}-${mm}-${dd}`;
            };
            const prevSundayStr = getPreviousSundayStr(escalaRefused.data);

            // Mapear membros escalados no domingo anterior
            const membersOnPrevSunday = new Set();
            escalas.forEach(e => {
                if (e.data === prevSundayStr && e.membroId && e.statusPresenca !== 'Recusado' && e.statusPresenca !== 'Recusada') {
                    membersOnPrevSunday.add(e.membroId);
                }
            });

            // 1. Filtrar membros elegíveis disponíveis
            let eligible = membros.filter(m => {
                if (m.perfil === 'admin') return false;
                if (m.status !== 'ativo') return false;
                
                // Excluir de escala automática se precisar consultar primeiro
                const mDisp = (m.disponibilidade || '').toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
                if (mDisp.includes('consultar primeiro')) return false;

                if (m.id === refusedMemberId) return false;
                if ((m.participaSubstituicao || 'Sim') !== 'Sim') return false;

                if (!App.isMembroDisponivel(m, escalaRefused.data, escalaRefused.horarioInicio)) return false;

                // Bypass setor e funcao se for Escala Livre
                if (escalaRefused.setorId === 'escala_livre') {
                    return true;
                }

                const mSectors = m.setores || (m.setor ? [m.setor] : []);
                if (!mSectors.includes(escalaRefused.setorId)) return false;

                const fPrincipal = (m.funcaoPrincipal || '').toLowerCase().trim();
                const fSecundaria = (m.funcaoSecundaria || '').toLowerCase().trim();
                const fSlot = escalaRefused.funcao.toLowerCase().trim();
                
                const principalMatch = fPrincipal && (fPrincipal.includes(fSlot) || fSlot.includes(fPrincipal));
                const secundariaMatch = fSecundaria && (fSecundaria.includes(fSlot) || fSlot.includes(fSecundaria));
                return principalMatch || secundariaMatch;
            });

            // Evitar obreiros que serviram no domingo anterior, a menos que queiram servir sempre (Disponibilidade Geral ou Função / Obs)
            let primaryEligible = eligible.filter(m => {
                const wasOnPrevSunday = membersOnPrevSunday.has(m.id);
                if (!wasOnPrevSunday) return true;

                const mDisp = (m.disponibilidade || '').toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
                const mObs = (m.funcao || '').toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
                const querTodoCulto = mDisp.includes('todos cultos') || mDisp.includes('todo culto') || mDisp.includes('dias de culto') ||
                                      mObs.includes('todos cultos') || mObs.includes('todo culto') || mObs.includes('dias de culto');
                return querTodoCulto;
            });

            if (primaryEligible.length > 0) {
                eligible = primaryEligible;
            }

            // Aplica regra de gênero na substituição se necessário (apenas em Entrada, Recepção, Apoio Interno)
            const needsGenderCheck = ['entrada', 'recep', 'apoio'].some(x => escalaRefused.funcao.toLowerCase().includes(x));
            if (needsGenderCheck) {
                // Encontrar todas as OUTRAS escalas para esta função no mesmo culto
                const sameCultoScales = escalas.filter(e => e.cultoId === escalaRefused.cultoId && e.id !== escalaId && e.funcao.toLowerCase().trim() === escalaRefused.funcao.toLowerCase().trim() && e.membroId && e.statusPresenca !== 'Recusado' && e.statusPresenca !== 'Recusada');
                if (sameCultoScales.length > 0) {
                    // Verificar o sexo de quem já está escalado
                    const assignedSexes = sameCultoScales.map(s => {
                        const mInfo = membros.find(m => m.id === s.membroId);
                        return mInfo ? (mInfo.sexo || 'Masculino') : 'Masculino';
                    });
                    
                    if (assignedSexes.includes('Masculino') && !assignedSexes.includes('Feminino')) {
                        const femEligible = eligible.filter(m => m.sexo === 'Feminino');
                        if (femEligible.length > 0) eligible = femEligible;
                    } else if (assignedSexes.includes('Feminino') && !assignedSexes.includes('Masculino')) {
                        const mascEligible = eligible.filter(m => m.sexo === 'Masculino');
                        if (mascEligible.length > 0) eligible = mascEligible;
                    }
                }
            }

            // 2. Calcular scores e ordenar
            const lastScaledMap = {};
            escalas.forEach(e => {
                if (e.membroId && e.statusPresenca === 'Confirmada') {
                    if (!lastScaledMap[e.membroId] || e.data > lastScaledMap[e.membroId]) {
                        lastScaledMap[e.membroId] = e.data;
                    }
                }
            });

            const candidatesWithScore = eligible.map(m => {
                let rodizioPontos = 40;
                if (lastScaledMap[m.id]) {
                    const diffDays = Math.ceil(Math.abs(new Date(escalaRefused.data) - new Date(lastScaledMap[m.id])) / (1000 * 60 * 60 * 24));
                    rodizioPontos = diffDays >= 30 ? 40 : (diffDays / 30) * 40;
                }
                const mEscalas = escalas.filter(e => e.membroId === m.id);
                const scoreObj = DbService.calcularScoreConfiabilidade(mEscalas);
                let scoreConfiabilidadePoints = scoreObj.emAvaliacao ? 22.5 : (scoreObj.score / 100) * 30;
                let funcaoPontos = (m.funcaoPrincipal || '').toLowerCase().includes(escalaRefused.funcao.toLowerCase()) ? 20 : 10;
                
                return {
                    member: m,
                    score: rodizioPontos + scoreConfiabilidadePoints + funcaoPontos + 10
                };
            });

            // Ordenação por rodízio justo (nunca serviu primeiro, depois quem serviu há mais tempo, desempate por score)
            candidatesWithScore.sort((a, b) => {
                const hasA = !!lastScaledMap[a.member.id];
                const hasB = !!lastScaledMap[b.member.id];
                if (!hasA && hasB) return -1;
                if (hasA && !hasB) return 1;

                if (hasA && hasB) {
                    const dateA = lastScaledMap[a.member.id];
                    const dateB = lastScaledMap[b.member.id];
                    if (dateA !== dateB) {
                        return dateA.localeCompare(dateB);
                    }
                }

                return b.score - a.score;
            });

            if (candidatesWithScore.length > 0) {
                const substitute = candidatesWithScore[0].member;

                escalaRefused.membroId = substitute.id;
                escalaRefused.membroNome = substitute.nome;
                escalaRefused.statusPresenca = 'Pendente';
                escalaRefused.statusServico = 'Planejado';
                
                await DbService.saveEscala(escalaId, escalaRefused);

                const logPayload = {
                    escalaId,
                    cultoId: escalaRefused.cultoId,
                    cultoNome: escalaRefused.cultoNome,
                    data: escalaRefused.data,
                    funcao: escalaRefused.funcao,
                    membroSaindoId: refusedMemberId,
                    membroSaindoNome: refusedMemberNome,
                    membroEntrandoId: substitute.id,
                    membroEntrandoNome: substitute.nome,
                    motivo: "Substituição preditiva automática Fase 2.1",
                    dataHora: new Date().toISOString()
                };
                await DbService.addSubstituicaoLog(logPayload);

                await DbService.addNotificacao({
                    paraUsuarioId: 'admin_default',
                    paraUsuarioNome: 'Supervisor Geral',
                    titulo: 'Substituição Automática Efetuada',
                    mensagem: `Escala de ${refusedMemberNome} para ${escalaRefused.funcao} foi assumida automaticamente por ${substitute.nome}.`,
                    tipo: 'sistema'
                });

                this.showToast(`Substituição automática efetuada. ${substitute.nome} assumiu a escala!`, 'success');
            } else {
                escalaRefused.membroId = '';
                escalaRefused.membroNome = 'Vaga Pendente';
                escalaRefused.statusPresenca = 'Pendente';
                escalaRefused.statusServico = 'Planejado';
                escalaRefused.observacoes = "🚨 Sem substituto disponível na fila de rodízio. Sob responsabilidade da Supervisão.";
                
                await DbService.saveEscala(escalaId, escalaRefused);

                const logPayload = {
                    escalaId,
                    cultoId: escalaRefused.cultoId,
                    cultoNome: escalaRefused.cultoNome,
                    data: escalaRefused.data,
                    funcao: escalaRefused.funcao,
                    membroSaindoId: refusedMemberId,
                    membroSaindoNome: refusedMemberNome,
                    membroEntrandoId: '',
                    membroEntrandoNome: 'Nenhum Substituto Disponível',
                    motivo: "Sem voluntários elegíveis livres para substituição",
                    dataHora: new Date().toISOString()
                };
                await DbService.addSubstituicaoLog(logPayload);

                await DbService.addNotificacao({
                    paraUsuarioId: 'admin_default',
                    paraUsuarioNome: 'Supervisor Geral',
                    titulo: 'Substituição Falhou - Vaga Aberta',
                    mensagem: `A escala de ${refusedMemberNome} para ${escalaRefused.funcao} está vaga. Nenhum voluntário elegível disponível.`,
                    tipo: 'alerta'
                });

                this.showToast("Substituição automática não encontrou voluntários livres. Vaga ficou em aberto.", "warning");
            }

            this.loadAdminEscalas();
        } catch(e) {
            console.error("Erro na substituição automática:", e);
        }
    },

    // --- HEALTH PANEL & SYSTEM GOVERNANCE ---
    switchReportSubTab(tab) {
        const btnEngagement = document.getElementById('btn-report-engagement');
        const btnRotation = document.getElementById('btn-report-rotation');
        const btnHealth = document.getElementById('btn-report-health');
        const btnBalance = document.getElementById('btn-report-balance');
        
        const secEngagement = document.getElementById('reports-engagement-section');
        const secRotation = document.getElementById('reports-rotation-section');
        const secHealth = document.getElementById('reports-health-section');
        const secBalance = document.getElementById('reports-balance-section');

        if (!btnEngagement || !btnRotation || !btnHealth || !btnBalance || !secEngagement || !secRotation || !secHealth || !secBalance) return;

        // Reset all buttons style
        [btnEngagement, btnRotation, btnHealth, btnBalance].forEach(btn => {
            btn.className = 'btn-secondary';
            btn.style.background = 'transparent';
            btn.style.color = 'var(--navy-dark)';
        });

        // Hide all sections
        secEngagement.style.display = 'none';
        secRotation.style.display = 'none';
        secHealth.style.display = 'none';
        secBalance.style.display = 'none';

        if (tab === 'engagement') {
            btnEngagement.className = 'btn-primary';
            btnEngagement.style.background = 'var(--teal-primary)';
            btnEngagement.style.color = '#fff';
            secEngagement.style.display = 'block';
        } else if (tab === 'rotation') {
            btnRotation.className = 'btn-primary';
            btnRotation.style.background = 'var(--teal-primary)';
            btnRotation.style.color = '#fff';
            secRotation.style.display = 'block';
            this.loadAndRenderRotationMetrics();
        } else if (tab === 'health') {
            btnHealth.className = 'btn-primary';
            btnHealth.style.background = 'var(--teal-primary)';
            btnHealth.style.color = '#fff';
            secHealth.style.display = 'block';
            this.loadAndRenderHealthMetrics();
        } else if (tab === 'balance') {
            btnBalance.className = 'btn-primary';
            btnBalance.style.background = 'var(--teal-primary)';
            btnBalance.style.color = '#fff';
            secBalance.style.display = 'block';
            this.renderDashboardEquilibrio();
        }
    },

    async loadAndRenderRotationMetrics() {
        const container = document.getElementById('rotation-sectors-container');
        if (!container) return;
        
        container.innerHTML = '<div style="text-align:center; padding: 40px;"><i class="fa-solid fa-spinner fa-spin fa-2x" style="color:var(--teal-primary);"></i><p style="margin-top:10px; font-size:0.9rem;">Calculando filas de rodízio por setor...</p></div>';
        
        try {
            const membros = await DbService.getMembros();
            const escalas = await DbService.getEscalas();
            
            // Map members to their last scaled date
            const lastScaledMap = {};
            escalas.forEach(e => {
                if (e.membroId && e.statusPresenca === 'Confirmada') {
                    if (!lastScaledMap[e.membroId] || e.data > lastScaledMap[e.membroId]) {
                        lastScaledMap[e.membroId] = e.data;
                    }
                }
            });
            
            let html = '';
            
            for (const sectorId in this.sectorsData) {
                const sector = this.sectorsData[sectorId];
                
                // Get all active available members belonging to this sector
                let sectorMembers = membros.filter(m => {
                    if (m.perfil === 'admin') return false;
                    if (m.status !== 'ativo') return false;
                    if (m.statusOperacional && m.statusOperacional !== 'Disponível') return false;
                    
                    const mSectors = m.setores || (m.setor ? [m.setor] : []);
                    return mSectors.includes(sectorId);
                });
                
                // Sort by last scaled date: oldest or never scaled first
                sectorMembers.sort((a, b) => {
                    const dateA = lastScaledMap[a.id] || '';
                    const dateB = lastScaledMap[b.id] || '';
                    
                    if (dateA === '' && dateB !== '') return -1;
                    if (dateA !== '' && dateB === '') return 1;
                    if (dateA === '' && dateB === '') return a.nome.localeCompare(b.nome);
                    
                    return dateA.localeCompare(dateB);
                });
                
                let tbodyHtml = '';
                if (sectorMembers.length === 0) {
                    tbodyHtml = '<tr><td colspan="6" style="text-align:center; color: var(--slate-gray); padding: 20px;">Nenhum voluntário cadastrado neste setor.</td></tr>';
                } else {
                    sectorMembers.forEach((m, idx) => {
                        const lastServed = lastScaledMap[m.id] ? lastScaledMap[m.id].split('-').reverse().join('/') : 'Nunca serviu';
                        const lastServedBadge = lastScaledMap[m.id] 
                            ? `<span class="badge" style="background: rgba(30, 41, 59, 0.1); color: var(--navy-dark); font-weight:500;">${lastServed}</span>` 
                            : `<span class="badge" style="background: rgba(16, 185, 129, 0.1); color: #10B981; font-weight:700;">Nunca serviu (Prioridade)</span>`;
                            
                        const functions = [m.funcaoPrincipal, m.funcaoSecundaria].filter(x => !!x).join(', ') || m.funcao || 'Voluntário';
                        
                        const mEscalas = escalas.filter(e => e.membroId === m.id);
                        const reliability = DbService.calcularScoreConfiabilidade(mEscalas);
                        const reliabilityStr = reliability.emAvaliacao ? 'Em avaliação' : `${reliability.score}%`;
                        
                        let queueBadge = `<span style="font-weight:700; color: var(--navy-dark);">${idx + 1}º</span>`;
                        if (idx === 0) {
                            queueBadge = `<span class="badge" style="background: #10B981; color: white; padding: 4px 8px; font-weight:800;">1º (Próximo)</span>`;
                        } else if (idx === 1) {
                            queueBadge = `<span class="badge" style="background: #3B82F6; color: white; padding: 4px 8px; font-weight:700;">2º</span>`;
                        }
                        
                        tbodyHtml += `
                            <tr>
                                <td style="text-align: center; vertical-align: middle;">${queueBadge}</td>
                                <td style="vertical-align: middle;"><b>${m.nome}</b></td>
                                <td style="vertical-align: middle;">${lastServedBadge}</td>
                                <td style="vertical-align: middle;">${functions}</td>
                                <td style="vertical-align: middle; font-size: 0.8rem; color: var(--slate-gray);">${m.disponibilidade || 'Todos'}</td>
                                <td style="vertical-align: middle; font-weight: 600; color: ${reliability.emAvaliacao ? 'var(--slate-gray)' : '#10B981'};">${reliabilityStr}</td>
                            </tr>
                        `;
                    });
                }
                
                html += `
                    <div class="panel-card" style="border: 1px solid var(--border-color); box-shadow: none; margin-bottom: 20px;">
                        <div class="panel-title" style="display:flex; align-items:center; gap:10px; margin-bottom:15px; border-bottom:1px solid var(--border-color); padding-bottom:10px; color:${sector.cor};">
                            <i class="${this.getSectorIcon(sectorId)}"></i> 
                            ${sector.nome} 
                            <span style="font-size:0.8rem; font-weight:normal; color:var(--slate-gray); margin-left:auto;">
                                ${sectorMembers.length} obreiros ativos
                            </span>
                        </div>
                        <div class="table-container" style="box-shadow:none; padding:0;">
                            <table class="admin-table">
                                <thead>
                                    <tr>
                                        <th style="width: 12%; text-align: center;">Posição na Fila</th>
                                        <th style="width: 25%;">Voluntário</th>
                                        <th style="width: 20%;">Último Serviço</th>
                                        <th style="width: 20%;">Função / Capacidade</th>
                                        <th style="width: 13%;">Disponibilidade</th>
                                        <th style="width: 10%;">Confiabilidade</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    ${tbodyHtml}
                                </tbody>
                            </table>
                        </div>
                    </div>
                `;
            }
            
            container.innerHTML = html;
        } catch (e) {
            console.error(e);
            container.innerHTML = '<div style="color:red; text-align:center; padding:20px;">Erro ao gerar filas de rodízio.</div>';
        }
    },

    async loadAndRenderHealthMetrics() {
        try {
            // 1. Métricas do Cache
            const stats = DbService.cacheStats || { leiturasEconomizadas: 0, leiturasReais: 0 };
            const economizadas = stats.leiturasEconomizadas || 0;
            const reais = stats.leiturasReais || 0;
            const totalReads = economizadas + reais;
            const efficiency = totalReads > 0 ? ((economizadas / totalReads) * 100).toFixed(1) : '100.0';
            const lastSyncStr = stats.ultimaAtualizacao ? new Date(stats.ultimaAtualizacao).toLocaleTimeString('pt-BR') : 'Nenhuma';

            document.getElementById('health-reads-saved').innerText = economizadas;
            document.getElementById('health-cache-efficiency').innerText = `${efficiency}%`;
            document.getElementById('health-last-sync').innerText = lastSyncStr;

            // 2. Métricas de Armazenamento
            const metrics = await DbService.getMetricasSaudeSistema();
            document.getElementById('health-doc-membros').innerText = metrics.membrosAtivos;
            document.getElementById('health-doc-escalas-ativas').innerText = metrics.escalasAtivas;
            document.getElementById('health-doc-escalas-arquivadas').innerText = metrics.escalasArquivadas;

            // 3. Último Arquivamento Histórico
            const lastArchive = await DbService.getUltimoArquivamento();
            if (lastArchive && lastArchive.executadoEm) {
                const dateStr = new Date(lastArchive.executadoEm).toLocaleDateString('pt-BR');
                document.getElementById('health-last-archive').innerText = `${dateStr} (${lastArchive.total} docs)`;
            } else {
                document.getElementById('health-last-archive').innerText = 'Nunca';
            }
        } catch (e) {
            console.error('Erro ao renderizar métricas de saúde:', e);
        }
    },

    async handleManualArchiving() {
        if (!confirm("Deseja realmente iniciar a rotina de arquivamento histórico manual? Escalas com mais de 14 meses serão transferidas com segurança.")) {
            return;
        }

        try {
            App.showLoading();
            const total = await DbService.arquivarDadosHistoricos();
            App.hideLoading();
            
            this.showToast(`Arquivamento histórico concluído! ${total} escalas foram movidas para o arquivo seguro.`, 'success');
            this.loadAndRenderHealthMetrics();
        } catch (e) {
            App.hideLoading();
            console.error(e);
            this.showAlert("Erro ao processar arquivamento manual.");
        }
    },

    toggleAfastamentoDatesFields(statusOp) {
        const fields = document.getElementById('afastamento-dates-fields');
        if (!fields) return;
        if (!statusOp || statusOp === 'Disponível') {
            fields.style.display = 'none';
            document.getElementById('membro-afastamento-inicio').required = false;
            document.getElementById('membro-afastamento-fim').required = false;
            document.getElementById('membro-afastamento-motivo').required = false;
        } else {
            fields.style.display = 'flex';
            document.getElementById('membro-afastamento-inicio').required = true;
            document.getElementById('membro-afastamento-fim').required = true;
            document.getElementById('membro-afastamento-motivo').required = true;
        }
    },

    openAfastamentoRapidoModal(membroId, membroNome) {
        document.getElementById('afastamento-rapido-membro-id').value = membroId;
        document.getElementById('afastamento-rapido-membro-nome').innerText = `Afastar Obreiro: ${membroNome}`;
        
        document.getElementById('afastamento-rapido-form').reset();
        
        const hoje = new Date().toISOString().split('T')[0];
        document.getElementById('afastamento-rapido-inicio').value = hoje;
        
        const umaSemana = new Date();
        umaSemana.setDate(umaSemana.getDate() + 7);
        const fim = umaSemana.toISOString().split('T')[0];
        document.getElementById('afastamento-rapido-fim').value = fim;

        document.getElementById('modal-afastamento-rapido').classList.add('active');
    },

    closeAfastamentoRapidoModal() {
        document.getElementById('modal-afastamento-rapido').classList.remove('active');
    },

    async handleAfastamentoRapidoSave() {
        const id = document.getElementById('afastamento-rapido-membro-id').value;
        const statusOperacional = document.getElementById('afastamento-rapido-status').value;
        const afastamentoInicio = document.getElementById('afastamento-rapido-inicio').value;
        const afastamentoFim = document.getElementById('afastamento-rapido-fim').value;
        const afastamentoMotivo = document.getElementById('afastamento-rapido-motivo').value.trim();
        const afastamentoObsSupervisao = document.getElementById('afastamento-rapido-obs').value.trim();
        const afastamentoRetornoAutomativo = document.getElementById('afastamento-rapido-retorno').value;

        if (!statusOperacional || !afastamentoInicio || !afastamentoFim || !afastamentoMotivo) {
            this.showAlert('Por favor, preencha todos os campos obrigatórios.');
            return;
        }

        if (afastamentoFim < afastamentoInicio) {
            this.showAlert('A data final prevista não pode ser anterior à data inicial.');
            return;
        }

        const hojeStr = new Date().toISOString().split('T')[0];
        try {
            const escalas = await DbService.getEscalas();
            const escalasFuturas = escalas.filter(esc => esc.membroId === id && esc.data >= hojeStr);
            if (escalasFuturas.length > 0) {
                const confirmar = confirm(`Atenção: O obreiro possui ${escalasFuturas.length} escala(s) futura(s) agendada(s) (a partir de hoje). Ao confirmar o afastamento, essas escalas precisarão ser revisadas ou substituídas. Deseja continuar?`);
                if (!confirmar) return;
            }
        } catch (err) {
            console.error("Erro ao verificar escalas futuras:", err);
        }

        try {
            await DbService.saveAfastamento(id, {
                statusOperacional,
                afastamentoInicio,
                afastamentoFim,
                afastamentoMotivo,
                afastamentoObsSupervisao,
                afastamentoRetornoAutomativo
            });

            // FASE 2: Remover obreiro de escalas conflitantes futuras no período
            const membros = await DbService.getMembros();
            const m = membros.find(x => x.id === id);
            const membroNome = m ? m.nome : 'Obreiro';
            await this.removerMembroDeEscalasConflitantes(id, membroNome, afastamentoInicio, afastamentoFim, statusOperacional);
            
            this.closeAfastamentoRapidoModal();
            this.showToast('Afastamento registrado com sucesso!', 'success');
            
            this.renderMembrosTable();
            if (this.adminActiveTab === 'afastamentos') {
                this.loadAndRenderAdminAfastamentos();
            }
        } catch (e) {
            this.showAlert('Erro ao registrar afastamento.');
        }
    },

    async checkAndReactivateReturnedMembers() {
        try {
            const membros = await DbService.getMembros();
            const hojeStr = new Date().toISOString().split('T')[0];
            const promises = [];

            membros.forEach(m => {
                if (m.statusOperacional && m.statusOperacional !== 'Disponível') {
                    if (m.afastamentoFim && hojeStr > m.afastamentoFim) {
                        const autoRetorno = m.afastamentoRetornoAutomativo === 'Sim' || m.afastamentoRetornoAutomativo === true || !m.afastamentoRetornoAutomativo;
                        if (autoRetorno) {
                            console.log(`Reativando membro automaticamente: ${m.nome}`);
                            promises.push(DbService.saveMembro(m.id, {
                                statusOperacional: 'Disponível',
                                afastamentoInicio: '',
                                afastamentoFim: '',
                                afastamentoMotivo: '',
                                afastamentoObsSupervisao: '',
                                afastamentoRetornoAutomativo: 'Sim'
                            }));
                        }
                    }
                }
            });

            if (promises.length > 0) {
                await Promise.all(promises);
                console.log(`${promises.length} membro(s) reativado(s) automaticamente.`);
                this.renderMembrosTable();
            }
        } catch (e) {
            console.error("Erro na reativação automática de membros:", e);
        }
    },

    switchAfastamentosFilter(filter) {
        this.activeAfastamentosFilter = filter;
        const btns = { atuais: 'btn-af-atuais', programados: 'btn-af-programados', encerrados: 'btn-af-encerrados' };
        Object.entries(btns).forEach(([key, id]) => {
            const btn = document.getElementById(id);
            if (!btn) return;
            if (key === filter) {
                btn.style.background = 'var(--teal-primary)';
                btn.style.color = 'white';
                btn.style.borderColor = 'transparent';
            } else {
                btn.style.background = 'transparent';
                btn.style.color = 'var(--navy-dark)';
                btn.style.borderColor = '#CBD5E1';
            }
        });

        const mainTable = document.querySelector('#admin-afastamentos-table-body')?.closest('.table-container');
        const histContainer = document.getElementById('admin-afastamentos-historico-container');
        if (mainTable) mainTable.style.display = filter === 'encerrados' ? 'none' : '';
        if (histContainer) histContainer.style.display = filter === 'encerrados' ? '' : 'none';

        this.loadAndRenderAdminAfastamentos();
    },

    async loadAndRenderAdminAfastamentos() {
        const body = document.getElementById('admin-afastamentos-table-body');
        const histBody = document.getElementById('admin-afastamentos-historico-table-body');
        const filter = this.activeAfastamentosFilter || 'atuais';

        if (!body || !histBody) return;

        if (filter !== 'encerrados') {
            body.innerHTML = '<tr><td colspan="8" style="text-align:center;"><i class="fa-solid fa-spinner fa-spin"></i> Carregando...</td></tr>';
        } else {
            histBody.innerHTML = '<tr><td colspan="7" style="text-align:center;"><i class="fa-solid fa-spinner fa-spin"></i> Carregando histórico...</td></tr>';
        }

        try {
            const membros = await DbService.getMembros();
            const hoje = new Date();
            hoje.setHours(0, 0, 0, 0);
            const hojeStr = hoje.toISOString().split('T')[0];

            const parseLocalDate = (dateStr) => {
                if (!dateStr) return null;
                const parts = dateStr.split('-');
                return new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10));
            };

            const opColors = { 'Férias': '#10B981', 'Afastado': '#F59E0B', 'Licença Médica': '#EF4444', 'Viagem / Intercâmbio': '#6366F1', 'Inativo Temporário': '#6B7280' };

            const afastados = membros.filter(m => m.statusOperacional && m.statusOperacional !== 'Disponível');

            // Split into current (started, not yet ended) vs programmed (future start)
            const atuais = afastados.filter(m => {
                if (!m.afastamentoInicio) return true; // no dates = treat as current
                return m.afastamentoInicio <= hojeStr;
            });
            const programados = afastados.filter(m => m.afastamentoInicio && m.afastamentoInicio > hojeStr);

            const renderAfastadoRow = (m) => {
                const cor = opColors[m.statusOperacional] || '#6B7280';
                const badge = `<span style="background:${cor}15; color:${cor}; padding:3px 8px; border-radius:6px; font-size:0.75rem; font-weight:700;">${m.statusOperacional}</span>`;
                const dataInicioFmt = m.afastamentoInicio ? m.afastamentoInicio.split('-').reverse().join('/') : '-';
                const dataFimFmt = m.afastamentoFim ? m.afastamentoFim.split('-').reverse().join('/') : '-';

                let diasRestantesStr = '-';
                if (m.afastamentoFim) {
                    const fim = parseLocalDate(m.afastamentoFim);
                    const diffTime = fim.getTime() - hoje.getTime();
                    const diffDays = Math.round(diffTime / (1000 * 60 * 60 * 24));
                    if (m.afastamentoInicio && m.afastamentoInicio > hojeStr) {
                        const inicio = parseLocalDate(m.afastamentoInicio);
                        const daysUntil = Math.round((inicio.getTime() - hoje.getTime()) / (1000 * 60 * 60 * 24));
                        diasRestantesStr = `<span style="color:#6366F1; font-weight:700;">Inicia em ${daysUntil}d</span>`;
                    } else if (diffDays < 0) {
                        diasRestantesStr = `<span style="color:#EF4444; font-weight:700;">Expirado</span>`;
                    } else if (diffDays === 0) {
                        diasRestantesStr = `<span style="color:#F59E0B; font-weight:700;">Último dia</span>`;
                    } else {
                        diasRestantesStr = `<b>${diffDays}</b> dia(s)`;
                    }
                }

                const reativarBtn = `
                    <button onclick="App.handleManualReactivation('${m.id}')" title="Confirmar Retorno" style="background: transparent; color: #10B981; border: 1px solid #10B981; padding: 5px 10px; border-radius: 6px; font-size: 0.75rem; font-weight: 600; cursor: pointer; display: inline-flex; align-items: center; gap: 4px;">
                        <i class="fa-solid fa-user-check"></i> Confirmar Retorno
                    </button>`;

                const tr = document.createElement('tr');
                tr.innerHTML = `
                    <td><b>${m.nome}</b></td>
                    <td>${badge}</td>
                    <td>${dataInicioFmt}</td>
                    <td>${dataFimFmt}</td>
                    <td>${diasRestantesStr}</td>
                    <td>${m.afastamentoMotivo || '-'}</td>
                    <td style="font-size:0.8rem; color:var(--slate-gray);">${m.afastamentoObsSupervisao || '-'}</td>
                    <td style="text-align:right;">${reativarBtn}</td>
                `;
                return tr;
            };

            if (filter !== 'encerrados') {
                body.innerHTML = '';
                const lista = filter === 'atuais' ? atuais : programados;
                if (lista.length === 0) {
                    const label = filter === 'atuais' ? 'Nenhum membro afastado atualmente.' : 'Nenhum afastamento programado para o futuro.';
                    body.innerHTML = `<tr><td colspan="8" style="text-align:center; color:var(--slate-gray); padding: 30px;">${label}</td></tr>`;
                } else {
                    lista.forEach(m => body.appendChild(renderAfastadoRow(m)));
                }
            } else {
                // Encerrados: load from historico
                histBody.innerHTML = '';
                const historico = await DbService.getHistoricoAfastamentos();
                if (historico.length === 0) {
                    histBody.innerHTML = '<tr><td colspan="7" style="text-align:center; color:var(--slate-gray); padding:30px;">Nenhum histórico registrado.</td></tr>';
                } else {
                    historico.forEach(h => {
                        const cor = opColors[h.statusOperacional] || '#6B7280';
                        const badge = `<span style="background:${cor}15; color:${cor}; padding:2px 6px; border-radius:4px; font-size:0.7rem; font-weight:700;">${h.statusOperacional || 'Afastado'}</span>`;
                        const dataInicioFmt = h.afastamentoInicio ? h.afastamentoInicio.split('-').reverse().join('/') : '-';
                        const dataFimFmt = h.afastamentoFim ? h.afastamentoFim.split('-').reverse().join('/') : '-';
                        let dataRegFmt = '-';
                        if (h.dataRegistro) {
                            try {
                                const dateObj = new Date(h.dataRegistro);
                                const d = String(dateObj.getDate()).padStart(2, '0');
                                const mo = String(dateObj.getMonth() + 1).padStart(2, '0');
                                const y = dateObj.getFullYear();
                                const hr = String(dateObj.getHours()).padStart(2, '0');
                                const min = String(dateObj.getMinutes()).padStart(2, '0');
                                dataRegFmt = `${d}/${mo}/${y} ${hr}:${min}`;
                            } catch (_) { dataRegFmt = h.dataRegistro; }
                        }
                        const tr = document.createElement('tr');
                        tr.innerHTML = `
                            <td><b>${h.membroNome || 'Desconhecido'}</b></td>
                            <td>${badge}</td>
                            <td>${dataInicioFmt}</td>
                            <td>${dataFimFmt}</td>
                            <td>${h.afastamentoMotivo || '-'}</td>
                            <td style="font-size:0.8rem; color:var(--slate-gray);">${h.afastamentoObsSupervisao || '-'}</td>
                            <td>${dataRegFmt}</td>
                        `;
                        histBody.appendChild(tr);
                    });
                }
            }
        } catch (e) {
            console.error('Erro ao carregar painel de afastamentos:', e);
            body.innerHTML = '<tr><td colspan="8" style="color:red; text-align:center;">Erro ao carregar dados.</td></tr>';
            histBody.innerHTML = '<tr><td colspan="7" style="color:red; text-align:center;">Erro ao carregar dados.</td></tr>';
        }
    },

    async handleManualReactivation(membroId) {
        if (confirm('Tem certeza que deseja reativar este obreiro e encerrar o afastamento temporário dele agora?')) {
            try {
                await DbService.saveMembro(membroId, {
                    statusOperacional: 'Disponível',
                    afastamentoInicio: '',
                    afastamentoFim: '',
                    afastamentoMotivo: '',
                    afastamentoObsSupervisao: '',
                    afastamentoRetornoAutomativo: 'Sim'
                });
                this.showToast('Membro reativado com sucesso!', 'success');
                this.renderMembrosTable();
                this.loadAndRenderAdminAfastamentos();
            } catch (e) {
                this.showAlert('Erro ao reativar obreiro.');
            }
        }
    },

    async removerMembroDeEscalasConflitantes(membroId, membroNome, inicio, fim, motivo) {
        try {
            console.log(`Verificando escalas conflitantes para o membro ${membroNome} (${membroId}) entre ${inicio} e ${fim}...`);
            const escalas = await DbService.getEscalas();
            const hojeStr = new Date().toISOString().split('T')[0];
            
            const escalasConflitantes = escalas.filter(esc => {
                return esc.membroId === membroId && 
                       esc.data >= hojeStr && 
                       esc.data >= inicio && 
                       esc.data <= fim;
            });

            if (escalasConflitantes.length === 0) {
                console.log("Nenhuma escala futura conflitante encontrada.");
                return;
            }

            console.log(`Encontradas ${escalasConflitantes.length} escalas conflitantes para remover.`);

            for (const esc of escalasConflitantes) {
                const originalMembroNome = esc.membroNome || membroNome;
                
                // Atualiza a escala limpando os dados de alocação do membro
                esc.membroId = '';
                esc.membroNome = 'Vaga Pendente';
                esc.statusPresenca = 'Pendente';
                
                const obsPrefixo = esc.observacoes ? `${esc.observacoes}\n` : '';
                esc.observacoes = `${obsPrefixo}🚨 Remoção automática: Obreiro afastado temporariamente (${motivo}).`;

                const escalaData = { ...esc };
                delete escalaData.id;
                await DbService.saveEscala(esc.id, escalaData);

                // Registrar o log em historico_substituicoes
                const logPayload = {
                    escalaId: esc.id,
                    cultoId: esc.cultoId || '',
                    cultoNome: esc.cultoNome || '',
                    data: esc.data,
                    funcao: esc.funcao || '',
                    membroSaindoId: membroId,
                    membroSaindoNome: originalMembroNome,
                    membroEntrandoId: '',
                    membroEntrandoNome: 'Vaga Pendente',
                    motivo: `Afastamento temporário: ${motivo}`,
                    dataHora: new Date().toISOString()
                };
                await DbService.addSubstituicaoLog(logPayload);

                // Criar aviso ao admin
                await DbService.addNotificacao({
                    paraUsuarioId: 'admin_default',
                    paraUsuarioNome: 'Supervisor Geral',
                    titulo: 'Vaga Aberta por Afastamento',
                    mensagem: `O obreiro ${originalMembroNome} foi removido da escala de ${esc.funcao || 'Diaconato'} no ${esc.cultoNome || 'Culto'} em ${esc.data.split('-').reverse().join('/')} devido a afastamento (${motivo}).`,
                    tipo: 'alerta'
                });
            }

            this.showToast(`Removido de ${escalasConflitantes.length} escala(s) conflitante(s). Avisos gerados para supervisão.`, 'info');
        } catch (e) {
            console.error("Erro ao remover membro de escalas conflitantes:", e);
        }
    },

    async renderDashboardEquilibrio() {
        const maisEscaladosBody = document.getElementById('equilibrio-mais-escalados-body');
        const menosEscaladosBody = document.getElementById('equilibrio-menos-escalados-body');
        const alertsContainer = document.getElementById('equilibrio-participation-alerts');

        if (!maisEscaladosBody || !menosEscaladosBody || !alertsContainer) return;

        maisEscaladosBody.innerHTML = '<tr><td colspan="3" style="text-align:center;"><i class="fa-solid fa-spinner fa-spin"></i> Carregando...</td></tr>';
        menosEscaladosBody.innerHTML = '<tr><td colspan="3" style="text-align:center;"><i class="fa-solid fa-spinner fa-spin"></i> Carregando...</td></tr>';
        alertsContainer.innerHTML = '';

        try {
            const membros = await DbService.getMembros();
            const escalas = await DbService.getEscalas();

            const availableMembros = membros.filter(m => m.perfil !== 'admin' && m.status === 'ativo' && (!m.statusOperacional || m.statusOperacional === 'Disponível'));

            const memberScaleCounts = {};
            availableMembros.forEach(m => {
                memberScaleCounts[m.id] = 0;
            });

            escalas.forEach(esc => {
                if (esc.membroId && memberScaleCounts[esc.membroId] !== undefined) {
                    memberScaleCounts[esc.membroId]++;
                }
            });

            const list = availableMembros.map(m => {
                let setorNome = '-';
                const mSetores = m.setores || (m.setor ? [m.setor] : []);
                if (mSetores.length > 0) {
                    setorNome = mSetores.map(sId => this.sectorsData[sId]?.nome || sId).join(', ');
                } else {
                    setorNome = 'Sem Setor';
                }

                return {
                    id: m.id,
                    nome: m.nome,
                    setorNome,
                    count: memberScaleCounts[m.id] || 0
                };
            });

            const sortedMais = [...list].sort((a, b) => b.count - a.count);
            const sortedMenos = [...list].sort((a, b) => a.count - b.count);

            maisEscaladosBody.innerHTML = '';
            sortedMais.slice(0, 5).forEach(item => {
                const tr = document.createElement('tr');
                tr.innerHTML = `
                    <td><b>${item.nome}</b></td>
                    <td>${item.setorNome}</td>
                    <td style="text-align: center;"><span class="badge" style="background: rgba(16, 185, 129, 0.1); color: #10B981; font-weight: 700;">${item.count}</span></td>
                `;
                maisEscaladosBody.appendChild(tr);
            });

            menosEscaladosBody.innerHTML = '';
            sortedMenos.slice(0, 5).forEach(item => {
                const tr = document.createElement('tr');
                tr.innerHTML = `
                    <td><b>${item.nome}</b></td>
                    <td>${item.setorNome}</td>
                    <td style="text-align: center;"><span class="badge" style="background: rgba(239, 68, 68, 0.1); color: #EF4444; font-weight: 700;">${item.count}</span></td>
                `;
                menosEscaladosBody.appendChild(tr);
            });

            const lowAlerts = list.filter(item => item.count < 2);
            if (lowAlerts.length === 0) {
                alertsContainer.innerHTML = `
                    <div style="background: rgba(16, 185, 129, 0.08); color: #10B981; border: 1px dashed #10B981; border-radius: 8px; padding: 12px; font-size: 0.85rem; display: flex; align-items: center; gap: 8px;">
                        <i class="fa-solid fa-circle-check"></i>
                        <span>Excelente! Todos os obreiros disponíveis estão participando ativamente das escalas (mínimo de 2 escalas).</span>
                    </div>
                `;
            } else {
                lowAlerts.forEach(item => {
                    const alertDiv = document.createElement('div');
                    alertDiv.style.background = 'rgba(245, 158, 11, 0.08)';
                    alertDiv.style.color = '#F59E0B';
                    alertDiv.style.border = '1px dashed #F59E0B';
                    alertDiv.style.borderRadius = '8px';
                    alertDiv.style.padding = '12px';
                    alertDiv.style.fontSize = '0.85rem';
                    alertDiv.style.display = 'flex';
                    alertDiv.style.alignItems = 'center';
                    alertDiv.style.gap = '8px';

                    if (item.count === 0) {
                        alertDiv.innerHTML = `
                            <i class="fa-solid fa-circle-exclamation" style="color:#EF4444;"></i>
                            <span><b>${item.nome}</b> (${item.setorNome}) está disponível mas <b>nunca foi escalado</b> no sistema.</span>
                        `;
                    } else {
                        alertDiv.innerHTML = `
                            <i class="fa-solid fa-triangle-exclamation"></i>
                            <span><b>${item.nome}</b> (${item.setorNome}) possui baixa participação: apenas <b>${item.count} escala</b> agendada.</span>
                        `;
                    }
                    alertsContainer.appendChild(alertDiv);
                });
            }

        } catch (e) {
            console.error("Erro ao carregar dashboard de equilíbrio:", e);
            maisEscaladosBody.innerHTML = '<tr><td colspan="3" style="color:red; text-align:center;">Erro ao carregar dados.</td></tr>';
            menosEscaladosBody.innerHTML = '<tr><td colspan="3" style="color:red; text-align:center;">Erro ao carregar dados.</td></tr>';
        }
    },

    // --- TAREFAS E ESTOQUE (MODALS JS) ---
    openSolicitarCompraModal() {
        const select = document.getElementById('replenish-product-select');
        if (select) {
            select.innerHTML = '<option value="" disabled selected>Carregando...</option>';
            if (this.allProductsCache) {
                const ativos = this.allProductsCache.filter(p => p.status === 'ativo');
                select.innerHTML = '<option value="" disabled selected>Selecione um produto</option>';
                ativos.forEach(p => {
                    select.innerHTML += `<option value="${p.nome}" data-id="${p.id}">${p.nome}</option>`;
                });
            } else {
                DbService.getProdutos().then(prods => {
                    this.allProductsCache = prods;
                    const ativos = prods.filter(p => p.status === 'ativo');
                    select.innerHTML = '<option value="" disabled selected>Selecione um produto</option>';
                    ativos.forEach(p => {
                        select.innerHTML += `<option value="${p.nome}" data-id="${p.id}">${p.nome}</option>`;
                    });
                });
            }
        }
        document.getElementById('modal-solicitar-compra').style.display = 'flex';
    },

    openAtualizarTarefaModal(id, currentStatus) {
        document.getElementById('atualizar-tarefa-id').value = id;
        document.getElementById('atualizar-tarefa-status').value = currentStatus;
        document.getElementById('modal-atualizar-tarefa').style.display = 'flex';
    },

    async handleAtualizarTarefa(event) {
        event.preventDefault();
        const id = document.getElementById('atualizar-tarefa-id').value;
        const newStatus = document.getElementById('atualizar-tarefa-status').value;
        
        try {
            await DbService.updateTarefaStatus(id, newStatus);
            document.getElementById('modal-atualizar-tarefa').style.display = 'none';
            this.showToast('Tarefa updated com sucesso!', 'success');
            if (this.currentView === 'member') {
                this.loadAndRenderMemberTarefas();
            }
        } catch (e) {
            this.showAlert('Erro ao atualizar tarefa.');
            console.error(e);
        }
    },

    async applyDirectSubstitution(escalaId, novoMembroId, novoMembroNome) {
        this.showLoading();
        try {
            // 1. Obter informações da escala e membro anterior para auditoria/log
            let membroAnteriorNome = 'Desconhecido';
            try {
                const escalaSnap = await db.collection('escalas').doc(escalaId).get();
                if (escalaSnap.exists) {
                    membroAnteriorNome = escalaSnap.data().membroNome || 'Desconhecido';
                }
            } catch (err) {
                console.warn("Erro ao buscar membro anterior para log:", err);
            }

            // 2. Atualizar escala no Firestore de forma atômica
            await DbService.saveEscala(escalaId, {
                membroId: novoMembroId,
                membroNome: novoMembroNome,
                statusPresenca: 'Pendente',
                statusServico: 'Aguardando',
                rejeicaoResolvida: true,
                notificado: false
            });

            // 3. Registrar no Histórico de Substituições
            try {
                await DbService.addSubstituicaoLog({
                    escalaId,
                    membroAnterior: membroAnteriorNome,
                    membroNovo: novoMembroNome,
                    executadoPor: this.currentUser ? this.currentUser.nome : 'Supervisor',
                    tipo: 'IA_Direta'
                });
            } catch (err) {
                console.warn("Falha ao registrar log de substituição:", err);
            }

            // 4. Disparar notificação FCM em bloco isolado try/catch
            let fcmSuccess = true;
            try {
                await DbService.addNotificacao({
                    paraUsuarioId: novoMembroId,
                    paraUsuarioNome: novoMembroNome,
                    titulo: "Nova Escala Designada",
                    mensagem: `Você foi escalado para um novo serviço. Por favor, confirme sua presença no aplicativo.`,
                    tipo: "escala_nova"
                });
            } catch (err) {
                console.error("Falha ao enviar notificação FCM:", err);
                fcmSuccess = false;
            }

            if (fcmSuccess) {
                this.showToast(`Substituição concluída: ${novoMembroNome} escalado!`, 'success');
            } else {
                this.showToast('Substituição gravada com sucesso (notificação pendente)', 'warning');
            }

            // 5. Invalidar cache e atualizar os alertas do supervisor
            DbService.limparCache('escalas');
            await this.loadAndRenderSupervisorAlerts();
            
        } catch (e) {
            console.error("Erro na substituição direta:", e);
            this.showToast("Falha ao realizar a substituição direta.", "danger");
        } finally {
            this.hideLoading();
        }
    }
};

// Start application when page is ready
window.addEventListener('DOMContentLoaded', () => {
    App.init();
});
