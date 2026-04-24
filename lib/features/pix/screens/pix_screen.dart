import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:super_clipboard/super_clipboard.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../core/utils/currency.dart';

class PixScreen extends StatefulWidget {
  const PixScreen({super.key});

  @override
  State<PixScreen> createState() => _PixScreenState();
}

class _PixScreenState extends State<PixScreen> {
  final _formKey = GlobalKey<FormState>();
  final _keyController = TextEditingController();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _qrKey = GlobalKey(); 

  int _amountCents = 0;
  String _selectedKeyType = 'cpf';
  String? _pixPayload;
  bool _showQr = false;
  bool _exporting = false;
  bool _copyingImage = false; 

  final _keyTypes = [
    ('cpf', 'CPF', 'Ex: 000.000.000-00'),
    ('cnpj', 'CNPJ', 'Ex: 00.000.000/0001-00'),
    ('phone', 'Telefone', 'Ex: +5511999999999'),
    ('email', 'E-mail', 'Ex: nome@email.com'),
    ('random', 'Chave aleatória', 'Ex: 123e4567-e89b-...'),
  ];

  String _formatCents(int cents) {
    return (cents / 100).toStringAsFixed(2).replaceAll('.', ',');
  }

  void _onAmountChanged(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    _amountCents = int.tryParse(digits) ?? 0;
    final formatted = _formatCents(_amountCents);
    _amountController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    setState(() {});
  }

  String _emvField(String id, String value) {
    final len = value.length.toString().padLeft(2, '0');
    return '$id$len$value';
  }

  String _crc16(String payload) {
    const poly = 0x1021;
    var crc = 0xFFFF;
    for (final char in payload.codeUnits) {
      crc ^= char << 8;
      for (var i = 0; i < 8; i++) {
        if (crc & 0x8000 != 0) {
          crc = ((crc << 1) ^ poly) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  String _buildPixPayload({
    required String key,
    required String name,
    required String city,
    required double? amount,
    required String description,
  }) {
    String normalize(String text) {
      var withDia = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÖØòóôõöøÈÉÊËèéêëÇçÌÍÎÏìíîïÙÚÛÜùúûüÿÑñ';
      var withoutDia = 'AAAAAAaaaaaaOOOOOOooooooEEEEeeeeCcIIIIiiiiUUUUuuuuyNn';
      for (int i = 0; i < withDia.length; i++) {
        text = text.replaceAll(withDia[i], withoutDia[i]);
      }
      return text.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '');
    }

    final cleanKey = key.replaceAll(RegExp(r'[\.\-\/\(\)\s]'), '').trim();
    final pixGui = _emvField('00', 'BR.GOV.BCB.PIX');
    final pixKey = _emvField('01', cleanKey);
    
    String pixDesc = '';
    if (description.isNotEmpty) {
      final normDesc = normalize(description);
      final finalDesc = normDesc.length > 72 ? normDesc.substring(0, 72) : normDesc;
      pixDesc = _emvField('02', finalDesc);
    }
    
    final merchantInfo = _emvField('26', '$pixGui$pixKey$pixDesc');
    final cleanName = normalize(name).trim().toUpperCase();
    final finalName = cleanName.length > 25 ? cleanName.substring(0, 25) : cleanName;
    final cleanCity = normalize(city).trim().toUpperCase();
    final finalCity = cleanCity.length > 15 ? cleanCity.substring(0, 15) : cleanCity;

    var payload = '';
    payload += _emvField('00', '01'); 
    payload += _emvField('01', '11'); 
    payload += merchantInfo;
    payload += _emvField('52', '0000'); 
    payload += _emvField('53', '986');  
    
    if (amount != null && amount > 0) {
      payload += _emvField('54', amount.toStringAsFixed(2));
    }
    
    payload += _emvField('58', 'BR'); 
    payload += _emvField('59', finalName);
    payload += _emvField('60', finalCity);
    payload += _emvField('62', _emvField('05', '***')); 
    
    payload += '6304'; 
    final crc = _crc16(payload);
    return '$payload$crc';
  }

  void _generate() {
    if (!_formKey.currentState!.validate()) return;
    final payload = _buildPixPayload(
      key: _keyController.text.trim(),
      name: _nameController.text.trim(),
      city: _cityController.text.trim(),
      amount: _amountCents > 0 ? _amountCents / 100 : null,
      description: _descriptionController.text.trim(),
    );
    setState(() {
      _pixPayload = payload;
      _showQr = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Scrollable.ensureVisible(_qrKey.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut, alignment: 0.1,
      );
    });
  }

  void _copyPayload() {
    if (_pixPayload == null) return;
    Clipboard.setData(ClipboardData(text: _pixPayload!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pix Copia e Cola copiado!'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _copyQrCodeImage() async {
    if (_pixPayload == null || _copyingImage) return;
    setState(() => _copyingImage = true);

    try {
      await Future.delayed(const Duration(milliseconds: 50));

      final boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Falha ao renderizar QR Code');
      final pngBytes = byteData.buffer.asUint8List();

      final clipboard = SystemClipboard.instance;
      if (clipboard == null) {
        throw Exception('Clipboard não disponível nesta plataforma');
      }
      final item = DataWriterItem();
      item.add(Formats.png(pngBytes));
      await clipboard.write([item]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagem do QR Code copiada!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao copiar imagem: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _copyingImage = false);
    }
  }

  Future<void> _exportQrCode() async {
    if (_pixPayload == null || _exporting) return;
    setState(() => _exporting = true);
    try {
      final boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/qrcode_pix.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], subject: 'QR Code Pix', text: 'QR Code Pix gerado pelo Quórum');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _reset() {
    setState(() {
      _showQr = false;
      _pixPayload = null;
    });
  }

  String? _validateKey(String? value) {
    if (value == null || value.trim().isEmpty) return 'Informe a chave Pix';
    return null;
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Informe o nome do recebedor';
    if (value.trim().length < 2) return 'Nome muito curto';
    return null;
  }

  String? _validateCity(String? value) {
    if (value == null || value.trim().isEmpty) return 'Informe a cidade do recebedor';
    return null;
  }

  @override
  void dispose() {
    _keyController.dispose();
    _nameController.dispose();
    _cityController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    final hint = _keyTypes.firstWhere((k) => k.$1 == _selectedKeyType).$3;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.pix, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text('Gerar Pix', style: AppTextStyles.splineSans(fontSize: 26, fontWeight: FontWeight.w700, color: textPrimary)),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tipo de chave', style: AppTextStyles.label(textSecondary)),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _keyTypes.map((kt) {
                          final isSelected = _selectedKeyType == kt.$1;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedKeyType = kt.$1;
                                  _showQr = false;
                                  _pixPayload = null;
                                  _keyController.clear();
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: isSelected ? AppColors.primary : borderColor, width: isSelected ? 1.5 : 1),
                                ),
                                child: Text(kt.$2, style: AppTextStyles.dmSans(fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, color: isSelected ? AppColors.primary : textSecondary)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Chave Pix', style: AppTextStyles.label(textSecondary)),
                    const SizedBox(height: 8),
                    TextFormField(controller: _keyController, validator: _validateKey, decoration: InputDecoration(hintText: hint), style: AppTextStyles.body(textPrimary), onChanged: (_) => setState(() => _showQr = false)),
                    const SizedBox(height: 20),
                    Text('Nome do recebedor', style: AppTextStyles.label(textSecondary)),
                    const SizedBox(height: 8),
                    TextFormField(controller: _nameController, validator: _validateName, decoration: const InputDecoration(hintText: 'Ex: João Silva'), style: AppTextStyles.body(textPrimary), onChanged: (_) => setState(() => _showQr = false)),
                    const SizedBox(height: 20),
                    Text('Cidade do recebedor', style: AppTextStyles.label(textSecondary)),
                    const SizedBox(height: 8),
                    TextFormField(controller: _cityController, validator: _validateCity, decoration: const InputDecoration(hintText: 'Ex: São Paulo'), style: AppTextStyles.body(textPrimary), onChanged: (_) => setState(() => _showQr = false)),
                    const SizedBox(height: 20),
                    Text('Valor (opcional)', style: AppTextStyles.label(textSecondary)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _amountController, keyboardType: TextInputType.number, 
                      onChanged: (v) { _onAmountChanged(v); setState(() => _showQr = false); },
                      decoration: InputDecoration(
                        hintText: '0,00', helperText: 'Deixe vazio para o pagador definir o valor',
                        prefixIcon: Padding(padding: const EdgeInsets.only(left: 16, right: 8), child: Text('R\$', style: AppTextStyles.bodyBold(AppColors.primary))),
                        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                      ),
                      style: AppTextStyles.splineSans(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
                    ),
                    const SizedBox(height: 20),
                    Text('Descrição (opcional)', style: AppTextStyles.label(textSecondary)),
                    const SizedBox(height: 8),
                    TextFormField(controller: _descriptionController, decoration: const InputDecoration(hintText: 'Ex: Aluguel março'), style: AppTextStyles.body(textPrimary), onChanged: (_) => setState(() => _showQr = false)),
                  ],
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
            sliver: SliverToBoxAdapter(
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity, height: 56,
                      child: FilledButton.icon(
                        onPressed: _generate, icon: const Icon(Icons.qr_code_2, size: 20), label: const Text('Gerar QR Code Pix'),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),

          if (_showQr && _pixPayload != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('QR Code gerado', style: AppTextStyles.label(textSecondary))),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: surfaceColor, borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), shape: BoxShape.circle), child: const Icon(Icons.person_outline, color: AppColors.primary, size: 20)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(_nameController.text.trim(), style: AppTextStyles.bodyBold(textPrimary)),
                                  Text(_cityController.text.trim(), style: AppTextStyles.label(textSecondary)),
                                ]),
                              ),
                              if (_amountCents > 0) Text(CurrencyUtils.format(_amountCents / 100), style: AppTextStyles.splineSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 20),

                          RepaintBoundary(
                            key: _qrKey,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                              child: QrImageView(data: _pixPayload!, version: QrVersions.auto, size: 220, backgroundColor: Colors.white, errorCorrectionLevel: QrErrorCorrectLevel.M),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_amountCents == 0) Text('Valor em aberto — o pagador define', style: AppTextStyles.label(textSecondary)),
                          const SizedBox(height: 24),

                          // Seção de botões em coluna conforme solicitado
                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _copyQrCodeImage, // Copia a imagem do QR
                                      icon: _copyingImage 
                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                                        : const Icon(Icons.copy, size: 16),
                                      label: Text(_copyingImage ? 'Copiando...' : 'Copiar QR Code'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14), 
                                        side: const BorderSide(color: AppColors.primary), 
                                        foregroundColor: AppColors.primary, 
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: _exporting ? null : _exportQrCode, // Salva/Compartilha imagem
                                      icon: _exporting 
                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                                        : const Icon(Icons.share, size: 16),
                                      label: Text(_exporting ? 'Exportando...' : 'Salvar / Compartilhar imagem'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.primary, 
                                        padding: const EdgeInsets.symmetric(vertical: 14), 
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(onPressed: _reset, icon: const Icon(Icons.refresh, size: 16), label: const Text('Gerar novo'), style: TextButton.styleFrom(foregroundColor: textSecondary)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _copyPayload, // Clique para copiar o texto (Copia e Cola)
                      child: Container(
                        width: double.infinity, padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA), borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.code, size: 14, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Text('Pix Copia e Cola', style: AppTextStyles.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                                const Spacer(),
                                Icon(Icons.copy, size: 14, color: textSecondary),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(_pixPayload!, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF6E7681), height: 1.6), maxLines: 4, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}