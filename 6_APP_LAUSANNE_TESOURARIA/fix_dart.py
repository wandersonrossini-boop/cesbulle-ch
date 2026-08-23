# -*- coding: utf-8 -*-
path = r'c:\Users\Wande\Documents\ia\6_APP_LAUSANNE_TESOURARIA\tesouraria_cme_app\lib\presentation\pages\closing_detail_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Let's fix the build method
start_build = content.find('  Widget build(BuildContext context) {\n    return Scaffold(')
if start_build == -1:
    print("Could not find build method")
    # let's look for return Scaffold
    start_build = content.find('return Scaffold(')

end_build = content.find('Widget _buildHeader(ServiceClosingDetail detail)')

new_build = """Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Espelho Oficial do Culto'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Compartilhar Relatório',
            onPressed: () {
              final state = context.read<HistoryBloc>().state;
              if (state is HistoryDetailLoaded) {
                _shareClosingDetails(state.detail);
              }
            },
          ),
        ],
      ),
      body: BlocConsumer<HistoryBloc, HistoryState>(
        listener: (context, state) {
          if (state is HistoryError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
          } else if (state is HistoryDeleteSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fechamento excluído com sucesso.")));
            Navigator.of(context).pop(true);
          }
        },
        builder: (context, state) {
          if (state is HistoryDetailLoading || state is HistoryInitial || state is HistoryDeleting) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is HistoryDetailLoaded) {
            final detail = state.detail;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(detail),
                      const SizedBox(height: 24),
                      _buildIdentifiedSection(detail),
                      const SizedBox(height: 24),
                      _buildUnidentifiedSection(detail),
                      const SizedBox(height: 24),
                      _buildSummarySection(detail),
                    ],
                  ),
                ),
              ),
            );
          }
          return const Center(child: Text("Erro ao carregar detalhes."));
        },
      ),
    );
  }

  """

if start_build != -1 and end_build != -1:
    content = content[:start_build] + new_build + content[end_build:]
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Fixed closing_detail_page.dart")
else:
    print("Failed to replace build method")

