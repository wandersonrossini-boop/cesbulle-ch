# 🔄 CHANGELOG TÉCNICO

Todas as mudanças técnicas notáveis no projeto serão documentadas neste arquivo, com foco principal em segurança, infraestrutura e arquitetura.

---

### [2026-10-21] Refinamento Visual Connect CME Lausanne & Check-in (v70.3.79)
* **Connect CME Lausanne (`connect.html`):**
  * Atualização da página inicial conforme design aprovado com hierarquia refinada: Logotipo, Saudação com nome dinâmico (`Olá, [Nome]`), Separador dourado, Área espiritual primária, Agenda compacta e Área social.
  * Implementação da tela intermediária `screen-espiritual` com cards de Oração, Uma palavra, Visita e nota de privacidade com ícone de cadeado.
  * Criação dos formulários dedicados para `oracao`, `palavra` e `visita` com estilo limpo, botão verde institucional (`#1B5E4B`) e nota de discrição.
  * Implementação da tela de sucesso unificada com check verde e botão de retorno `VOLTAR PARA O INÍCIO`.
  * Atualização da agenda com layout em duas colunas e card inferior explicativo.
* **Módulo de Check-in (`checkin.html`):**
  * Sincronização e transações Firestore para evitar duplicações concorrentes em eventos fechados.
  * Normalização de nomes e telefones para entrada rápida (walk-in).
  * Regras de segurança alinhadas a `hasRole('checkin')` e `hasRole('eventos')`.
* **Painel Administrativo & Recepção (`recepcao_v2.html`, `admin.html`, `gabinete.html`, `integracao.html`):**
  * Atualização da paleta institucional Navy, Teal e Gold.
  * Fluxo de encerramento de sessão com diálogo de confirmação.

---

### [2026-07-06] Sprint 1 - Ticket UI-001 (Consolidação da Sidebar)
* **Adicionado:** Criação do módulo global `js/ui.js` para gerenciar funções transversais.
* **Refatorado:** Função `toggleSidebar()` isolada e componentizada. Removida cópia em `admin.html` e `gabinete.html` (-6 linhas), substituída pela importação do arquivo central compartilhado.

### [2026-07-06] Sprint 0 - Fechamento da Baseline
* **Baseline de Engenharia criada.** A fundação documental do projeto foi formalmente estabelecida, sem nenhuma alteração funcional.

### [2026-07-06] Missão ENG-001 (Documentação Técnica)
* **Adicionado:** Criação do diretório central de documentação (`docs/`).
* **Adicionado:** Construção da documentação oficial da plataforma (`ARQUITETURA.md`, `BACKLOG.md` e este `CHANGELOG.md`).
* **Mapeamento:** Todos os relatórios das auditorias anteriores consolidados internamente na subpasta `docs/auditorias/`.

### [2026-07-06] Limpeza Estrutural (Arquivos Mortos)
* **Removido:** `js/firebase-config.bulle.js` (Arquivo morto sem nenhuma referência no projeto).
* **Removido:** `app.html` (Arquivo órfão defasado que executava apenas redirecionamento forçado).
* **Movido:** `ferramenta_senhas_lausanne.html` (Retirado da raiz principal do projeto e resguardado na pasta `archive/` por conter lógicas sensíveis sem fluxo de UI ativo).

### [Antes de 2026-07-06]
* **Desenvolvimento Histórico:** Todo o sistema foi mantido através de clonagem de telas baseadas em `admin.html` (Recepção, Integração, Visitante). Sem versionamento arquitetural documentado até o dia de hoje.
