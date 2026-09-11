/**
 * Catedral Connect - Auth Manager v70.3.1 (Lausanne Flex)
 * Handles Firebase Authentication and Role-Based Access Control (RBAC)
 */

const AuthManager = {
    // Current user's role (cached for session) - UPGRADED to localStorage for v60.0 Supernova
    role: (localStorage.getItem('session_role') === 'media' ? 'altar' : localStorage.getItem('session_role')) || null,

    async resolveAuthenticatedRoute(user) {
        if (!user) throw new Error("Sem usuário autenticado");
        const snap = await db.collection("users").doc(user.uid).get();
        if (!snap.exists) throw new Error("Usuário sem permissão de acesso.\nEntre em contato com o administrador.");
        const data = snap.data();
        if (data.ativo !== true) throw new Error("Usuário inativo.\nEntre em contato com o administrador.");
        if (!["admin", "monitor"].includes(data.role)) throw new Error("Perfil inválido.\nEntre em contato com o administrador.");
        
        return data.role === "admin" ? "admin" : "integracao";
    },

    /**
     * Initialize Auth Listener
     */
    init() {
        if (!window.firebase || !window.db) {
            console.error("Firebase not initialized.");
            return;
        }

        // Listen for cross-tab role updates (e.g. login in one tab affects all others)
        window.addEventListener('storage', (e) => {
            if (e.key === 'session_role') {
                this.role = e.newValue;
                console.log("💎 Diamond Sync: Role updated from other tab:", this.role);
            }
        });

        firebase.auth().onAuthStateChanged(async (user) => {
            if (user) {
                console.log("User Authenticated:", user.email);
                try {
                    const route = await this.resolveAuthenticatedRoute(user);
                    this.role = route === "admin" ? "admin" : "monitor";
                    localStorage.setItem('session_role', this.role);
                    
                    // Call global callback if defined
                    if (typeof window.onAuthSuccess === 'function') {
                        window.onAuthSuccess(user, route);
                    }
                } catch (err) {
                    console.error("🔑 Auth verification failed:", err.message);
                    alert(err.message);
                    await AuthManager.logout();
                }
            } else {
                console.log("User Logged Out");
                this.role = null;
                if (window.self === window.top) {
                    localStorage.removeItem('session_role');
                }
                // Call global callback if defined
                if (typeof window.onAuthLogout === 'function') {
                    window.onAuthLogout();
                }
            }
        });
    },

    /**
     * Centralized Login for Departmental Accounts
     * @param {string} department - e.g., 'admin', 'reception'
     * @param {string} pin - The PIN/Password
     */
    // Maps department role names → registered Firebase email accounts
    EMAIL_MAP: {
        'reception':   'recepcao@catedral.ch',
        'recepcao':    'recepcao@catedral.ch',
        'gabinete':    'pastor@catedral.ch',
        'admin':       'pastor@catedral.ch',
        'secretaria':  'pastor@catedral.ch',
        'lider':       'pastor@catedral.ch',
        'lideres':     'pastor@catedral.ch',
        'ministerio':  'pastor@catedral.ch',
        'ministério':  'pastor@catedral.ch',
        'kids':        'infantil@catedral.ch',
        'infantil':    'infantil@catedral.ch',
        'integracao':  'missao@catedral.ch',
        'acolhimento': 'missao@catedral.ch',
        'followup':    'missao@catedral.ch',
        'altar':       'midia@catedral.ch',
        'midia':       'midia@catedral.ch',
        'missao':      'missao@catedral.ch',
        'mulheres':    'mulheres@catedral.ch',
        'homens':      'homens@catedral.ch',
        'checkin':     'checkin@catedral.ch', // Dedicated event account
        'eventos':     'checkin@catedral.ch',
    },

    /**
     * Helper to determine role from email pattern (Emergency/Zero-Trust Fallback)
     */
    getRoleFromEmail(email) {
        if (!email) return 'guest';
        const e = email.toLowerCase();
        // ADMIN GROUP: Higher level access
        if (e.includes('admin') || e.includes('master') || e.includes('secretaria') || e.includes('pastor') || e.includes('lider') || e.includes('ministerio') || e.includes('ministério')) return 'admin';
        // DEPARTMENTAL GROUP
        if (e.includes('recepcao') || e.includes('checkin') || e.includes('eventos')) return 'reception';
        if (e.includes('kids') || e.includes('infantil')) return 'kids';
        if (e.includes('midia') || e.includes('media')) return 'altar';
        if (e.includes('altar')) return 'altar';
        if (e.includes('missao') || e.includes('integracao')) return 'integracao';
        if (e.includes('acolhimento')) return 'acolhimento';
        return 'guest';
    },

    async login(emailOrRole, password) {
        if (!emailOrRole || !password) {
            console.warn("🔐 AuthManager: Login blocked - Missing credentials.");
            return { success: false, error: "Missing credentials" };
        }

        let email = this.EMAIL_MAP[emailOrRole] || emailOrRole;

        try {
            const result = await firebase.auth().signInWithEmailAndPassword(email, password);
            console.log("Login Success:", result.user.email);
            
            try {
                const userDoc = await db.collection('users').doc(result.user.uid).get();
                if (userDoc.exists) {
                    const userData = userDoc.data();
                    if (userData.ativo !== true || (userData.role !== 'monitor' && userData.role !== 'admin')) {
                        await firebase.auth().signOut();
                        return { success: false, error: "Usuário sem permissão de acesso.\nEntre em contato com o administrador." };
                    }
                    this.role = userData.role;
                    localStorage.setItem('session_role', this.role);
                } else {
                    await firebase.auth().signOut();
                    return { success: false, error: "Usuário sem permissão de acesso.\nEntre em contato com o administrador." };
                }
            } catch (fsErr) {
                console.error("Firestore user check failed during login:", fsErr);
                await firebase.auth().signOut();
                return { success: false, error: "Erro ao validar permissões de acesso no Firestore." };
            }

            localStorage.setItem('last_logged_email', result.user.email);
            return { success: true };
        } catch (error) {
            console.error("❌ Login Failed:", error.code, error.message);
            return { success: false, error: error.message };
        }
    },

    /**
     * Logout
     */
    async logout() {
        await firebase.auth().signOut();
        localStorage.removeItem('session_role');
        localStorage.removeItem('session_role_persistent');
        localStorage.removeItem('session_pin_persistent');
        localStorage.removeItem('current_session_pin'); // Clear Master PIN
        localStorage.removeItem('remember_me'); // Clear remember me flag
        sessionStorage.clear();
        // Redirect to main index for fresh start
        window.top.location.href = 'index.html';
    },

    /**
     * Verification Guard for Pages/Iframes
     * @param {string} requiredRole 
     */
    async verifyAccess(requiredRole) {
        return new Promise((resolve) => {
            firebase.auth().onAuthStateChanged(async (user) => {
                if (!user) {
                    resolve(false);
                    return;
                }
                
                // If role not current, fetch it once
                if (!this.role || this.role === 'guest') {
                    const userDoc = await db.collection('users').doc(user.uid).get();
                    if (userDoc.exists) {
                        const userData = userDoc.data();
                        if (userData.ativo !== true || (userData.role !== 'monitor' && userData.role !== 'admin')) {
                            resolve(false);
                            return;
                        }
                        this.role = userData.role;
                    } else {
                        resolve(false);
                        return;
                    }
                    localStorage.setItem('session_role', this.role);
                }

                if (requiredRole === 'admin' && this.role === 'admin') {
                    resolve(true);
                } else if (requiredRole === 'integracao' && this.role === 'monitor') {
                    resolve(true);
                } else {
                    alert("Usuário sem permissão para este módulo.");
                    resolve(false);
                }
            });
        });
    }
};

// Auto-init on script load
if (window.firebase) AuthManager.init();
