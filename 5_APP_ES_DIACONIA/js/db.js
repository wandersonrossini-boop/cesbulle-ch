// CES Diaconia - Database & CRUD Module (Firestore SDK v8 compat)

const DbService = {
    // --- DATE CONVERSION UTILITY ---
    safeToDate(val, defaultVal = null) {
        if (!val) return defaultVal;
        if (typeof val.toDate === 'function') {
            return val.toDate();
        }
        if (val instanceof Date) {
            return val;
        }
        if (typeof val.seconds === 'number') {
            return new Date(val.seconds * 1000 + Math.floor((val.nanoseconds || 0) / 1000000));
        }
        const parsed = new Date(val);
        if (!isNaN(parsed.getTime())) {
            return parsed;
        }
        return defaultVal;
    },

    // --- CACHE SYSTEM (Fase 2.1 - Otimizada com SessionStorage) ---
    _cacheTTL: 300000, // 5 minutos em milissegundos
    cacheStats: {
        leiturasEconomizadas: 0,
        leiturasReais: 0,
        ultimaAtualizacao: null
    },

    _salvarNoCache(chave, dados) {
        try {
            sessionStorage.setItem(`diaconia_cache_${chave}`, JSON.stringify(dados));
            const cachedTimestamps = sessionStorage.getItem('diaconia_cache_timestamps');
            const timestamps = cachedTimestamps ? JSON.parse(cachedTimestamps) : {};
            timestamps[chave] = Date.now();
            sessionStorage.setItem('diaconia_cache_timestamps', JSON.stringify(timestamps));
        } catch (e) {
            console.warn("Falha ao salvar no cache:", e);
        }
    },

    _obterDoCache(chave) {
        try {
            const dataStr = sessionStorage.getItem(`diaconia_cache_${chave}`);
            return dataStr ? JSON.parse(dataStr) : null;
        } catch (e) {
            return null;
        }
    },

    isCacheValido(chave) {
        try {
            const cachedTimestamps = sessionStorage.getItem('diaconia_cache_timestamps');
            if (!cachedTimestamps) return false;
            const timestamps = JSON.parse(cachedTimestamps);
            const ts = timestamps[chave] || 0;
            const agora = Date.now();
            return (agora - ts < this._cacheTTL) && sessionStorage.getItem(`diaconia_cache_${chave}`) !== null;
        } catch (e) {
            return false;
        }
    },

    limparCache(chave) {
        try {
            if (chave) {
                console.log(`[Cache] Invalidando cache para a chave: ${chave}`);
                sessionStorage.removeItem(`diaconia_cache_${chave}`);
                const cachedTimestamps = sessionStorage.getItem('diaconia_cache_timestamps');
                const timestamps = cachedTimestamps ? JSON.parse(cachedTimestamps) : {};
                timestamps[chave] = 0;
                sessionStorage.setItem('diaconia_cache_timestamps', JSON.stringify(timestamps));
            } else {
                console.log("[Cache] Invalidando todo o cache");
                sessionStorage.removeItem('diaconia_cache_membros');
                sessionStorage.removeItem('diaconia_cache_setores');
                sessionStorage.removeItem('diaconia_cache_produtos');
                sessionStorage.removeItem('diaconia_cache_escalas');
                sessionStorage.removeItem('diaconia_cache_cultos');
                sessionStorage.removeItem('diaconia_cache_reposicoes');
                sessionStorage.removeItem('diaconia_cache_avisos');
                sessionStorage.removeItem('diaconia_cache_muralConfig');
                sessionStorage.removeItem('diaconia_cache_timestamps');
            }
        } catch (e) {
            console.error("Erro ao limpar cache:", e);
        }
    },

    // --- CRYPTO HELPERS (Salted SHA-256 via Web Crypto API) ---
    generateSalt() {
        const array = new Uint8Array(16);
        window.crypto.getRandomValues(array);
        return Array.from(array).map(b => b.toString(16).padStart(2, '0')).join('');
    },

    async hashPassword(password, salt) {
        const encoder = new TextEncoder();
        const data = encoder.encode(password + salt);
        const hashBuffer = await window.crypto.subtle.digest('SHA-256', data);
        const hashArray = Array.from(new Uint8Array(hashBuffer));
        return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
    },

    // --- INITIAL SEED METHOD ---
    async checkAndSeedDatabase() {
        try {
            console.log("Checking if database needs seeding...");
            const membersSnap = await db.collection('membros').limit(1).get();
            
            if (membersSnap.empty) {
                console.log("Database empty! Seeding initial data...");
                
                // 1. Seed Admin Principal (CES Diaconia Lausanne)
                const adminSalt = this.generateSalt();
                const adminHash = await this.hashPassword("Ces120222.", adminSalt);
                
                await db.collection('membros').doc('admin_default').set({
                    nome: "Wanderson Rossini",
                    nomeNormalizado: "wanderson rossini",
                    email: "admin@diaconia.com",
                    perfil: "admin",
                    setor: null,
                    funcao: "Administrador",
                    status: "ativo",
                    criadoEm: firebase.firestore.FieldValue.serverTimestamp()
                });

                await db.collection('credenciais').doc('admin_default').set({
                    passwordHash: adminHash,
                    passwordSalt: adminSalt
                });

                // 4. Seed Sectors
                const sectors = [
                    {
                        id: "diaconia_templo",
                        nome: "Diaconia do Templo",
                        funcoes: ["Portaria", "Check-in", "Apoio Interno", "Ronda"],
                        cor: "#127369" // teal
                    },
                    {
                        id: "acolhimento_integracao",
                        nome: "Acolhimento e Integração",
                        funcoes: ["Acolhimento", "Integração"],
                        cor: "#4A154B" // purple
                    },
                    {
                        id: "limpeza",
                        nome: "Limpeza",
                        funcoes: ["Limpeza geral", "Salão e banheiros", "Áreas externas", "Reposição de produtos"],
                        cor: "#1E3A8A" // deep blue
                    },
                    {
                        id: "manutencao",
                        nome: "Manutenção",
                        funcoes: ["Manutenção predial", "Elétrica", "Hidráulica", "Ar-condicionado", "Reparos gerais"],
                        cor: "#065F46" // green
                    }
                ];

                for (let sec of sectors) {
                    await db.collection('setores').doc(sec.id).set(sec);
                }

                // 5. Seed Products
                const initialProducts = [
                    { nome: "Papel higiênico", setorId: "limpeza", quantidade: 30, status: "ativo" },
                    { nome: "Sabonete líquido", setorId: "limpeza", quantidade: 15, status: "ativo" },
                    { nome: "Desinfetante", setorId: "limpeza", quantidade: 10, status: "ativo" },
                    { nome: "Detergente", setorId: "limpeza", quantidade: 12, status: "ativo" },
                    { nome: "Saco de lixo 100L", setorId: "limpeza", quantidade: 50, status: "ativo" },
                    { nome: "Esponja de limpeza", setorId: "limpeza", quantidade: 20, status: "ativo" },
                    { nome: "Álcool 70%", setorId: "limpeza", quantidade: 15, status: "ativo" },
                    
                    { nome: "Lâmpada LED 9W", setorId: "manutencao", quantidade: 15, status: "ativo" },
                    { nome: "Fita isolante", setorId: "manutencao", quantidade: 8, status: "ativo" },
                    { nome: "Pilhas AA (para microfone)", setorId: "manutencao", quantidade: 24, status: "ativo" },
                    { nome: "Filtro de ar-condicionado", setorId: "manutencao", quantidade: 6, status: "ativo" },
                    { nome: "Parafuso e bucha 8mm", setorId: "manutencao", quantidade: 100, status: "ativo" },
                    
                    { nome: "Copo descartável 200ml", setorId: "acolhimento_integracao", quantidade: 200, status: "ativo" },
                    { nome: "Fita crepe", setorId: "acolhimento_integracao", quantidade: 5, status: "ativo" },
                    { nome: "Crachá de visitante", setorId: "acolhimento_integracao", quantidade: 40, status: "ativo" },
                    { nome: "Caneta esferográfica azul", setorId: "acolhimento_integracao", quantidade: 15, status: "ativo" },
                    
                    { nome: "Pilhas AAA", setorId: "diaconia_templo", quantidade: 20, status: "ativo" },
                    { nome: "Rádio comunicador (reserva)", setorId: "diaconia_templo", quantidade: 2, status: "ativo" },
                    { nome: "Lanterna LED", setorId: "diaconia_templo", quantidade: 4, status: "ativo" },
                    { nome: "Capa de chuva descartável", setorId: "diaconia_templo", quantidade: 30, status: "ativo" }
                ];

                for (let prod of initialProducts) {
                    await db.collection('produtos').add(prod);
                }

                // 6. Aviso de boas-vindas
                await db.collection('avisos').add({
                    titulo: "Bem-vindos ao App de Escala!",
                    conteudo: "O sistema de escala da Diac\u00f4nia CES Lausanne est\u00e1 no ar. Cada membro receber\u00e1 suas escalas diretamente aqui. Confirme sua presen\u00e7a assim que receber a notifica\u00e7\u00e3o.",
                    autorNome: "Wanderson Rossini",
                    data: firebase.firestore.FieldValue.serverTimestamp()
                });

                console.log("Database seeded successfully!");
            } else {
                console.log("Database already has data. Seeding skipped.");
            }
        } catch (e) {
            console.error("Error checking or seeding database:", e);
        }
    },

    // Normalize a string for comparison: lowercase + remove accents + compress spaces
    normalizeStr(str) {
        return (str || '').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/\s+/g, ' ').trim();
    },

    // --- AUTENTICAï¿½ï¿½O POR NOME (Firestore-based) ---
    async authenticateUser(nomeDigitado, password) {
        try {
            const nomeNorm = this.normalizeStr(nomeDigitado);
            
            // Garantir sessão ativa para passar pelas regras de segurança
            if (!firebase.auth().currentUser) {
                console.log("[Auth-Diag] Iniciando sessão anônima temporária...");
                await firebase.auth().signInAnonymously();
            }
            console.log(`[Auth-Diag] Sessão anônima ativa. UID temporário: ${firebase.auth().currentUser.uid}`);

            // Buscar membro ativo pelo nome normalizado
            console.log(`[Auth-Diag] Executando query em 'membros' para nomeNormalizado: "${nomeNorm}"`);
            const snap = await db.collection('membros')
                .where('nomeNormalizado', '==', nomeNorm)
                .where('status', '==', 'ativo')
                .limit(1)
                .get();

            // DIAGNÓSTICO AVANÇADO (Detectar Duplicidade usando limit(1) e orderBy para burlar a restrição de listagem de forma legal)
            try {
                const snapDesc = await db.collection('membros')
                    .where('nomeNormalizado', '==', nomeNorm)
                    .where('status', '==', 'ativo')
                    .orderBy(firebase.firestore.FieldPath.documentId(), 'desc')
                    .limit(1)
                    .get();

                if (!snap.empty && !snapDesc.empty) {
                    const docFirst = snap.docs[0];
                    const docLast = snapDesc.docs[0];

                    if (docFirst.id !== docLast.id) {
                        console.log(`[Auth-Diag] ATENÇÃO: MÚLTIPLOS DOCUMENTOS ENCONTRADOS para "${nomeNorm}"! (Pelo menos 2)`);
                        console.log(`[Auth-Diag] Documento A (Ascendente) -> ID: ${docFirst.id.substring(0,3)}***${docFirst.id.substring(docFirst.id.length-3)}, Perfil: ${docFirst.data().perfil}, Nome: ${docFirst.data().nome}`);
                        console.log(`[Auth-Diag] Documento B (Descendente) -> ID: ${docLast.id.substring(0,3)}***${docLast.id.substring(docLast.id.length-3)}, Perfil: ${docLast.data().perfil}, Nome: ${docLast.data().nome}`);
                    } else {
                        console.log(`[Auth-Diag] Apenas 1 documento existe no banco para "${nomeNorm}".`);
                    }
                }
            } catch (diagErr) {
                console.warn("[Auth-Diag] Aviso: não foi possível executar diagnóstico secundário de duplicidade.", diagErr.message);
            }

            let matchedDoc = null;
            let mData = null;

            if (!snap.empty) {
                matchedDoc = snap.docs[0];
                mData = matchedDoc.data();
                console.log("[Auth-Diag] Membro SELECIONADO para o login:");
                console.log(`[Auth-Diag] ID: ${matchedDoc.id.substring(0, 3)}***${matchedDoc.id.substring(matchedDoc.id.length - 3)}`);
                console.log(`[Auth-Diag] perfil: ${mData.perfil || 'vazio'}`);
                console.log(`[Auth-Diag] nome: ${mData.nome}`);
                console.log(`[Auth-Diag] nomeNormalizado: ${mData.nomeNormalizado}`);
                console.log(`[Auth-Diag] status: ${mData.status}`);
            } else {
                console.log("[Auth-Diag] Membro NÃO ENCONTRADO na query.");
            }

            if (!matchedDoc) {
                return { success: false, error: 'Nome não encontrado. Verifique se digitou o nome completo.' };
            }

            const membroId = matchedDoc.id;
            const maskedId = membroId.substring(0, 3) + '***' + membroId.substring(membroId.length - 3);
            console.log(`[Auth-Diag] ID do Membro resolvido (parcial): ${maskedId}`);

            console.log(`[Auth-Diag] Tentando ler credenciais/${maskedId}...`);
            const credRef = db.collection('credenciais').doc(membroId);
            const credSnap = await credRef.get();

            let passwordMatch = false;
            let needsMigration = false;

            if (credSnap.exists) {
                console.log("[Auth-Diag] Documento de credencial EXISTE.");
                const credData = credSnap.data();
                const computedHash = await this.hashPassword(password, credData.passwordSalt);
                passwordMatch = (computedHash === credData.passwordHash);
                console.log(`[Auth-Diag] Comparação de hash concluída. Result: ${passwordMatch}`);
            } else if (mData.senha) {
                console.log("[Auth-Diag] Credencial não existe, testando senha em texto plano legado.");
                if (mData.senha === password) {
                    passwordMatch = true;
                    needsMigration = true;
                }
            } else {
                console.log("[Auth-Diag] Documento de credencial NÃO EXISTE e sem senha legada.");
            }

            if (!passwordMatch) {
                return { success: false, error: 'Senha incorreta.' };
            }

            // Realizar migração híbrida segura no client-side
            if (needsMigration) {
                const salt = this.generateSalt();
                const hash = await this.hashPassword(password, salt);

                const batch = db.batch();
                // 1. Criar credencial com hash e salt
                batch.set(credRef, {
                    passwordHash: hash,
                    passwordSalt: salt
                });
                // 2. Remover senha em texto plano e gravar nomeNormalizado
                batch.update(db.collection('membros').doc(membroId), {
                    nomeNormalizado: nomeNorm,
                    senha: firebase.firestore.FieldValue.delete()
                });
                await batch.commit();
                console.log(`[Segurança] Membro '${mData.nome}' migrado com sucesso client-side!`);
            } else if (!mData.nomeNormalizado && mData.nome) {
                // Apenas atualizar nome normalizado se estiver ausente
                await db.collection('membros').doc(membroId).update({
                    nomeNormalizado: nomeNorm
                });
            }

            // Simular claims/perfil do usuário na sessão ativa do frontend
            const sessionUser = {
                id: membroId,
                nome: mData.nome,
                email: mData.email,
                perfil: mData.perfil || 'membro',
                setor: mData.setor,
                setores: mData.setores || (mData.setor ? [mData.setor] : []),
                funcao: mData.funcao,
                fotoUrl: mData.fotoUrl || null,
                eRepositor: mData.eRepositor || false
            };

            this.limparCache();

            return {
                success: true,
                user: sessionUser
            };
        } catch (e) {
            console.error("Erro na autenticação client-side:", e);
            return { success: false, error: "Erro de conexão com o banco de dados." };
        }
    },

    // --- MEMBROS CRUD ---
    async getMembros() {
        if (this.isCacheValido('membros')) {
            const data = this._obterDoCache('membros');
            if (data) {
                this.cacheStats.leiturasEconomizadas += data.length || 1;
                return data;
            }
        }
        const snap = await db.collection('membros').orderBy('nome').get();
        const data = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        this._salvarNoCache('membros', data);
        this.cacheStats.leiturasReais += data.length;
        this.cacheStats.ultimaAtualizacao = new Date();
        return data;
    },

    async saveMembro(id, data) {
        let returnId = id;
        
        // 1. Garantir nomeNormalizado
        if (data.nome) {
            data.nomeNormalizado = this.normalizeStr(data.nome);
        }

        // Extrair campos de senha
        let inputPassword = data.senha;
        delete data.senha; // Nunca manter senha no objeto do membro

        if (id) {
            // Edição de membro
            data.senha = firebase.firestore.FieldValue.delete();
            await db.collection('membros').doc(id).update(data);
            returnId = id;
        } else {
            // Cadastro de novo membro
            data.criadoEm = firebase.firestore.FieldValue.serverTimestamp();
            const docRef = await db.collection('membros').add(data);
            returnId = docRef.id;
        }

        // 2. Se houver uma nova senha informada (ou for cadastro novo), salvar de forma segura no client-side
        if (inputPassword && inputPassword.trim() !== '') {
            try {
                console.log(`[Segurança] Salvando credenciais do membro no client-side...`);
                const salt = this.generateSalt();
                const hash = await this.hashPassword(inputPassword, salt);
                
                await db.collection('credenciais').doc(returnId).set({
                    passwordHash: hash,
                    passwordSalt: salt
                });
            } catch (e) {
                console.error("Erro ao salvar credenciais do obreiro:", e);
                throw e;
            }
        } else if (!id) {
            // Novo cadastro sem senha informada (usar senha padrão de segurança)
            try {
                console.log(`[Segurança] Gerando credencial padrão para o novo obreiro...`);
                const salt = this.generateSalt();
                const hash = await this.hashPassword("Ces120222.", salt);
                
                await db.collection('credenciais').doc(returnId).set({
                    passwordHash: hash,
                    passwordSalt: salt
                });
            } catch (e) {
                console.error("Erro ao definir credencial padrão de novo obreiro:", e);
            }
        }

        this.limparCache('membros');
        return returnId;
    },

    async deleteMembro(id) {
        await db.collection('membros').doc(id).delete();
        this.limparCache('membros');
    },

    // --- SETORES ---
    async getSetores() {
        if (this.isCacheValido('setores')) {
            const data = this._obterDoCache('setores');
            if (data) {
                this.cacheStats.leiturasEconomizadas += data.length || 1;
                return data;
            }
        }
        const snap = await db.collection('setores').get();
        const data = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        this._salvarNoCache('setores', data);
        this.cacheStats.leiturasReais += data.length;
        this.cacheStats.ultimaAtualizacao = new Date();
        return data;
    },

    async saveSetor(id, data) {
        await db.collection('setores').doc(id).set(data);
        this.limparCache('setores');
    },

    // --- PRODUTOS CRUD ---
    async getProdutos() {
        if (this.isCacheValido('produtos')) {
            const data = this._obterDoCache('produtos');
            if (data) {
                this.cacheStats.leiturasEconomizadas += data.length || 1;
                return data;
            }
        }
        const snap = await db.collection('produtos').orderBy('nome').get();
        const data = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        this._salvarNoCache('produtos', data);
        this.cacheStats.leiturasReais += data.length;
        this.cacheStats.ultimaAtualizacao = new Date();
        return data;
    },

    async saveProduto(id, data) {
        if (id) {
            await db.collection('produtos').doc(id).update(data);
        } else {
            await db.collection('produtos').add(data);
        }
        this.limparCache('produtos');
    },

    async registrarSaidaEstoque({ produtoId, quantidade, retiradoPorNome }) {
        return this.registrarMovimentacaoEstoque(produtoId, 'saida', quantidade, 'Saída para uso diário/Limpeza', retiradoPorNome);
    },

    async registrarMovimentacaoEstoque(produtoId, tipo, quantidade, observacao, usuarioNome) {
        const prodDoc = await db.collection('produtos').doc(produtoId).get();
        if (!prodDoc.exists) {
            throw new Error("Produto nï¿½o encontrado");
        }
        const prodData = prodDoc.data();
        const currentQty = typeof prodData.quantidade === 'number' ? prodData.quantidade : 0;
        const newQty = tipo === 'entrada' ? currentQty + quantidade : currentQty - quantidade;

        // Atualiza a quantidade do produto no estoque
        await db.collection('produtos').doc(produtoId).update({
            quantidade: newQty
        });

        // Cria a movimentaï¿½ï¿½o de estoque
        const movimentacao = {
            produtoId,
            produtoNome: prodData.nome,
            setorId: prodData.setorId || 'limpeza',
            tipo,
            quantidade,
            observacao: observacao || '',
            usuarioNome: usuarioNome || 'Sistema',
            dataMovimentacao: firebase.firestore.FieldValue.serverTimestamp()
        };
        await db.collection('historico_estoque').add(movimentacao);
        return newQty;
    },

    async getMovimentacoesEstoque(setorId) {
        let query = db.collection('historico_estoque');
        if (setorId) {
            query = query.where('setorId', '==', setorId);
        }
        const snap = await query.get();
        const list = snap.docs.map(doc => {
            const data = doc.data();
            return {
                id: doc.id,
                ...data,
                dataMovimentacao: this.safeToDate(data.dataMovimentacao, new Date())
            };
        });
        // Ordena em JS (evita índice composto no Firestore)
        list.sort((a, b) => b.dataMovimentacao - a.dataMovimentacao);
        return list.slice(0, 50);
    },

    // --- REPOSIï¿½ï¿½ES CRUD ---
    async getReposicoes() {
        if (this.isCacheValido('reposicoes')) {
            const data = this._obterDoCache('reposicoes');
            if (data) {
                this.cacheStats.leiturasEconomizadas += data.length || 1;
                return data.map(item => ({
                    ...item,
                    dataSolicitacao: this.safeToDate(item.dataSolicitacao, new Date())
                }));
            }
        }
        const snap = await db.collection('reposicoes').get();
        const list = snap.docs.map(doc => {
            const data = doc.data();
            return {
                id: doc.id,
                ...data,
                dataSolicitacao: this.safeToDate(data.dataSolicitacao, new Date())
            };
        });
        // Ordenação em JS (evita necessidade de índice composto no Firestore)
        list.sort((a, b) => b.dataSolicitacao - a.dataSolicitacao);
        this._salvarNoCache('reposicoes', list);
        this.cacheStats.leiturasReais += list.length;
        return list;
    },

    async addReposicao(data) {
        data.dataSolicitacao = firebase.firestore.FieldValue.serverTimestamp();
        data.status = 'Pendente';
        await db.collection('reposicoes').add(data);
        this.limparCache('reposicoes');
    },

    async updateStatusReposicao(id, status) {
        await db.collection('reposicoes').doc(id).update({ status });
        this.limparCache('reposicoes');
    },

    // --- AVISOS CRUD ---
    async getAvisos() {
        if (this.isCacheValido('avisos')) {
            const data = this._obterDoCache('avisos');
            if (data) {
                this.cacheStats.leiturasEconomizadas += data.length || 1;
                return data.map(item => ({
                    ...item,
                    data: this.safeToDate(item.data, new Date())
                }));
            }
        }
        const snap = await db.collection('avisos').get();
        let list = snap.docs.map(doc => {
            const data = doc.data();
            return {
                id: doc.id,
                ...data,
                data: this.safeToDate(data.data, new Date())
            };
        });

        // Filter out expired notices in local timezone date (YYYY-MM-DD)
        const tzOffset = new Date().getTimezoneOffset() * 60000;
        const hojeStr = new Date(Date.now() - tzOffset).toISOString().split('T')[0];
        list = list.filter(item => {
            if (!item.dataExpiracao) return true;
            return item.dataExpiracao >= hojeStr;
        });

        // Sort by date descending
        list.sort((a, b) => b.data - a.data);
        this._salvarNoCache('avisos', list);
        this.cacheStats.leiturasReais += list.length;
        return list;
    },

    async saveAviso(data) {
        data.data = firebase.firestore.FieldValue.serverTimestamp();
        await db.collection('avisos').add(data);
        this.limparCache('avisos');
    },

    async deleteAviso(id) {
        await db.collection('avisos').doc(id).delete();
        this.limparCache('avisos');
    },

    // --- TAREFAS (Zeladoria/Manutenção) CRUD ---
    async getTarefas(setorId = null) {
        let query = db.collection('tarefas');
        if (setorId) {
            query = query.where('setorId', '==', setorId);
        }
        const snap = await query.get();
        let list = snap.docs.map(doc => {
            const data = doc.data();
            return {
                id: doc.id,
                ...data,
                dataCriacao: this.safeToDate(data.dataCriacao, new Date())
            };
        });
        // Sort por dataCriacao decrescente
        list.sort((a, b) => b.dataCriacao - a.dataCriacao);
        return list;
    },

    async saveTarefa(data) {
        data.dataCriacao = firebase.firestore.FieldValue.serverTimestamp();
        await db.collection('tarefas').add(data);
    },

    async updateTarefaStatus(id, newStatus) {
        await db.collection('tarefas').doc(id).update({ status: newStatus });
    },

    async updateTarefa(id, data) {
        await db.collection('tarefas').doc(id).update(data);
    },

    async deleteTarefa(id) {
        await db.collection('tarefas').doc(id).delete();
    },

    // --- CULTOS CRUD ---
    async getCultos(dataInicio = null, dataFim = null) {
        let rawList = [];
        if (this.isCacheValido('cultos')) {
            const cached = this._obterDoCache('cultos');
            if (cached) {
                rawList = cached;
                this.cacheStats.leiturasEconomizadas += rawList.length || 1;
            }
        }
        
        if (rawList.length === 0) {
            const snap = await db.collection('cultos').get();
            rawList = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
            this._salvarNoCache('cultos', rawList);
            this.cacheStats.leiturasReais += rawList.length;
            this.cacheStats.ultimaAtualizacao = new Date();
        }

        let list = [...rawList];
        if (dataInicio && dataFim) {
            list = list.filter(item => item.data >= dataInicio && item.data <= dataFim);
        }
        
        // Ordenar por data e horarioInicio
        list.sort((a, b) => {
            if (a.data !== b.data) return a.data.localeCompare(b.data);
            const tA = a.horarioInicio || '00:00';
            const tB = b.horarioInicio || '00:00';
            return tA.localeCompare(tB);
        });
        
        return list;
    },

    async saveCulto(id, data) {
        if (id) {
            await db.collection('cultos').doc(id).update(data);
            
            // Se o nome do culto mudou, atualizar as escalas vinculadas denormalizadas
            if (data.nome) {
                const escalasSnap = await db.collection('escalas').where('cultoId', '==', id).get();
                if (!escalasSnap.empty) {
                    const batch = db.batch();
                    escalasSnap.docs.forEach(doc => {
                        batch.update(doc.ref, { cultoNome: data.nome });
                    });
                    await batch.commit();
                }
            }
            this.limparCache('cultos');
            this.limparCache('escalas');
            return id;
        } else {
            data.criadoEm = firebase.firestore.FieldValue.serverTimestamp();
            const docRef = await db.collection('cultos').add(data);
            this.limparCache('cultos');
            this.limparCache('escalas');
            return docRef.id;
        }
    },

    async deleteCulto(id) {
        await db.collection('cultos').doc(id).delete();
        
        // Deleta as escalas vinculadas
        const escalasSnap = await db.collection('escalas').where('cultoId', '==', id).get();
        if (!escalasSnap.empty) {
            const batch = db.batch();
            escalasSnap.docs.forEach(doc => {
                batch.delete(doc.ref);
            });
            await batch.commit();
        }
        this.limparCache('cultos');
        this.limparCache('escalas');
    },

    // --- ESCALAS CRUD ---
    async getEscalas(setorId = null, dataInicio = null, dataFim = null, cultoId = null) {
        let rawList = [];
        if (this.isCacheValido('escalas')) {
            const cached = this._obterDoCache('escalas');
            if (cached) {
                rawList = cached;
                this.cacheStats.leiturasEconomizadas += rawList.length || 1;
            }
        }

        if (rawList.length === 0) {
            const snap = await db.collection('escalas').get();
            rawList = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
            this._salvarNoCache('escalas', rawList);
            this.cacheStats.leiturasReais += rawList.length;
            this.cacheStats.ultimaAtualizacao = new Date();
        }

        // Filtro local otimizado e ordenaï¿½ï¿½o em memï¿½ria
        let list = [...rawList];
        if (setorId) {
            list = list.filter(item => item.setorId === setorId);
        }
        if (cultoId) {
            list = list.filter(item => item.cultoId === cultoId);
        }
        if (dataInicio && dataFim && !cultoId) {
            list = list.filter(item => item.data >= dataInicio && item.data <= dataFim);
        }
        
        // Ordena por data e horï¿½rio de inï¿½cio
        list.sort((a, b) => {
            if (a.data !== b.data) return a.data.localeCompare(b.data);
            const tA = a.horarioInicio || '00:00';
            const tB = b.horarioInicio || '00:00';
            return tA.localeCompare(tB);
        });
        
        return list;
    },

    async saveEscala(id, data) {
        if (id) {
            await db.collection('escalas').doc(id).update(data);
        } else {
            await db.collection('escalas').add(data);
        }
        this.limparCache('escalas');
    },

    async deleteEscala(id) {
        await db.collection('escalas').doc(id).delete();
        this.limparCache('escalas');
    },

    async getEscalasDoMembro(membroId) {
        const escalas = await this.getEscalas();
        return escalas.filter(e => e.membroId === membroId);
    },

    async updatePresenca(id, statusPresenca) {
        const updateData = { statusPresenca };
        if (statusPresenca === 'Recusada') {
            updateData.rejeicaoResolvida = false;
        }
        await db.collection('escalas').doc(id).update(updateData);
        this.limparCache('escalas');
    },

    // --- SERVIÇOS & EXECUÇÃO ---
    async iniciarServico(escalaId, membroId, membroNome, setorId, funcao, data, horarioInicio, horarioFim) {
        const agora = new Date();
        const horaReal = `${String(agora.getHours()).padStart(2, '0')}:${String(agora.getMinutes()).padStart(2, '0')}`;
        
        // Update Escala status apenas se for uma escala real
        if (escalaId && escalaId !== 'extra') {
            await db.collection('escalas').doc(escalaId).update({
                statusServico: 'Em andamento'
            });
        }

        // Add to active services
        const servicoRef = await db.collection('servicos').add({
            escalaId,
            membroId,
            membroNome,
            setorId,
            funcao,
            data,
            horarioInicio,
            horarioInicioReal: horaReal,
            horarioFim,
            iniciadoEm: firebase.firestore.FieldValue.serverTimestamp(),
            status: 'Em andamento',
            observacoes: ""
        });
        
        if (setorId === 'limpeza' || setorId === 'manutencao') {
            await this.saveAviso({
                titulo: "🟢 Início de Expediente Operacional",
                conteudo: `O membro ${membroNome} iniciou seu serviço de ${funcao} no setor ${setorId} às ${horaReal}.`,
                tipo: "info",
                dataCriacao: agora.toISOString()
            });
        }

        return servicoRef.id;
    },

    async finalizarServico(servicoId, escalaId, observacoes) {
        const agora = firebase.firestore.FieldValue.serverTimestamp();
        
        // Update service
        await db.collection('servicos').doc(servicoId).update({
            finalizadoEm: agora,
            status: 'Finalizado',
            observacoes: observacoes
        });

        // Update corresponding scale
        if (escalaId && escalaId !== 'extra') {
            await db.collection('escalas').doc(escalaId).update({
                statusServico: 'Finalizado',
                observacoes: observacoes
            });
        }
    },

    async fecharCulto(cultoId, statusEscalas) {
        await db.collection('cultos').doc(cultoId).update({
            status: 'Finalizado',
            fechadoEm: firebase.firestore.FieldValue.serverTimestamp()
        });

        const batch = db.batch();
        statusEscalas.forEach(item => {
            const escalaRef = db.collection('escalas').doc(item.escalaId);
            batch.update(escalaRef, {
                statusPresenca: item.statusPresenca,
                statusServico: 'Finalizado'
            });
        });

        await batch.commit();

        this.limparCache('cultos');
        this.limparCache('escalas');
    },

    async getServicosEmAndamento() {
        const snap = await db.collection('servicos')
            .where('status', '==', 'Em andamento')
            .get();
        return snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    },

    async getHistoricoServicos() {
        const snap = await db.collection('servicos')
            .where('status', '==', 'Finalizado')
            .get();
        
        let list = snap.docs.map(doc => {
            const data = doc.data();
            return {
                id: doc.id,
                ...data,
                iniciadoEm: this.safeToDate(data.iniciadoEm, null),
                finalizadoEm: this.safeToDate(data.finalizadoEm, null)
            };
        });

        // Sort by finalization date descending
        list.sort((a, b) => {
            if (!a.finalizadoEm) return 1;
            if (!b.finalizadoEm) return -1;
            return b.finalizadoEm - a.finalizadoEm;
        });

        return list;
    },

    async getRepositores() {
        // Aproveita o cache de membros em vez de realizar query Firestore adicional
        const todos = await this.getMembros();
        return todos.filter(m => m.eRepositor === true && m.status === 'ativo');
    },

    async addNotificacao(data) {
        data.data = firebase.firestore.FieldValue.serverTimestamp();
        data.lida = false;
        await db.collection('notificacoes').add(data);
    },

    async getNotificacoesUsuario(usuarioId) {
        const snap = await db.collection('notificacoes')
            .where('paraUsuarioId', '==', usuarioId)
            .get();
        const list = snap.docs.map(doc => {
            const data = doc.data();
            return {
                id: doc.id,
                ...data,
                data: this.safeToDate(data.data, new Date())
            };
        });
        // Ordena em JS (evita índice composto no Firestore)
        list.sort((a, b) => b.data - a.data);
        return list.slice(0, 30);
    },

    async marcarNotificacoesComoLidas(usuarioId) {
        const snap = await db.collection('notificacoes')
            .where('paraUsuarioId', '==', usuarioId)
            .where('lida', '==', false)
            .get();
        
        if (snap.empty) return;
        
        const batch = db.batch();
        snap.docs.forEach(doc => {
            batch.update(db.collection('notificacoes').doc(doc.id), { lida: true });
        });
        await batch.commit();
    },

    // --- STANDBY / VOLUNTARIADO (CES Diaconia v3.2) ---
    async saveStandby(data) {
        data.criadoEm = firebase.firestore.FieldValue.serverTimestamp();
        await db.collection('disponibilidades').add(data);
    },

    async getStandbys() {
        const snap = await db.collection('disponibilidades').get();
        return snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    },

    async deleteStandby(id) {
        await db.collection('disponibilidades').doc(id).delete();
    },

    // --- MENSAGENS PARA A SUPERVISï¿½O (CES Diaconia v3.2) ---
    async saveSupervisionMessage(membroId, membroNome, content) {
        const msg = {
            membroId,
            membroNome,
            conteudo: content,
            lida: false,
            criadoEm: firebase.firestore.FieldValue.serverTimestamp()
        };
        await db.collection('mensagens_supervisao').add(msg);
    },

    async getSupervisionMessages(somenteNaoLidas = true) {
        let query = db.collection('mensagens_supervisao');
        if (somenteNaoLidas) {
            query = query.where('lida', '==', false);
        }
        const snap = await query.get();
        let list = snap.docs.map(doc => {
            const data = doc.data();
            return {
                id: doc.id,
                ...data,
                criadoEm: this.safeToDate(data.criadoEm, new Date())
            };
        });
        list.sort((a, b) => b.criadoEm - a.criadoEm);
        return list;
    },

    async marcarMensagemComoLida(id) {
        await db.collection('mensagens_supervisao').doc(id).update({ lida: true });
    },

    async getMuralConfig() {
        if (this.isCacheValido('muralConfig')) {
            const data = this._obterDoCache('muralConfig');
            if (data) {
                this.cacheStats.leiturasEconomizadas += 1;
                return data;
            }
        }
        try {
            const doc = await db.collection('configuracoes').doc('mural').get();
            const result = doc.exists ? doc.data() : null;
            if (result) {
                this._salvarNoCache('muralConfig', result);
                this.cacheStats.leiturasReais += 1;
            }
            return result;
        } catch (e) {
            console.error("Erro ao buscar configuracoes do mural:", e);
            return null;
        }
    },

    async saveMuralConfig(data) {
        await db.collection('configuracoes').doc('mural').set(data);
        this.limparCache('muralConfig');
    },

    // --- HISTï¿½RICO DE SUBSTITUIï¿½ï¿½ES ---
    async addSubstituicaoLog(logData) {
        logData.dataHora = firebase.firestore.FieldValue.serverTimestamp();
        await db.collection('historico_substituicoes').add(logData);
    },

    async getSubstituicoesHistorico() {
        const snap = await db.collection('historico_substituicoes').orderBy('dataHora', 'desc').limit(100).get();
        return snap.docs.map(doc => {
            const data = doc.data();
            return {
                id: doc.id,
                ...data,
                dataHora: this.safeToDate(data.dataHora, new Date())
            };
        });
    },

    // --- HISTÓRICO DE AFASTAMENTOS ---
    async saveAfastamento(membroId, data) {
        data.dataRegistro = new Date().toISOString();
        await db.collection('membros').doc(membroId).update({
            statusOperacional: data.statusOperacional,
            afastamentoInicio: data.afastamentoInicio || '',
            afastamentoFim: data.afastamentoFim || '',
            afastamentoMotivo: data.afastamentoMotivo || '',
            afastamentoObsSupervisao: data.afastamentoObsSupervisao || '',
            afastamentoRetornoAutomativo: data.afastamentoRetornoAutomativo || 'Sim',
            afastamentosHistorico: firebase.firestore.FieldValue.arrayUnion(data)
        });
        this.limparCache('membros');
    },

    async getHistoricoAfastamentos() {
        // Aproveita o cache de membros em vez de realizar nova leitura Firestore
        const membros = await this.getMembros();
        const list = [];
        membros.forEach(m => {
            if (m.afastamentosHistorico && Array.isArray(m.afastamentosHistorico)) {
                m.afastamentosHistorico.forEach(af => {
                    list.push({
                        membroId: m.id,
                        membroNome: m.nome,
                        ...af
                    });
                });
            } else if (m.afastamento) {
                list.push({
                    membroId: m.id,
                    membroNome: m.nome,
                    ...m.afastamento
                });
            }
        });
        list.sort((a, b) => {
            const dateA = a.dataRegistro || '';
            const dateB = b.dataRegistro || '';
            return dateB.localeCompare(dateA);
        });
        return list;
    },

    // --- SCORE DE CONFIABILIDADE (Fase 2) ---
    // Calcula score 0-100 baseado nos ï¿½ltimos 12 meses de escalas do membro.
    // Requer mï¿½nimo de 5 escalas para classificaï¿½ï¿½o efetiva.
    // Retorna { score, classificacao, total, confirmadas, recusadas, faltas, emAvaliacao }
    calcularScoreConfiabilidade(escalasDoMembro) {
        const hoje = new Date();
        const dozeAtras = new Date(hoje);
        dozeAtras.setFullYear(dozeAtras.getFullYear() - 1);
        const dozeAtrasStr = dozeAtras.toISOString().split('T')[0];

        const escalas12m = escalasDoMembro.filter(e => e.data >= dozeAtrasStr);

        const total = escalas12m.length;
        if (total < 5) {
            return { score: null, classificacao: 'Em avaliaï¿½ï¿½o', total, confirmadas: 0, recusadas: 0, faltas: 0, emAvaliacao: true };
        }

        const confirmadas = escalas12m.filter(e => e.statusPresenca === 'Confirmada').length;
        const recusadas   = escalas12m.filter(e => e.statusPresenca === 'Recusada').length;
        const faltas      = escalas12m.filter(e => e.statusPresenca === 'Ausente').length;

        // Pontuaï¿½ï¿½o ponderada:
        //   +40 pts por confirmaï¿½ï¿½o normalizada
        //   +20 pts por presenï¿½a (escalas sem recusa/falta)
        //   -25 pts por cancelamento
        //   -35 pts por falta injustificada
        const pontos = (confirmadas * 40) + ((total - recusadas - faltas) * 20) - (recusadas * 25) - (faltas * 35);
        const maxPontos = total * 60; // mï¿½ximo teï¿½rico (todas confirmadas)
        let score = maxPontos > 0 ? Math.round((pontos / maxPontos) * 100) : 50;
        score = Math.max(0, Math.min(100, score));

        let classificacao;
        if (score >= 80) classificacao = 'Excelente';
        else if (score >= 60) classificacao = 'Bom';
        else if (score >= 40) classificacao = 'Regular';
        else classificacao = 'Crï¿½tico';

        return { score, classificacao, total, confirmadas, recusadas, faltas, emAvaliacao: false };
    },

    // Persiste o score calculado de volta no documento do membro
    async salvarScoreConfiabilidade(membroId, scoreData) {
        await db.collection('membros').doc(membroId).update({
            scoreConfiabilidade: scoreData.score,
            scoreClassificacao: scoreData.classificacao,
            scoreAtualizadoEm: firebase.firestore.FieldValue.serverTimestamp()
        });
    },

    // --- INDISPONIBILIDADE MENSAL (Fase 2) ---
    // diasMap: { "2026-06-08": "nao_posso" | "prefiro_nao" | "posso" }
    async saveIndisponibilidade(membroId, diasMap) {
        await db.collection('membros').doc(membroId).update({
            indisponibilidades_mensais: diasMap,
            indisponibilidadeAtualizadoEm: firebase.firestore.FieldValue.serverTimestamp()
        });
    },

    async getIndisponibilidades(membroId) {
        // Consulta cache de membros antes de ir ao Firestore
        if (this.isCacheValido('membros')) {
            const cached = this._obterDoCache('membros');
            if (cached) {
                const m = cached.find(x => x.id === membroId);
                if (m) return m.indisponibilidades_mensais || {};
            }
        }
        const doc = await db.collection('membros').doc(membroId).get();
        if (!doc.exists) return {};
        return doc.data().indisponibilidades_mensais || {};
    },

    // Retorna mapa { membroId: { nome, diasMap } } para visï¿½o do admin
    async getAllIndisponibilidades() {
        // Aproveita o cache de membros em vez de realizar nova leitura Firestore
        const membros = await this.getMembros();
        const result = {};
        membros.forEach(m => {
            if (m.indisponibilidades_mensais && Object.keys(m.indisponibilidades_mensais).length > 0) {
                result[m.id] = {
                    nome: m.nome,
                    diasMap: m.indisponibilidades_mensais
                };
            }
        });
        return result;
    },

    // --- ARQUIVAMENTO SEGURO DE DADOS HISTï¿½RICOS (Fase 2.1) ---
    // Mover de 'escalas' para 'escalas_arquivadas' dados com mais de 14 meses (margem de seguranï¿½a para o score de 12 meses)
    async arquivarDadosHistoricos() {
        const hoje = new Date();
        const catorzeMesesAtras = new Date(hoje);
        catorzeMesesAtras.setMonth(catorzeMesesAtras.getMonth() - 14);
        const dataLimiteStr = catorzeMesesAtras.toISOString().split('T')[0];

        console.log(`[Arquivamento] Buscando escalas anteriores a: ${dataLimiteStr}`);
        const snap = await db.collection('escalas')
            .where('data', '<', dataLimiteStr)
            .get();

        if (snap.empty) {
            console.log("[Arquivamento] Nenhuma escala para arquivar.");
            await this.registrarControleArquivamento(0);
            return 0;
        }

        let totalArquivado = 0;
        for (let doc of snap.docs) {
            const data = doc.data();
            const docId = doc.id;

            // 1. Grava cï¿½pia exata na coleï¿½ï¿½o 'escalas_arquivadas'
            await db.collection('escalas_arquivadas').doc(docId).set({
                ...data,
                arquivadoEm: firebase.firestore.FieldValue.serverTimestamp()
            });

            // 2. Valida gravaï¿½ï¿½o bem sucedida (lendo de volta)
            const validationDoc = await db.collection('escalas_arquivadas').doc(docId).get();
            if (validationDoc.exists) {
                // 3. Confirmada a gravaï¿½ï¿½o segura, remove original
                await db.collection('escalas').doc(docId).delete();
                totalArquivado++;
            } else {
                console.error(`[Arquivamento] Falha crï¿½tica de validaï¿½ï¿½o para a escala: ${docId}. Cancelando remoï¿½ï¿½o original.`);
            }
        }

        await this.registrarControleArquivamento(totalArquivado);
        this.limparCache('escalas');
        return totalArquivado;
    },

    async registrarControleArquivamento(total) {
        await db.collection('controle_arquivamento').add({
            executadoEm: firebase.firestore.FieldValue.serverTimestamp(),
            totalDocumentosArquivados: total,
            status: 'Sucesso'
        });
    },

    async getUltimoArquivamento() {
        try {
            const snap = await db.collection('controle_arquivamento')
                .orderBy('executadoEm', 'desc')
                .limit(1)
                .get();

            if (snap.empty) return null;
            const data = snap.docs[0].data();
            return {
                executadoEm: this.safeToDate(data.executadoEm, null),
                total: data.totalDocumentosArquivados,
                status: data.status
            };
        } catch(e) {
            console.error(e);
            return null;
        }
    },

    async getMetricasSaudeSistema() {
        try {
            // Reutiliza caches de membros, escalas e produtos (evita 3 leituras Firestore)
            const [membros, escalas, produtos] = await Promise.all([
                this.getMembros(),
                this.getEscalas(),
                this.getProdutos()
            ]);

            // escalas_arquivadas nao tem cache dedicado -- leitura direta necessaria
            const arquivadosSnap = await db.collection('escalas_arquivadas').get();

            return {
                membrosAtivos: membros.length,
                escalasAtivas: escalas.length,
                produtosCadastrados: produtos.length,
                escalasArquivadas: arquivadosSnap.size,
                totalDocumentos: membros.length + escalas.length + produtos.length + arquivadosSnap.size
            };
        } catch (e) {
            console.error("Erro ao computar metricas de saude:", e);
            return {
                membrosAtivos: 0,
                escalasAtivas: 0,
                produtosCadastrados: 0,
                escalasArquivadas: 0,
                totalDocumentos: 0
            };
        }
    }
};



