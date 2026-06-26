import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../constants/colors.dart';
import '../models/recipient.dart';
import '../services/wallet_store.dart';

/// Écran d'envoi d'argent, pré-rempli via POST /qr/resolve.
class SendMoneyScreen extends StatefulWidget {
  const SendMoneyScreen({super.key, required this.recipient});

  final Recipient recipient;

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _pinController = TextEditingController();
  final _idempotencyKey = const Uuid().v4();
  String _currency = 'CDF';
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    final result = await WalletStore.instance.send(
      recipient: widget.recipient,
      amount: double.parse(_amountController.text.replaceAll(',', '.')),
      currency: _currency,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      idempotencyKey: _idempotencyKey,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.success) {
      await _showSuccessDialog();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppColors.primaryRed,
        ),
      );
    }
  }

  Future<void> _showSuccessDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.promoGreen, size: 64),
            const SizedBox(height: 12),
            const Text(
              'Transfert réussi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '${_amountController.text} $_currency envoyés à ${widget.recipient.name}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Terminé'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
        title: const Text("Envoyer de l'argent"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRecipientCard(),
              const SizedBox(height: 20),
              const _SectionLabel('Montant à envoyer'),
              const SizedBox(height: 8),
              _buildAmountField(),
              const SizedBox(height: 20),
              const _SectionLabel('Motif (optionnel)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteController,
                decoration: _inputDecoration('Ex: Remboursement'),
                maxLength: 60,
              ),
              const SizedBox(height: 8),
              const _SectionLabel('Code PIN de confirmation'),
              const SizedBox(height: 8),
              _buildPinField(),
              const SizedBox(height: 28),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecipientCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.redTint,
            child: Icon(Icons.person, color: AppColors.primaryRed, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bénéficiaire',
                  style: TextStyle(
                      fontSize: 11.5, color: AppColors.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.recipient.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.recipient.maskedPhone,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Icon(Icons.verified_rounded,
              color: AppColors.promoGreen, size: 22),
        ],
      ),
    );
  }

  Widget _buildAmountField() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _amountController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700),
            decoration: _inputDecoration('0,00'),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Saisissez un montant';
              final value = double.tryParse(v.replaceAll(',', '.'));
              if (value == null || value <= 0) return 'Montant invalide';
              return null;
            },
          ),
        ),
        const SizedBox(width: 12),
        _buildCurrencySelector(),
      ],
    );
  }

  Widget _buildCurrencySelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.redTint,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DropdownButton<String>(
        value: _currency,
        underline: const SizedBox.shrink(),
        items: const [
          DropdownMenuItem(value: 'CDF', child: Text('CDF')),
          DropdownMenuItem(value: 'USD', child: Text('USD')),
        ],
        onChanged: (v) => setState(() => _currency = v ?? 'CDF'),
        style: const TextStyle(
          color: AppColors.primaryRed,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildPinField() {
    return TextFormField(
      controller: _pinController,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: _inputDecoration('••••'),
      validator: (v) {
        if (v == null || v.length < 4) return 'PIN à 4-6 chiffres';
        return null;
      },
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryRed,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: _submitting ? null : _submit,
        child: _submitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : const Text(
                'Confirmer le transfert',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.cardBackground,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryRed),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}
