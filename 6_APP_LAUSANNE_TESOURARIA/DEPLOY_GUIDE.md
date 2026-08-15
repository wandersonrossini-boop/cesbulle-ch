# 🏗️ DEPLOY — Guia Oficial da Tesouraria CME Lausanne

> ⚠️ **LEIA ANTES DE FAZER QUALQUER DEPLOY**
> Este arquivo existe para evitar publicações acidentais em projetos errados.

---

## 📦 Arquitetura de Produção

```
Flutter Web App (Firebase Hosting)
         ↓  HTTPS
Spring Boot API (Render — Docker)
         ↓  JDBC
PostgreSQL (Render — Managed Database)
```

---

## 🔑 Contas e Projetos — Separação Obrigatória

### ⚠️ ATENÇÃO: Este projeto usa uma conta Firebase DIFERENTE da conta principal!

| Conta Google | Projetos Firebase | Uso |
|---|---|---|
| `wandersonrossini@gmail.com` | `catedral-connect-bf717`, `catedral-connect-6c55e`, `ces-diaconia-*`, etc. | Todos os OUTROS projetos da CES Bulle |
| **`secretariacessuica@gmail.com`** | **`cme-lausanne-mvp-12345`** | **EXCLUSIVO: Tesouraria CME Lausanne** |

---

## ✅ Como Fazer Deploy Correto

### 1. Frontend (Flutter Web → Firebase Hosting)

**SEMPRE** execute a partir da pasta do app:
```bash
cd C:\Users\Wande\Documents\ia\6_APP_LAUSANNE_TESOURARIA\tesouraria_cme_app
```

**Compilar:**
```bash
flutter build web
```

**Publicar:**
```bash
npx firebase-tools deploy --only hosting --project cme-lausanne-mvp-12345 --account secretariacessuica@gmail.com
```

> ✅ URL oficial: **https://cme-lausanne-mvp-12345.web.app**

---

### 2. Backend (Spring Boot → Render)

O Render faz **auto-deploy automático** a cada `git push origin main`.

Repositório conectado ao Render:
- **GitHub:** https://github.com/wandersonrossini-boop/cesbulle-ch
- **Root Directory:** `6_APP_LAUSANNE_TESOURARIA/tesouraria_cme_api`
- **URL da API:** https://tesouraria-cme-api.onrender.com/api

> ✅ Basta fazer `git push` — o Render detecta e faz o deploy automaticamente via Docker.

---

## 🔐 Credenciais de Acesso ao App

| Campo | Valor |
|---|---|
| Usuário | `tesouraria` |
| Senha | `password123` |

---

## ❌ O que NÃO fazer

| Ação Proibida | Motivo |
|---|---|
| `firebase deploy` da pasta raiz `ia/` | Publica os outros 4 apps (Bulle, Admin, Diaconia...) |
| Deploy sem especificar `--project cme-lausanne-mvp-12345` | Firebase CLI usa a conta `wandersonrossini@gmail.com` que não tem acesso a este projeto |
| Rodar `firebase deploy` de outra pasta | Firebase CLI não encontra o `firebase.json` correto |
| Mexer em `catedral-connect-6c55e` | Este é o projeto do **4_APP_LAUSANNE_ADMIN** (sistema administrativo, não tesouraria) |

---

## 📂 Estrutura de Arquivos do Deploy

```
6_APP_LAUSANNE_TESOURARIA/
├── tesouraria_cme_api/          ← Backend Java/Spring Boot
│   ├── Dockerfile               ← Build Docker para o Render
│   └── src/main/resources/
│       └── application-prod.properties ← Configuração de produção (variáveis Render)
│
└── tesouraria_cme_app/          ← Frontend Flutter Web
    ├── .firebaserc              ← { "default": "cme-lausanne-mvp-12345" }
    ├── firebase.json            ← Aponta para build/web
    └── build/web/               ← Artefato compilado (flutter build web)
```

---

## 🔄 Fluxo Completo de Deploy

```
1. git add . && git commit -m "..." && git push origin main
         └─→ Render detecta e faz deploy automático do backend ✅

2. flutter build web
         └─→ Compila o app Flutter para build/web ✅

3. npx firebase-tools deploy --only hosting --project cme-lausanne-mvp-12345 --account secretariacessuica@gmail.com
         └─→ Publica em https://cme-lausanne-mvp-12345.web.app ✅
```

---

> 📌 Criado em: 09/08/2026 | Mantido por: Antigravity / Admilson Silva
