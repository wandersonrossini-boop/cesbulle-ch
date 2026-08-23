import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/auth_api_service.dart';
import '../../services/contributor_api_service.dart';
import '../widgets/app_sidebar_drawer.dart';
import 'login_page.dart';
import '../../utils/file_download_helper.dart';

class MembersPage extends StatefulWidget {
  const MembersPage({super.key});

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  final ContributorApiService _apiService = ContributorApiService();
  List<ContributorModel> _allContributors = [];
  List<ContributorModel> _filtered = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContributors();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _allContributors
          .where((c) =>
              c.fullName.toLowerCase().contains(q) ||
              c.contributorNumber.toLowerCase().contains(q))
          .toList();
    });
  }

  Future<void> _loadContributors() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _apiService.fetchContributors();
      setState(() {
        _allContributors = list;
        _filtered = list;
        _isLoading = false;
      });
    } catch (e) {
      if (e.toString().contains('UNAUTHORIZED') && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sessão expirada. Faça login novamente.'),
            backgroundColor: Color(0xFFDC2626),
            duration: Duration(seconds: 2),
          ),
        );
        await Future.delayed(const Duration(seconds: 2));
        await AuthApiService().logout();
        if (mounted) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
        }
        return;
      }
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showAddEditDialog(ContributorModel? item) {
    final isEdit = item != null;
    final nameCtrl = TextEditingController(text: item?.fullName ?? '');
    final numberCtrl = TextEditingController(text: item?.contributorNumber ?? '');
    final addressCtrl = TextEditingController(text: item?.address ?? '');
    final zipCtrl = TextEditingController(text: item?.postalCode ?? '');
    final cityCtrl = TextEditingController(text: item?.city ?? '');
    final emailCtrl = TextEditingController(text: item?.email ?? '');
    final phoneCtrl = TextEditingController(text: item?.phone ?? '');
    bool active = item?.active ?? true;
    bool isSaving = false;
    String? dlgError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(isEdit ? 'Editar Contribuinte' : 'Novo Contribuinte',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nome Completo', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: numberCtrl,
                    decoration: const InputDecoration(labelText: 'Nº Contribuinte (Único)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(labelText: 'Endereço', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: zipCtrl,
                          decoration: const InputDecoration(labelText: 'NPA', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: cityCtrl,
                          decoration: const InputDecoration(labelText: 'Cidade', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Telefone', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: active,
                        onChanged: (val) {
                          if (val != null) setModalState(() => active = val);
                        },
                      ),
                      const Text('Ativo'),
                    ],
                  ),
                  if (dlgError != null) ...[
                    const SizedBox(height: 8),
                    Text(dlgError!, style: const TextStyle(color: AppTheme.excludeRed, fontSize: 13)),
                  ]
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('CANCELAR'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final name = nameCtrl.text.trim();
                        final numStr = numberCtrl.text.trim();
                        if (name.isEmpty || numStr.isEmpty) return;

                        setModalState(() {
                          isSaving = true;
                          dlgError = null;
                        });

                        final model = ContributorModel(
                          id: item?.id ?? '',
                          fullName: name,
                          contributorNumber: numStr,
                          address: addressCtrl.text.trim(),
                          postalCode: zipCtrl.text.trim(),
                          city: cityCtrl.text.trim(),
                          email: emailCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          active: active,
                        );

                        try {
                          if (isEdit) {
                            await _apiService.updateContributor(item.id, model);
                          } else {
                            await _apiService.createContributor(model);
                          }
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            _loadContributors();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(isEdit ? 'Contribuinte atualizado!' : 'Contribuinte adicionado!')),
                            );
                          }
                        } catch (e) {
                          setModalState(() {
                            isSaving = false;
                            dlgError = e.toString().replaceFirst('Exception: ', '');
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                child: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('SALVAR', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAttestationDialog(ContributorModel contributor) async {
    int year = DateTime.now().year;
    bool isGenerating = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            title: const Text('Emitir Attestation de Dons', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Selecione o ano fiscal para ${contributor.fullName}:'),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: year,
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Ano Fiscal'),
                  items: [
                    DropdownMenuItem(value: year, child: Text('$year')),
                    DropdownMenuItem(value: year - 1, child: Text('${year - 1}')),
                    DropdownMenuItem(value: year - 2, child: Text('${year - 2}')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDlgState(() => year = val);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isGenerating ? null : () => Navigator.pop(ctx),
                child: const Text('CANCELAR'),
              ),
              ElevatedButton(
                onPressed: isGenerating
                    ? null
                    : () async {
                        setDlgState(() => isGenerating = true);
                        try {
                          final pdfBytes = await _apiService.downloadAttestationPdf(contributor.id, year);
                          downloadFile(pdfBytes, 'attestation_${contributor.contributorNumber}_$year.pdf');
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Attestation baixada com sucesso!')),
                            );
                          }
                        } catch (e) {
                          setDlgState(() => isGenerating = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erro ao baixar PDF: $e'), backgroundColor: AppTheme.excludeRed),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
                child: isGenerating
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('GERAR PDF', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(ContributorModel contributor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desativar Contribuinte'),
        content: Text('Tem certeza que deseja desativar o contribuinte ${contributor.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.excludeRed, foregroundColor: Colors.white),
            child: const Text('DESATIVAR'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final updated = ContributorModel(
          id: contributor.id,
          fullName: contributor.fullName,
          contributorNumber: contributor.contributorNumber,
          address: contributor.address,
          postalCode: contributor.postalCode,
          city: contributor.city,
          email: contributor.email,
          phone: contributor.phone,
          active: false,
        );
        await _apiService.updateContributor(contributor.id, updated);
        _loadContributors();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contribuinte desativado com sucesso.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao desativar: $e'), backgroundColor: AppTheme.excludeRed),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = _buildErrorState();
    } else {
      body = _buildContent(isDesktop);
    }

    if (isDesktop) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSidebarDrawer(activeRoute: 'contribuintes', permanent: true),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      drawer: isDesktop ? null : const AppSidebarDrawer(activeRoute: 'contribuintes'),
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F172A),
              elevation: 0,
              shape: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
              title: const Text(
                'Contribuintes',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
              ),
            ),
      body: body,
      floatingActionButton: isDesktop ? null : FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(null),
        backgroundColor: AppTheme.primaryGreen,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('NOVO CONTRIBUINTE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 56, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 16),
          const Text(
            'Falha ao carregar contribuintes',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Verifique sua conexão e tente novamente.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadContributors,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar Novamente'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDesktop) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 40 : 24,
        vertical: isDesktop ? 32 : 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(isDesktop),
              const SizedBox(height: 32),
              _buildSummaryCard(),
              const SizedBox(height: 32),
              _buildContributorList(isDesktop),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MEMBROS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Contribuintes',
              style: TextStyle(
                fontSize: isDesktop ? 24 : 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Gerencie os membros cadastrados na base de dados da tesouraria.',
              style: TextStyle(
                fontSize: isDesktop ? 13 : 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        if (isDesktop)
          ElevatedButton.icon(
            onPressed: () => _showAddEditDialog(null),
            icon: const Icon(Icons.add, color: Colors.white, size: 20),
            label: const Text('NOVO CONTRIBUINTE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.people_rounded, color: Color(0xFF1E3A8A), size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_allContributors.length}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  letterSpacing: -1,
                ),
              ),
              const Text(
                'Contribuintes cadastrados',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContributorList(bool isDesktop) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Pesquisar contribuinte...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF1E3A8A)),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border.symmetric(horizontal: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'NOME',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 1.0),
                  ),
                ),
                if (_filtered.isNotEmpty)
                  Text(
                    '${_filtered.length} de ${_allContributors.length}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
              ],
            ),
          ),
          if (_filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  _searchController.text.isNotEmpty
                      ? 'Nenhum resultado para "${_searchController.text}".'
                      : 'Nenhum contribuinte cadastrado.',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
              itemBuilder: (context, index) => _buildContributorRow(_filtered[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildContributorRow(ContributorModel contributor) {
    final parts = contributor.fullName.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : contributor.fullName.substring(0, 1).toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contributor.fullName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Nº ${contributor.contributorNumber} • ${contributor.city}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                color: const Color(0xFF1E3A8A),
                tooltip: 'Emitir Attestation',
                onPressed: () => _showAttestationDialog(contributor),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: const Color(0xFF64748B),
                tooltip: 'Editar',
                onPressed: () => _showAddEditDialog(contributor),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: AppTheme.excludeRed,
                tooltip: 'Desativar',
                onPressed: () => _confirmDelete(contributor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
