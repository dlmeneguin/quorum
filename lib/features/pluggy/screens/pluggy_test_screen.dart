import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../core/utils/currency.dart';
import '../services/pluggy_service.dart';

class PluggyTestScreen extends StatefulWidget {
  const PluggyTestScreen({super.key});

  @override
  State<PluggyTestScreen> createState() => _PluggyTestScreenState();
}

class _PluggyTestScreenState extends State<PluggyTestScreen> {
  final _clientIdController = TextEditingController();
  final _clientSecretController = TextEditingController();
  final _itemIdController = TextEditingController();

  bool _loading = false;
  String? _error;
  String? _apiKey;

  // Dados recuperados da API
  Map<String, dynamic>? _identity;
  List<Map<String, dynamic>> _accounts = [];
  // accountId → lista de transações
  final Map<String, List<Map<String, dynamic>>> _transactionsByAccount = {};
  // accountId selecionado para ver transações
  String? _selectedAccountId;

  static const _prefClientId = 'pluggy_client_id';
  static const _prefClientSecret = 'pluggy_client_secret';
  static const _prefItemId = 'pluggy_item_id';

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _clientIdController.text = prefs.getString(_prefClientId) ?? '';
      _clientSecretController.text = prefs.getString(_prefClientSecret) ?? '';
      _itemIdController.text = prefs.getString(_prefItemId) ?? '';
    });
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefClientId, _clientIdController.text.trim());
    await prefs.setString(_prefClientSecret, _clientSecretController.text.trim());
    await prefs.setString(_prefItemId, _itemIdController.text.trim());
  }

  Future<void> _connect() async {
    final clientId = _clientIdController.text.trim();
    final clientSecret = _clientSecretController.text.trim();
    final itemId = _itemIdController.text.trim();

    if (clientId.isEmpty || clientSecret.isEmpty || itemId.isEmpty) {
      setState(() => _error = 'Preencha todos os campos.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _apiKey = null;
      _identity = null;
      _accounts = [];
      _transactionsByAccount.clear();
      _selectedAccountId = null;
    });

    await _saveCredentials();

    try {
      // 1. Autenticar
      final apiKey = await PluggyService.authenticate(
        clientId: clientId,
        clientSecret: clientSecret,
      );
      setState(() => _apiKey = apiKey);

      // 2. Buscar identidade (pode não existir)
      try {
        final identity = await PluggyService.fetchIdentity(
          apiKey: apiKey,
          itemId: itemId,
        );
        setState(() => _identity = identity);
      } catch (_) {
        // Ignora — nem todos os conectores suportam identity
      }

      // 3. Buscar contas
      final accounts = await PluggyService.fetchAccounts(
        apiKey: apiKey,
        itemId: itemId,
      );
      setState(() {
        _accounts = accounts;
        if (accounts.isNotEmpty) {
          _selectedAccountId = accounts.first['id'] as String?;
        }
      });

      // 4. Buscar transações da primeira conta automaticamente
      if (accounts.isNotEmpty) {
        final firstAccountId = accounts.first['id'] as String;
        final txs = await PluggyService.fetchTransactions(
          apiKey: apiKey,
          accountId: firstAccountId,
        );
        setState(() {
          _transactionsByAccount[firstAccountId] = txs;
        });
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadTransactionsFor(String accountId) async {
    if (_apiKey == null) return;
    if (_transactionsByAccount.containsKey(accountId)) {
      setState(() => _selectedAccountId = accountId);
      return;
    }

    setState(() {
      _loading = true;
      _selectedAccountId = accountId;
    });

    try {
      final txs = await PluggyService.fetchTransactions(
        apiKey: _apiKey!,
        accountId: accountId,
      );
      setState(() => _transactionsByAccount[accountId] = txs);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    _clientSecretController.dispose();
    _itemIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final surfaceColor =
        isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final borderColor =
        isDark ? AppColors.borderDark : AppColors.borderLight;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pluggy — Teste de Integração',
          style: AppTextStyles.sectionTitle(textPrimary),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ── Instrução ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Como configurar',
                  style: AppTextStyles.bodyBold(textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  '1. Conecte seus bancos em meu.pluggy.ai\n'
                  '2. Crie uma conta em dashboard.pluggy.ai\n'
                  '3. Crie uma Application de desenvolvimento\n'
                  '4. Clique em "Preview in Demo" e vincule seu MeuPluggy\n'
                  '5. Copie o client_id, client_secret e o item_id abaixo',
                  style: AppTextStyles.label(textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Formulário ──
          Text('Client ID', style: AppTextStyles.label(textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _clientIdController,
            decoration: InputDecoration(
              hintText: 'ex: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
              hintStyle: AppTextStyles.label(textSecondary),
            ),
            style: AppTextStyles.body(textPrimary),
          ),
          const SizedBox(height: 16),

          Text('Client Secret', style: AppTextStyles.label(textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _clientSecretController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'ex: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
              hintStyle: AppTextStyles.label(textSecondary),
            ),
            style: AppTextStyles.body(textPrimary),
          ),
          const SizedBox(height: 16),

          Text('Item ID', style: AppTextStyles.label(textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _itemIdController,
            decoration: InputDecoration(
              hintText: 'ex: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
              hintStyle: AppTextStyles.label(textSecondary),
            ),
            style: AppTextStyles.body(textPrimary),
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _loading ? null : _connect,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sync_rounded, size: 18),
              label: Text(
                _loading ? 'Conectando...' : 'Conectar e buscar dados',
                style: AppTextStyles.bodyBold(Colors.white),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

          // ── Erro ──
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.danger.withOpacity(0.3)),
              ),
              child: Text(_error!,
                  style: AppTextStyles.label(AppColors.danger)),
            ),
          ],

          // ── Identidade ──
          if (_identity != null) ...[
            const SizedBox(height: 24),
            _SectionCard(
              title: 'Identidade',
              icon: Icons.person_outline,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              child: _buildIdentityContent(_identity!, textPrimary, textSecondary),
            ),
          ],

          // ── Contas ──
          if (_accounts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Contas encontradas (${_accounts.length})',
                style: AppTextStyles.sectionTitle(textPrimary)),
            const SizedBox(height: 10),
            ..._accounts.map((account) {
              final accountId = account['id'] as String? ?? '';
              final isSelected = accountId == _selectedAccountId;
              final type = account['type'] as String? ?? '?';
              final name = account['name'] as String? ?? 'Sem nome';
              final balance = (account['balance'] as num?)?.toDouble() ?? 0.0;
              final currency = account['currencyCode'] as String? ?? 'BRL';
              final subtype = account['subtype'] as String?;

              return GestureDetector(
                onTap: () => _loadTransactionsFor(accountId),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.07)
                        : surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.4)
                          : borderColor,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _colorForType(type).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _iconForType(type),
                          color: _colorForType(type),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style:
                                    AppTextStyles.bodyBold(textPrimary),
                                overflow: TextOverflow.ellipsis),
                            Text(
                              '${_labelForType(type)}${subtype != null ? ' · $subtype' : ''}',
                              style: AppTextStyles.label(textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            CurrencyUtils.format(balance),
                            style: AppTextStyles.bodyBold(
                              balance < 0
                                  ? AppColors.danger
                                  : textPrimary,
                            ),
                          ),
                          Text(currency,
                              style: AppTextStyles.label(textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],

          // ── Transações ──
          if (_selectedAccountId != null &&
              _transactionsByAccount.containsKey(_selectedAccountId)) ...[
            const SizedBox(height: 16),
            Builder(builder: (context) {
              final selectedAccount = _accounts.firstWhere(
                (a) => a['id'] == _selectedAccountId,
                orElse: () => {},
              );
              final accountName =
                  selectedAccount['name'] as String? ?? 'Conta';
              final txs =
                  _transactionsByAccount[_selectedAccountId] ?? [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Últimas transações — $accountName (${txs.length})',
                    style: AppTextStyles.sectionTitle(textPrimary),
                  ),
                  const SizedBox(height: 10),
                  if (txs.isEmpty)
                    Text('Nenhuma transação encontrada.',
                        style: AppTextStyles.body(textSecondary))
                  else
                    ...txs.map((tx) => _buildTransactionTile(
                          tx,
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        )),
                ],
              );
            }),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildIdentityContent(
    Map<String, dynamic> identity,
    Color textPrimary,
    Color textSecondary,
  ) {
    final fullName = identity['fullName'] as String?;
    final taxNumber = identity['taxNumber'] as String?;
    final emails = (identity['emails'] as List?)
        ?.map((e) => e['value'] as String? ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
    final phones = (identity['phoneNumbers'] as List?)
        ?.map((e) => e['value'] as String? ?? '')
        .where((e) => e.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (fullName != null)
          _InfoRow(label: 'Nome', value: fullName, textPrimary: textPrimary, textSecondary: textSecondary),
        if (taxNumber != null)
          _InfoRow(label: 'CPF/CNPJ', value: taxNumber, textPrimary: textPrimary, textSecondary: textSecondary),
        if (emails != null && emails.isNotEmpty)
          _InfoRow(label: 'E-mail', value: emails.join(', '), textPrimary: textPrimary, textSecondary: textSecondary),
        if (phones != null && phones.isNotEmpty)
          _InfoRow(label: 'Telefone', value: phones.join(', '), textPrimary: textPrimary, textSecondary: textSecondary),
      ],
    );
  }

  Widget _buildTransactionTile(
    Map<String, dynamic> tx, {
    required Color surfaceColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final description = tx['description'] as String? ?? 'Sem descrição';
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final type = tx['type'] as String? ?? 'DEBIT';
    final date = tx['date'] as String?;
    final category = tx['category'] as String?;
    final status = tx['status'] as String? ?? '';

    final isCredit = type == 'CREDIT';
    final color = isCredit ? AppColors.success : AppColors.danger;

    String formattedDate = '';
    if (date != null) {
      try {
        final parsed = DateTime.parse(date);
        formattedDate =
            '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
      } catch (_) {
        formattedDate = date;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCredit
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: AppTextStyles.bodyBold(textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    if (formattedDate.isNotEmpty)
                      Text(formattedDate,
                          style: AppTextStyles.label(textSecondary)),
                    if (category != null && category.isNotEmpty) ...[
                      Text(' · ',
                          style: AppTextStyles.label(textSecondary)),
                      Flexible(
                        child: Text(
                          category,
                          style: AppTextStyles.label(textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    if (status == 'PENDING') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('pendente',
                            style: AppTextStyles.dmSans(
                                fontSize: 10,
                                color: AppColors.accent)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'} ${CurrencyUtils.format(amount.abs())}',
            style: AppTextStyles.bodyBold(color),
          ),
        ],
      ),
    );
  }

  Color _colorForType(String type) {
    return switch (type) {
      'BANK' => AppColors.primary,
      'CREDIT' => AppColors.danger,
      _ => AppColors.accent,
    };
  }

  IconData _iconForType(String type) {
    return switch (type) {
      'BANK' => Icons.account_balance_outlined,
      'CREDIT' => Icons.credit_card_outlined,
      _ => Icons.account_balance_wallet_outlined,
    };
  }

  String _labelForType(String type) {
    return switch (type) {
      'BANK' => 'Conta',
      'CREDIT' => 'Cartão de crédito',
      _ => type,
    };
  }
}

// ── Widgets auxiliares ──

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    required this.surfaceColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: AppTextStyles.bodyBold(textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color textPrimary;
  final Color textSecondary;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: AppTextStyles.label(textSecondary)),
          ),
          Expanded(
            child: Text(value, style: AppTextStyles.body(textPrimary)),
          ),
        ],
      ),
    );
  }
}