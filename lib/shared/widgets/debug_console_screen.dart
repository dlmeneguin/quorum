import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/app_logger.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class DebugConsoleScreen extends StatefulWidget {
  const DebugConsoleScreen({super.key});

  @override
  State<DebugConsoleScreen> createState() => _DebugConsoleScreenState();
}

class _DebugConsoleScreenState extends State<DebugConsoleScreen> {
  final _scrollController = ScrollController();
  late final List<LogEntry> _entries;
  late final StreamSubscription<LogEntry> _sub;
  bool _autoScroll = true;
  String _filter = 'all';

  static const _categories = [
    ('all', 'Todos'),
    ('sync', '[Sync]'),
    ('auth', '[Auth]'),
    ('drive', '[Drive]'),
    ('pluggy', 'Pluggy'),
    ('error', 'Erro'),
  ];

  @override
  void initState() {
    super.initState();
    _entries = List.from(AppLogger.history);
    _sub = AppLogger.stream.listen((entry) {
      if (!mounted) return;
      setState(() => _entries.add(entry));
      if (_autoScroll) _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<LogEntry> get _filtered {
    if (_filter == 'all') return _entries;
    return _entries.where((e) {
      switch (_filter) {
        case 'sync':
          return e.category == LogCategory.sync;
        case 'auth':
          return e.category == LogCategory.auth;
        case 'drive':
          return e.category == LogCategory.drive;
        case 'pluggy':
          return e.category == LogCategory.pluggy;
        case 'error':
          return e.category == LogCategory.error;
        default:
          return true;
      }
    }).toList();
  }

  void _copyAll() {
    final text = _filtered
        .map((e) =>
            '[${_formatTime(e.timestamp)}] ${e.message}')
        .join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logs copiados para a área de transferência'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _clear() {
    setState(() {
      _entries.clear();
      AppLogger.history.clear();
    });
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final ms = dt.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  Color _colorForCategory(LogCategory cat) {
    switch (cat) {
      case LogCategory.sync:
        return const Color(0xFF4ADE80); // verde
      case LogCategory.auth:
        return const Color(0xFF60A5FA); // azul
      case LogCategory.drive:
        return const Color(0xFFA78BFA); // roxo
      case LogCategory.pluggy:
        return const Color(0xFFFBBF24); // âmbar
      case LogCategory.error:
        return const Color(0xFFF87171); // vermelho
      case LogCategory.general:
        return const Color(0xFF9CA3AF); // cinza
    }
  }

  String _labelForCategory(LogCategory cat) {
    switch (cat) {
      case LogCategory.sync:
        return 'SYNC';
      case LogCategory.auth:
        return 'AUTH';
      case LogCategory.drive:
        return 'DRIVE';
      case LogCategory.pluggy:
        return 'PLUGGY';
      case LogCategory.error:
        return 'ERRO';
      case LogCategory.general:
        return 'LOG';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: Row(
          children: [
            const Icon(Icons.terminal, size: 18, color: Color(0xFF4ADE80)),
            const SizedBox(width: 8),
            Text(
              'Console de Debug',
              style: AppTextStyles.splineSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFF0F6FF),
              ),
            ),
          ],
        ),
        actions: [
          // Auto-scroll toggle
          IconButton(
            onPressed: () =>
                setState(() => _autoScroll = !_autoScroll),
            icon: Icon(
              Icons.vertical_align_bottom,
              size: 20,
              color: _autoScroll
                  ? const Color(0xFF4ADE80)
                  : const Color(0xFF6B7280),
            ),
            tooltip: _autoScroll
                ? 'Auto-scroll ativo'
                : 'Auto-scroll inativo',
          ),
          IconButton(
            onPressed: _copyAll,
            icon: const Icon(Icons.copy, size: 18,
                color: Color(0xFF9CA3AF)),
            tooltip: 'Copiar tudo',
          ),
          IconButton(
            onPressed: _clear,
            icon: const Icon(Icons.delete_outline,
                size: 18, color: Color(0xFF9CA3AF)),
            tooltip: 'Limpar',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            color: const Color(0xFF161B22),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: _categories.map((cat) {
                  final (key, label) = cat;
                  final isSelected = _filter == key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _filter = key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.25)
                              : const Color(0xFF21262D),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : const Color(0xFF30363D),
                          ),
                        ),
                        child: Text(
                          label,
                          style: AppTextStyles.dmSans(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? AppColors.primary
                                : const Color(0xFF8B949E),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
      body: filtered.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.terminal,
                      size: 48, color: Color(0xFF30363D)),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum log ainda',
                    style: AppTextStyles.body(const Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Os logs aparecerão aqui em tempo real',
                    style:
                        AppTextStyles.label(const Color(0xFF484F58)),
                  ),
                ],
              ),
            )
          : NotificationListener<ScrollNotification>(
              onNotification: (notif) {
                if (notif is ScrollUpdateNotification) {
                  final atBottom =
                      _scrollController.position.pixels >=
                          _scrollController.position.maxScrollExtent - 40;
                  if (_autoScroll != atBottom) {
                    setState(() => _autoScroll = atBottom);
                  }
                }
                return false;
              },
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final entry = filtered[index];
                  final color = _colorForCategory(entry.category);
                  final label = _labelForCategory(entry.category);

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Timestamp
                        Text(
                          _formatTime(entry.timestamp),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: Color(0xFF484F58),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Badge categoria
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Mensagem
                        Expanded(
                          child: SelectableText(
                            entry.message,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: color,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}