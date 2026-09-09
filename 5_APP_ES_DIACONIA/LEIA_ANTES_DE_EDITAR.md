# ⚠️ LEIA ANTES DE EDITAR — APP ES DIACONIA [MÓDULO 5]

> Protocolo ativo e centralizador de arquitetura. Qualquer edição nesta pasta ou no sistema associado deve respeitar as regras descritas neste documento.
> Protocolo completo do ecossistema: `docs/PROTOCOLO_CONSULTA_PADRAO.md`

---

## 📍 1. IDENTIDADE E STATUS DO MÓDULO

| Campo | Valor |
|---|---|
| **Congregação** | CES Lausanne (Produção) |
| **Tipo** | Aplicativo PWA Standalone — Controle de escalas e serviços diaconais |
| **Status Geral** | 🟢 **ESTÁVEL / PRODUÇÃO VALIDADA / FCM EM VALIDAÇÃO FINAL** |
| **Modelo Operacional** | **Produção Exclusiva** (`diaconia-a38f1` / pronto para migração Infomaniak) |
| **Faturamento** | **Plano Spark (100% Gratuito)**. Cloud Functions e plano Blaze **NÃO** autorizados. |
| **PWA & Instalação** | **Instalador Integrado Ativo** (captura instalação e solicita notificações automaticamente) |

---

## ⚙️ 2. AMBIENTES E DIRETRIZES DO FIREBASE & INFOMANIAK

O mapeamento de projetos, hospedagens e redirecionamento está estruturado da seguinte forma:

| Ambiente | Projeto Firebase ID | Domínio/URL de Hospedagem | Status Operacional |
| :--- | :--- | :--- | :--- |
| **Produção Oficial** | `diaconia-a38f1` | `https://diaconia-a38f1.web.app` | **ATIVO** (Firestore de produção + PWA) |
| **Hospedagem Oficial** | *(Pronto para migrar)* | **Infomaniak** (ex: `diaconia.cesbulle.ch`) | **CONFIGURAÇÃO PRONTA** |
| **Desenvolvimento** | `ces-diaconia-dev` | `https://ces-diaconia-dev.web.app` | **ATIVO** (Para testes isolados) |

> [!IMPORTANT]
> **Hospedagem no Infomaniak:** Ao subir os arquivos estáticos para o Infomaniak, **é obrigatório** cadastrar o novo domínio na lista de **Domínios Autorizados** no console do Firebase (Authentication -> Settings -> Authorized Domains). O SSL/HTTPS Let's Encrypt deve estar ativo no painel da Infomaniak para que a API de PWA/Notificações funcione.
> A única fonte oficial de credenciais de conexão é o arquivo [firebase-config.js](file:///c:/Users/Wande/Documents/ia/5_APP_ES_DIACONIA/js/firebase-config.js).

---

## 🔒 3. ARQUITETURA DE SEGURANÇA E BANCO DE DADOS

### Coleções do Firestore:

* `/membros`: Armazena os perfis dos obreiros. Usuários ativos possuem `status == "ativo"`. Administradores possuem `perfil == "admin"`. Aproximadamente 8.000 membros foram auditados e nenhum utiliza mais o campo legado `senha`.
* `/credenciais`: Protegido. Armazena `passwordHash` (SHA-256 com salt) e `passwordSalt` gerados no client-side. Cada documento tem o mesmo ID do documento correspondente em `/membros`.
* `/setores`: Configurações de cores, ícones e funções dos setores de atuação.
* `/cultos` e `/escalas`: Planejamento de liturgias e voluntários associados.
* `/produtos` e `/historico_estoque`: Controle de reposição e movimentação de materiais de limpeza/manutenção.
* `/avisos`, `/disponibilidades`, `/mensagens_supervisao`, `/historico_substituicoes` e `/escalas_arquivadas`.

### Regras de Acesso e Autenticação (Spark-friendly):
1. **Autenticação Anônima Obrigatória**: O aplicativo faz login anônimo temporário via Firebase Auth (`signInAnonymously()`) no carregamento. Firebase Authentication **não é utilizado para autenticação real de usuários** — serve exclusivamente para satisfazer as regras de segurança do Firestore.
2. **Autenticação Real via Firestore**: A autenticação real é realizada pelas coleções `membros` e `credenciais`. Firebase Authentication é utilizado exclusivamente para `signInAnonymously()`, satisfazendo as regras de segurança do Firestore. Apenas usuários com `status == "ativo"` podem acessar. Administradores possuem `perfil == "admin"`.
3. **Compatibilidade Legada**: A função `validateLegacyPassword()` permanece no código por compatibilidade e **não deve ser removida sem autorização explícita**.
4. **Firestore Rules**:
   * Acesso geral permitido apenas para sessões autenticadas (`allow read, write: if request.auth != null`).
   * A coleção `/credenciais` tem bloqueio de listagem global a nível de banco de dados (`allow list: if false`), permitindo apenas a consulta individual por ID (`allow get: if request.auth != null`) para validação do hash.
5. **Criptografia**: Processada inteiramente no cliente via Web Crypto API, garantindo que hashes e salts nunca circulem de forma vulnerável na rede.

---

## ⚡ 4. FUNCIONALIDADES ATIVAS & DESBLOQUEADAS

Recentemente, o sistema foi atualizado com a remoção dos bloqueios legados da Fase 4A, reativando recursos essenciais:

* **Escalas e Calendário Mensal**:
  * O método `navigateToNextService` está totalmente ativo, permitindo ver detalhes de cada escala.
  * O **Calendário Mensal Premium** (`openMonthlyCalendar` e `showMonthlyCalendar`) foi desbloqueado e está integrado à Home dos obreiros.
* **Instalador PWA Customizado**:
  * Captura do evento `beforeinstallprompt` ativada.
  * Um card estilizado de **"Instalar no Celular"** aparece dinamicamente no menu **Perfil** se o app não estiver instalado.
* **Guia de Otimização de Segundo Plano**:
  * Assim que as notificações são ativadas, o app dispara um modal explicativo customizado por sistema operacional (**Android** e **iOS/iPhone**), ensinando os obreiros a desativar a otimização de bateria para garantir a recepção dos alertas mesmo com o app fechado.
* **Firebase Cloud Messaging (FCM)**:
  * Service Worker registrado e operacional (`sw-notifications.js`).
  * Token FCM gerado corretamente, associado ao documento do membro autenticado e armazenado em `membros.fcmTokens`.
  * Notificações em foreground e background implementadas.
  * Push Engine operacional.
  * Validação atual concentrada na entrega ponta a ponta.
* **GitHub Actions**:
  * Secret `FIREBASE_SERVICE_ACCOUNT` configurado no repositório.
  * Workflow de envio de notificações operacional.
  * Cron automático ativo.

---

## 📂 5. ARQUIVOS CRÍTICOS DO SISTEMA

* [index.html](file:///c:/Users/Wande/Documents/ia/5_APP_ES_DIACONIA/index.html): Interface principal de escalas e diaconia. Contém o card de instalação PWA.
* [js/app.js](file:///c:/Users/Wande/Documents/ia/5_APP_ES_DIACONIA/js/app.js): Lógica de controle do SPA (sessões, navegação, PWA, controle de diálogos de bateria e notificações).
* [js/db.js](file:///c:/Users/Wande/Documents/ia/5_APP_ES_DIACONIA/js/db.js): Camada CRUD de banco de dados (controle de cache e conversão de datas). Contém `authenticateUser`, `hashPassword`, `generateSalt` e `validateLegacyPassword`.
* [js/firebase-config.js](file:///c:/Users/Wande/Documents/ia/5_APP_ES_DIACONIA/js/firebase-config.js): SDK de configuração e controle de redirecionamento dinâmico de conexões.
* [sw-notifications.js](file:///c:/Users/Wande/Documents/ia/5_APP_ES_DIACONIA/sw-notifications.js): Service Worker de notificações e cache offline.
* [firestore.rules](file:///c:/Users/Wande/Documents/ia/firestore.rules): Regras de segurança de acesso ativo do Firestore.
* [firestore.indexes.json](file:///c:/Users/Wande/Documents/ia/firestore.indexes.json): Índices compostos exigidos para filtros complexos.

---

## 🔒 6. DIRETRIZES E REGRAS PARA EDIÇÃO E DEPLOY

1. **Sessão Local antes de Deploy**:
   * Sempre confirme o ambiente correto do Firebase CLI antes de realizar o deploy:
     * Para Produção: `firebase use diaconia-a38f1`
     * Para Desenvolvimento: `firebase use ces-diaconia-dev`
2. **Deploy do App**:
   * Subir apenas a hospedagem deste módulo: `firebase deploy --only hosting:diaconia`
   * Subir regras e índices associados: `firebase deploy --only firestore`
3. **Backup Final**:
   * Salvar backups estruturais em: `3_LAUSANNE_ARQUIVO_HISTORICO/REPOSITORIO_DE_RESTAURACAO_E_VERSOES/`
