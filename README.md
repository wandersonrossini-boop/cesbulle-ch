# Catedral da Esperança Bulle & Lausanne - Ecossistema Digital

Este repositório contém o código-fonte integral do ecossistema digital da Catedral da Esperança (Bulle e Lausanne, Suíça).

## 📁 Estrutura do Projeto
- **`1_SITE_CATEDRAL_INSTITUCIONAL`**: Site oficial público ([cesbulle.ch](https://cesbulle.ch)).
- **`2_APP_BULLE_OPERACIONAL`**: Aplicativo interno Bulle (Recepção, Kids, Altar e Secretaria).
- **`3_LAUSANNE_ARQUIVO_HISTORICO`**: Backup e arquivos históricos de Lausanne.
- **`4_APP_LAUSANNE_ADMIN`**: Sistema administrativo e aplicativo da congregação Lausanne (`admin.html`, `connect.html`, `checkin.html`, `recepcao_v2.html`, `gabinete.html`, `integracao.html`).
- **`5_APP_ES_DIACONIA`**: Sistema de controle de escalas e serviços diaconais (autônomo).
- **`6_APP_LAUSANNE_TESOURARIA`**: Módulo operacional e financeiro da tesouraria.

## 🚀 Tecnologias
- **Frontend:** HTML5, CSS3 (Mobile-First, Paleta Institucional e Identidade Visual), JavaScript (ES6+).
- **Backend / Hosting:** Firebase (Hosting, Cloud Firestore, Firebase Auth).
- **API / Mobile:** Flutter / Spring Boot (Tesouraria).

## 🛠️ Como dar manutenção
1. Certifique-se de ter o **Firebase CLI** instalado.
2. Para subir mudanças no site institucional: `firebase deploy --only hosting:site`.
3. Para subir mudanças no app Bulle: `firebase deploy --only hosting:app`.
4. Para subir mudanças no Lausanne (Admin, Connect e Check-in): `firebase deploy --only hosting:admin-lausanne`.
5. Para subir mudanças na Diaconia: `firebase deploy --only hosting:diaconia`.

## 🌐 URLs de Produção (Lausanne)
- **Connect Lausanne:** [https://catedral-connect-6c55e.web.app/connect.html](https://catedral-connect-6c55e.web.app/connect.html)
- **Check-in Lausanne:** [https://catedral-connect-6c55e.web.app/checkin.html](https://catedral-connect-6c55e.web.app/checkin.html)
- **Painel Administrativo:** [https://catedral-connect-6c55e.web.app/](https://catedral-connect-6c55e.web.app/)

---
© 2026 Catedral da Esperança | Atualizado em 21/10/2026
