// Firebase Configuration for CES Diaconia (Standalone SPA)
// Environment: Production (diaconia-a38f1) & Dev (ces-diaconia-dev)

var firebaseConfigDev = {
    apiKey: "AIzaSyC5aYjN7SoiuITUrtsxxU03HvARVotYdjI",
    authDomain: "ces-diaconia-dev.firebaseapp.com",
    projectId: "ces-diaconia-dev",
    storageBucket: "ces-diaconia-dev.firebasestorage.app",
    messagingSenderId: "823919336681",
    appId: "1:823919336681:web:ea26257e1eb002424e2478"
};

var firebaseConfigProd = {
    apiKey: "AIzaSyDqlZ5pukg4NAg2mqMjAzAcRJCIeNN_K24",
    authDomain: "diaconia-a38f1.firebaseapp.com",
    projectId: "diaconia-a38f1",
    storageBucket: "diaconia-a38f1.firebasestorage.app",
    messagingSenderId: "489746524173",
    appId: "1:489746524173:web:f0eead38951fb738364d44"
};

// 1. Detectar o ambiente com base no domínio
let selectedConfig = firebaseConfigProd;
let useLegacyNamespace = false;

const hostname = window.location.hostname;
const isDefinitiveDomain = (hostname === 'diaconato.ch' || hostname === 'www.diaconato.ch');
const isCurrentOfficialDomain = (hostname === 'diaconia-a38f1.web.app' || hostname === 'diaconia-a38f1.firebaseapp.com');
const isDevDomain = (hostname === 'ces-diaconia-dev.web.app' || hostname === 'localhost' || hostname === '127.0.0.1');

if (isDefinitiveDomain || isCurrentOfficialDomain) {
    selectedConfig = firebaseConfigProd;
    useLegacyNamespace = false;
    console.log(`Diaconia rodando no ambiente de PRODUÇÃO (${hostname}).`);
} else if (isDevDomain) {
    selectedConfig = firebaseConfigDev;
    useLegacyNamespace = false;
    console.log("Diaconia rodando no AMBIENTE DE DESENVOLVIMENTO (Dev) com coleções limpas.");
} else {
    selectedConfig = firebaseConfigProd;
    useLegacyNamespace = false;
    console.warn(`Hostname desconhecido (${hostname}). Utilizando PRODUÇÃO como fallback de segurança.`);
}

// 2. Inicializar o Firebase
if (typeof firebase !== 'undefined') {
    if (firebase.apps.length === 0) {
        firebase.initializeApp(selectedConfig);
        console.log("Firebase inicializado para CES Diaconia!");
    } else {
        console.log("Firebase já inicializado.");
    }

    // Configurar persistência de sessão para evitar "sessões fantasma" em IndexedDB
    if (typeof firebase.auth === 'function') {
        firebase.auth().setPersistence(firebase.auth.Auth.Persistence.SESSION).catch(e => {
            console.warn("Erro ao configurar persistência de sessão:", e);
        });
    }

    window.db = firebase.firestore();
    window.firebaseConfig = selectedConfig;

    // --- NAMESPACING DE DADOS (Compatibilidade com Projeto Legado) ---
    if (useLegacyNamespace) {
        window.DB_PREFIX = 'diaconia_escala_';
        const originalCollection = window.db.collection;
        window.db.collection = function(name) {
            const finalName = name.startsWith(window.DB_PREFIX) ? name : window.DB_PREFIX + name;
            return originalCollection.call(this, finalName);
        };
        console.log("Firestore Namespacing Ativo com prefixo: " + window.DB_PREFIX);
    } else {
        console.log("Firestore Operando com Coleções Limpas (Sem prefixo).");
    }
} else {
    console.error("SDK do Firebase não encontrado. Carregue os SDKs antes deste script.");
}
