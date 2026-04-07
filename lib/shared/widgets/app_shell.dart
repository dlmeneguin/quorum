import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/transactions/screens/transactions_screen.dart';
import '../../features/budget/screens/budget_screen.dart';
import '../../features/goals/screens/goals_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/pluggy/providers/pluggy_provider.dart';
import '../../features/pluggy/screens/pluggy_import_screen.dart';
import 'alberto_widgets.dart';
import 'splash_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;
  bool _isReady = false;
  List<Map<String, dynamic>> _pendingPluggyTxs = [];

  final List<_NavItem> _navItems = const [
    _NavItem(icon: LucideIcons.layoutDashboard, label: 'Dashboard'),
    _NavItem(icon: LucideIcons.arrowLeftRight, label: 'Transações'),
    _NavItem(icon: LucideIcons.pieChart, label: 'Orçamento'),
    _NavItem(icon: LucideIcons.target, label: 'Metas'),
    _NavItem(icon: LucideIcons.settings, label: 'Configurações'),
  ];

  final List<Widget> _screens = const [
    DashboardScreen(),
    TransactionsScreen(),
    BudgetScreen(),
    GoalsScreen(),
    SettingsScreen(),
  ];

  Future<void> _initialize() async {
    try {
      final notifier = ref.read(pluggyConfigProvider.notifier);
      final txs = await notifier.fetchNewTransactions();
      _pendingPluggyTxs = txs;
    } catch (e) {
      debugPrint('[AppShell] Erro no initialize: $e');
    }
  }

  void _onSplashDone() {
    setState(() => _isReady = true);

    if (_pendingPluggyTxs.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                PluggyImportScreen(transactions: _pendingPluggyTxs),
            fullscreenDialog: true,
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isReady) {
      return SplashScreen(
        onReady: _initialize,
      );
    }

    final isDesktop = MediaQuery.of(context).size.width >= 600;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: isDesktop
          ? _DesktopLayout(
              navItems: _navItems,
              screens: _screens,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) =>
                  setState(() => _selectedIndex = i),
            )
          : _MobileLayout(
              navItems: _navItems,
              screens: _screens,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) =>
                  setState(() => _selectedIndex = i),
            ),
    );
  }
}

// Layout Windows — sidebar fixa de 220px
class _DesktopLayout extends StatelessWidget {
  final List<_NavItem> navItems;
  final List<Widget> screens;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const _DesktopLayout({
    required this.navItems,
    required this.screens,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSnoopy = colors.primary == AppColors.snoopyPrimary;
    final borderColor =
        isDark ? AppColors.borderDark : AppColors.borderLight;

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 220,
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(
                right: BorderSide(color: borderColor),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                  child: Text(
                    'Quórum',
                    style: AppTextStyles.splineSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 8),
                ...navItems.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final isSelected = i == selectedIndex;

                  return _SidebarItem(
                    icon: item.icon,
                    label: item.label,
                    isSelected: isSelected,
                    onTap: () => onDestinationSelected(i),
                  );
                }),

                if (isSnoopy) ...[
                  const Spacer(),
                  const AlbertoSidebarWidget(sidebarWidth: 220),
                ] else
                  const Spacer(),

                const SizedBox(height: 8),
              ],
            ),
          ),
          Expanded(child: screens[selectedIndex]),
        ],
      ),
    );
  }
}

// Layout Android — bottom navigation bar
class _MobileLayout extends StatelessWidget {
  final List<_NavItem> navItems;
  final List<Widget> screens;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const _MobileLayout({
    required this.navItems,
    required this.screens,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: screens[selectedIndex],
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected
                  ? scheme.primary
                  : (isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight),
              overflow: TextOverflow.ellipsis,
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: navItems
              .map(
                (item) => NavigationDestination(
                  icon: Icon(item.icon),
                  label: item.label,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

// Item do sidebar desktop
class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final textColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? scheme.primary.withOpacity(0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? scheme.primary : secondaryColor,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: AppTextStyles.dmSans(
                  fontSize: 14,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? scheme.primary : textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}