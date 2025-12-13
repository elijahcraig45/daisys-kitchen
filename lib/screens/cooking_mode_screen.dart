import 'dart:async';
import 'package:flutter/material.dart';
import 'package:recipe_keeper/models/recipe.dart';
import 'package:recipe_keeper/models/recipe_step.dart';
import 'package:recipe_keeper/models/ingredient.dart';

class CookingModeScreen extends StatefulWidget {
  final Recipe recipe;

  const CookingModeScreen({
    super.key,
    required this.recipe,
  });

  @override
  State<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends State<CookingModeScreen> {
  late PageController _pageController;
  int _currentStep = 0;
  final Map<int, Timer?> _timers = {};
  final Map<int, int> _remainingSeconds = {};
  final Map<int, bool> _timerRunning = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Initialize timer states
    for (var step in widget.recipe.steps) {
      if (step.timerSeconds != null && step.timerSeconds! > 0) {
        _remainingSeconds[step.stepNumber] = step.timerSeconds!;
        _timerRunning[step.stepNumber] = false;
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var timer in _timers.values) {
      timer?.cancel();
    }
    super.dispose();
  }

  void _startTimer(int stepNumber) {
    if (_timerRunning[stepNumber] == true) return;

    setState(() {
      _timerRunning[stepNumber] = true;
    });

    _timers[stepNumber] = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds[stepNumber]! > 0) {
          _remainingSeconds[stepNumber] = _remainingSeconds[stepNumber]! - 1;
        } else {
          timer.cancel();
          _timerRunning[stepNumber] = false;
          _showTimerCompleteDialog(stepNumber);
        }
      });
    });
  }

  void _pauseTimer(int stepNumber) {
    _timers[stepNumber]?.cancel();
    setState(() {
      _timerRunning[stepNumber] = false;
    });
  }

  void _resetTimer(int stepNumber) {
    _timers[stepNumber]?.cancel();
    final step =
        widget.recipe.steps.firstWhere((s) => s.stepNumber == stepNumber);
    setState(() {
      _remainingSeconds[stepNumber] = step.timerSeconds!;
      _timerRunning[stepNumber] = false;
    });
  }

  void _showTimerCompleteDialog(int stepNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Timer Complete!'),
        content: Text('Step $stepNumber timer has finished.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cooking Mode'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Step ${_currentStep + 1}/${widget.recipe.steps.length}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: ((_currentStep + 1) / widget.recipe.steps.length),
            minHeight: 6,
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentStep = index;
                });
              },
              itemCount: widget.recipe.steps.length,
              itemBuilder: (context, index) {
                final step = widget.recipe.steps[index];
                return _buildStepPage(step);
              },
            ),
          ),
          _buildNavigationControls(),
        ],
      ),
    );
  }

  Widget _buildStepPage(RecipeStep step) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: CircleAvatar(
              radius: 32,
              child: Text(
                '${step.stepNumber}',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            step.title.isNotEmpty ? step.title : 'Step ${step.stepNumber}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (step.description != null &&
              step.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              step.description!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
          const SizedBox(height: 24),
          if (step.ingredientsForStep != null &&
              step.ingredientsForStep!.isNotEmpty) ...[
            Text(
              'Ingredients for this step:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ...step.ingredientsForStep!.map((ingredient) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 8),
                    const SizedBox(width: 12),
                    Text(
                      _formatIngredientDisplay(ingredient),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),
          ],
          if (step.timerSeconds != null && step.timerSeconds! > 0)
            _buildTimerSection(step),
        ],
      ),
    );
  }

  String _formatIngredientDisplay(Ingredient ingredient) {
    final primary = _formatAmountUnit(ingredient.amount, ingredient.unit);
    final secondary = ingredient.secondaryAmount != null &&
            ingredient.secondaryAmount!.trim().isNotEmpty
        ? _formatAmountUnit(
            ingredient.secondaryAmount!, ingredient.secondaryUnit)
        : '';
    final buffer = StringBuffer();
    if (primary.isNotEmpty) {
      buffer.write(primary);
    }
    if (secondary.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write('($secondary)');
    }
    if (buffer.isNotEmpty) buffer.write(' ');
    buffer.write(ingredient.name);
    return buffer.toString().trim();
  }

  String _formatAmountUnit(String amount, String? unit) {
    final trimmedAmount = amount.trim();
    final trimmedUnit = unit?.trim() ?? '';
    if (trimmedAmount.isEmpty && trimmedUnit.isEmpty) {
      return '';
    }
    if (trimmedUnit.isEmpty) return trimmedAmount;
    if (trimmedAmount.isEmpty) return trimmedUnit;
    return '$trimmedAmount $trimmedUnit';
  }

  Widget _buildTimerSection(RecipeStep step) {
    final remaining = _remainingSeconds[step.stepNumber]!;
    final isRunning = _timerRunning[step.stepNumber] ?? false;
    final minutes = remaining ~/ 60;
    final seconds = remaining % 60;

    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer, size: 32),
                const SizedBox(width: 12),
                Text(
                  step.timerLabel ?? 'Timer',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: isRunning
                      ? () => _pauseTimer(step.stepNumber)
                      : () => _startTimer(step.stepNumber),
                  icon: Icon(isRunning ? Icons.pause : Icons.play_arrow),
                  label: Text(isRunning ? 'Pause' : 'Start'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _resetTimer(step.stepNumber),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Previous'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          if (_currentStep > 0 && _currentStep < widget.recipe.steps.length - 1)
            const SizedBox(width: 16),
          if (_currentStep < widget.recipe.steps.length - 1)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next'),
                iconAlignment: IconAlignment.end,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            )
          else
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Recipe Complete!'),
                      content: const Text('Enjoy your meal!'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).pop();
                          },
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle),
                label: const Text('Complete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
