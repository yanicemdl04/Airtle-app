import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../constants/colors.dart';
import '../../constants/spacing.dart';
import '../../models/recipient.dart';
import '../../services/toast_service.dart';
import '../../services/wallet_store.dart';
import '../../widgets/animated_button.dart';
import '../../widgets/airtel_card.dart';
import 'send_recipient_screen.dart';

/// Flux multi-étapes : destinataire → montant → confirmation → PIN → succès.
class SendMoneyFlow extends StatefulWidget {
  const SendMoneyFlow({super.key, required this.recipient});

  final Recipient recipient;

  @override
  State<SendMoneyFlow> createState() => _SendMoneyFlowState();
}

class _SendMoneyFlowState extends State<SendMoneyFlow> {
  late final SendFlowData _data = SendFlowData(recipient: widget.recipient);
  int _step = 0;
  bool _submitting = false;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _pinController = TextEditingController();
  final _idempotencyKey = const Uuid().v4();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _nextStep() => setState(() => _step++);

  void _prevStep() {
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      setState(() => _step--);
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final result = await WalletStore.instance.send(
      recipient: _data.recipient,
      amount: _data.amount!,
      currency: _data.currency,
      note: _data.note,
      idempotencyKey: _idempotencyKey,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.success) {
      _nextStep();
    } else {
      ToastService.error(context, 'Échec', message: result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_step]),
        leading: _step < 4
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _prevStep,
              )
            : null,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _buildStep(),
      ),
    );
  }

  static const _titles = [
    'Destinataire',
    'Montant',
    'Confirmation',
    'Code PIN',
    'Succès',
  ];

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _RecipientStep(
          key: const ValueKey(0),
          recipient: _data.recipient,
          onContinue: _nextStep,
        );
      case 1:
        return _AmountStep(
          key: const ValueKey(1),
          amountController: _amountController,
          noteController: _noteController,
          currency: _data.currency,
          onCurrencyChanged: (v) => setState(() => _data.currency = v),
          onContinue: () {
            final amount =
                double.tryParse(_amountController.text.replaceAll(',', '.'));
            if (amount == null || amount <= 0) {
              ToastService.error(context, 'Montant invalide');
              return;
            }
            _data.amount = amount;
            _data.note = _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim();
            _nextStep();
          },
        );
      case 2:
        return _ConfirmStep(
          key: const ValueKey(2),
          data: _data,
          onConfirm: _nextStep,
        );
      case 3:
        return _PinStep(
          key: const ValueKey(3),
          pinController: _pinController,
          loading: _submitting,
          onSubmit: () {
            if (_pinController.text.length < 4) {
              ToastService.error(context, 'PIN invalide');
              return;
            }
            _submit();
          },
        );
      default:
        return _SuccessStep(
          key: const ValueKey(4),
          data: _data,
          onDone: () => Navigator.of(context).popUntil((r) => r.isFirst),
        );
    }
  }
}

class _RecipientStep extends StatelessWidget {
  const _RecipientStep({
    super.key,
    required this.recipient,
    required this.onContinue,
  });

  final Recipient recipient;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        children: [
          AirtelCard(
            margin: EdgeInsets.zero,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.redTint,
                  child: Text(
                    recipient.name.isNotEmpty
                        ? recipient.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.primaryRed,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Destinataire trouvé',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        recipient.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        recipient.maskedPhone,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.verified_rounded, color: AppColors.success),
              ],
            ),
          ),
          const Spacer(),
          AnimatedButton(label: 'Continuer', onPressed: onContinue),
        ],
      ),
    );
  }
}

class _AmountStep extends StatelessWidget {
  const _AmountStep({
    super.key,
    required this.amountController,
    required this.noteController,
    required this.currency,
    required this.onCurrencyChanged,
    required this.onContinue,
  });

  final TextEditingController amountController;
  final TextEditingController noteController;
  final String currency;
  final ValueChanged<String> onCurrencyChanged;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Combien souhaitez-vous envoyer ?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: const InputDecoration(hintText: '0,00'),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: AppColors.redTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<String>(
                  value: currency,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'CDF', child: Text('CDF')),
                    DropdownMenuItem(value: 'USD', child: Text('USD')),
                  ],
                  onChanged: (v) => onCurrencyChanged(v ?? 'CDF'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: noteController,
            decoration: const InputDecoration(
              labelText: 'Motif (optionnel)',
              hintText: 'Ex: Remboursement',
            ),
            maxLength: 60,
          ),
          const SizedBox(height: AppSpacing.md),
          AnimatedButton(label: 'Continuer', onPressed: onContinue),
        ],
      ),
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({
    super.key,
    required this.data,
    required this.onConfirm,
  });

  final SendFlowData data;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AirtelCard(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                _ConfirmRow('Destinataire', data.recipient.name),
                const Divider(),
                _ConfirmRow('Téléphone', data.recipient.maskedPhone),
                const Divider(),
                _ConfirmRow(
                  'Montant',
                  '${data.amount!.toStringAsFixed(2)} ${data.currency}',
                  highlight: true,
                ),
                if (data.note != null) ...[
                  const Divider(),
                  _ConfirmRow('Motif', data.note!),
                ],
              ],
            ),
          ),
          const Spacer(),
          AnimatedButton(label: 'Confirmer le transfert', onPressed: onConfirm),
        ],
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow(this.label, this.value, {this.highlight = false});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: highlight ? 18 : 14,
              color: highlight ? AppColors.primaryRed : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PinStep extends StatelessWidget {
  const _PinStep({
    super.key,
    required this.pinController,
    required this.loading,
    required this.onSubmit,
  });

  final TextEditingController pinController;
  final bool loading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Entrez votre code PIN',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Votre PIN sécurise chaque transaction Airtel Money.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              letterSpacing: 12,
              fontWeight: FontWeight.w800,
            ),
            decoration: const InputDecoration(
              hintText: '••••',
              counterText: '',
            ),
          ),
          const Spacer(),
          AnimatedButton(
            label: 'Valider',
            loading: loading,
            onPressed: onSubmit,
          ),
        ],
      ),
    );
  }
}

class _SuccessStep extends StatelessWidget {
  const _SuccessStep({
    super.key,
    required this.data,
    required this.onDone,
  });

  final SendFlowData data;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.success,
              size: 48,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Transfert réussi !',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '${data.amount!.toStringAsFixed(2)} ${data.currency} envoyés à ${data.recipient.name}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          AnimatedButton(label: 'Terminé', onPressed: onDone),
        ],
      ),
    );
  }
}
