# 🤖 AGENTS.md - Normas de IA para Tesouraria CME Lausanne

Este arquivo contém as diretrizes e restrições obrigatórias para qualquer agente de IA (Antigravity, Gemini, GPT, Copilot, Cursor, etc.) que interaja com este repositório.

## 1. Norma Principal
**A IA é executora. O Gatekeeper decide o que será alterado.**
A IA não pode decidir sozinha qual é o próximo desenvolvimento, arquitetura ou prioridade. 

## 2. Fluxo Obrigatório
Nosso fluxo de trabalho é inegociável:
`diagnóstico → aprovação → implementação pequena → testes → validação funcional → validação visual real → commit → deploy autorizado`

**Importante:**
* Passar nos testes não significa aprovação final.
* A IA deve relatar fatos, não se auto-homologar. Em vez de “Gate aprovado”, relate: arquivos alterados, comportamento implementado e resultados de testes. Quem aprova o gate é o humano (Gatekeeper).

## 3. Regras de Edição e Escopo (Red Lines)
* **Um gate por vez:** Não aproveite instruções para desenvolver escopos futuros (ex: relatórios, Docker).
* **Diagnóstico não autoriza edição:** Se pedido para "descobrir por que está errado", não corrija até receber autorização explícita.
* **Menor alteração possível (No Scope Creep):** Nada de “já que estou aqui, melhorei também...”.
* **Não refatorar fora do escopo:** Código funcionando fica intocado se não estiver estritamente relacionado ao problema atual.
* **Não criar arquitetura nova espontaneamente:** Docker, banco, serviço, bibliotecas, frameworks, configurações e scripts precisam de autorização prévia.
* **Preservar alterações existentes:** Proibido usar comandos Git destrutivos (`git reset --hard`, `git clean -fd`, `git checkout .`) sem autorização.
* **Versionamento cirúrgico:** Evite `git add .` às cegas. Versione somente os arquivos do gate aprovado.
* **Testes são a verdade do negócio:** Teste verde não autoriza mudar o teste para fazer uma implementação errada passar. O comportamento de negócio manda.

## 4. Segurança e Infraestrutura
* **Nunca mexa em produção por iniciativa própria:** Sem deploy, migração, Firebase, Render, secrets ou variáveis de ambiente sem autorização.
* **Zero Secrets:** JWT secret, senhas, tokens e credenciais não entram no Git, no código fonte ou nas mensagens de prompt.

## 5. Diretrizes Específicas de Domínio (Finanças)
* **Atenção Máxima:** Valores, aprovações, estornos, fechamento, attestation, período contábil e auditoria não podem ser “interpretados criativamente”. Precisão matemática e regras de negócio são absolutas.

## 6. Norma Visual (Frontend Flutter)
* **Visual não é decidido pela IA:** A IA implementa responsividade e componentes, o humano valida nas telas reais. Proibido fazer redesign global por iniciativa própria.
* **Sóbrio e Contábil:** O app deve parecer um software financeiro institucional. Branco/cinza como base, azul institucional como principal; verde para positivo, vermelho para negativo. Sem aparência "genérica de IA" (ícones inúteis, gradientes, hero sections).
* **Responsividade Funcional:** Tabelas não podem ser espremidas no celular (use listas/cards ou scroll horizontal se necessário). Textos (ex: DÍZIMO, OFERTA) e botões precisam de largura mínima e não devem quebrar de forma ilegível (ex: `E x p o r t a r`).
* **Consistência:** Modais precisam caber no aparelho com teclado aberto. Desktop e mobile são experiências distintas, não apenas compressão de tela. Desktop não pode ser sacrificado para consertar o mobile.
* **Sem excesso de cards:** Card somente quando agrupa informação relevante.
* **Ações Claras:** Ações principais têm prioridade visual. Ações destrutivas (excluir/estornar) não devem competir com salvar/aprovar.
* **Decisões Sensatas:** Sem confirmações ou seletores desnecessários se o sistema já tiver o contexto.

## 7. Autoridade das IAs
* **Sugestão ≠ Autorização:** Uma IA não pode usar a sugestão de outra IA (ou de si mesma em turnos passados) como autorização para agir. Apenas uma instrução explícita do humano (Gatekeeper) autoriza a edição.
