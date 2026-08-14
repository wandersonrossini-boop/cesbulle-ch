# Regras de Deploy - Tesouraria CME Lausanne

Este projeto possui dois componentes principais e deve ser deployado seguindo as instruções estritas abaixo para evitar confusão de projetos vizinhos (como o App Diaconia).

---

## 🛠️ 1. Frontend (Flutter Web)
Hospedado no **Firebase Hosting** sob o projeto `cme-lausanne-mvp-12345`.

### Regras Obrigatórias para o Agente:
1. **Evitar conflitos de porta/PowerShell:** No Windows, o script PowerShell `npx` pode ser bloqueado pela ExecutionPolicy. Sempre execute os comandos do Node/Firebase empacotados pelo `cmd.exe`.
2. **Especificar o Projeto Explicitamente:** Devido a arquivos `.firebaserc` na pasta raiz pai do usuário, você **DEVE** declarar explicitamente o projeto `--project cme-lausanne-mvp-12345` em qualquer comando de deploy para evitar enviar os arquivos para outros aplicativos.

### Comandos de Compilação e Deploy:
```bash
# 1. Compilar para web
flutter build web

# 2. Deploy para o Firebase correto (via cmd.exe para evitar bloqueio do PowerShell)
cmd.exe /c "npx firebase deploy --only hosting --project cme-lausanne-mvp-12345"
```

---

## ⚙️ 2. Backend (Spring Boot API)
Hospedado no **Render** com banco de dados PostgreSQL.

### Regras Obrigatórias para o Agente:
1. **Deploy Automático:** O deploy do backend é acionado automaticamente a cada `git push` na branch `main`.
2. **Atualização de Credenciais:** O arquivo `DataInitializer.java` deve garantir a existência e a senha correta do usuário administrador `pastor` com a senha `Pr.124578.`.
3. **Comando de Commit e Push:**
```bash
git add .
git commit -m "mensagem de commit"
git push
```
