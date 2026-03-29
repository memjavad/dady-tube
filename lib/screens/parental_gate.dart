import 'package:flutter/material.dart';
import 'dart:math';

import '../core/tactile_widgets.dart';
import '../core/theme.dart';
import '../core/app_localizations.dart';

class ParentalGate extends StatefulWidget {
  final Widget destination;

  const ParentalGate({super.key, required this.destination});

  @override
  State<ParentalGate> createState() => _ParentalGateState();
}

class _ParentalGateState extends State<ParentalGate> {
  final TextEditingController _pinController = TextEditingController();
  String _error = '';
  late int _num1;
  late int _num2;
  late int _answer;

  @override
  void initState() {
    super.initState();
    _generateMathProblem();
  }

  void _generateMathProblem() {
    final random = Random();
    // Generate multiplication problem between 5x5 and 12x12
    _num1 = random.nextInt(8) + 5;
    _num2 = random.nextInt(8) + 5;
    _answer = _num1 * _num2;
    _pinController.clear();
  }

  void _verifyPin() {
    // Validate answer instead of a hardcoded PIN
    final input = int.tryParse(_pinController.text);
    if (input == _answer) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => widget.destination),
      );
    } else {
      setState(() {
        _error = 'Oops! Ask a grown-up for help.';
        _generateMathProblem();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(loc.translate('parental_gate_title')),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 0),
          child: TactileCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_person_rounded, size: 64, color: DadyTubeTheme.primary),
                const SizedBox(height: 24),
                // Removed redundant title here as it's now in AppBar
                Text(
                  loc.translate('parental_gate_msg'),
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  '$_num1 × $_num2 = ?',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: DadyTubeTheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                _buildPinField(context),
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(loc.translate('try_again'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ],
                const SizedBox(height: 32),
                _buildNumPad(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinField(BuildContext context) {
    final maxLength = _answer.toString().length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(maxLength, (index) {
        bool filled = _pinController.text.length > index;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: filled ? DadyTubeTheme.primary : Colors.grey.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }

  Widget _buildNumPad(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        if (index == 9) return const SizedBox.shrink(); // Empty slot
        if (index == 11) {
          return TactileButton(
            onTap: () {
              if (_pinController.text.isNotEmpty) {
                setState(() {
                  _pinController.text = _pinController.text.substring(0, _pinController.text.length - 1);
                });
              }
            },
            child: TactileCard(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: const Center(child: Icon(Icons.backspace_rounded)),
            ),
          );
        }
        
        final number = index == 10 ? '0' : (index + 1).toString();
        return TactileButton(
          onTap: () {
            final maxLength = _answer.toString().length;
            if (_pinController.text.length < maxLength) {
              setState(() {
                _pinController.text += number;
              });
              if (_pinController.text.length == maxLength) {
                _verifyPin();
              }
            }
          },
          child: TactileCard(
             color: Theme.of(context).colorScheme.surfaceContainerLow,
             child: Center(
               child: Text(
                 number,
                 style: Theme.of(context).textTheme.headlineSmall,
               ),
             ),
          ),
        );
      },
    );
  }
}
