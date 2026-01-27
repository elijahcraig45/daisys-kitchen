import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_keeper/models/recipe.dart';
import 'package:recipe_keeper/models/ingredient.dart';
import 'package:recipe_keeper/models/recipe_step.dart';
import 'package:recipe_keeper/providers/firebase_providers.dart';
import 'package:recipe_keeper/providers/gemini_providers.dart';
import 'package:recipe_keeper/services/recipe_autofill_service.dart';

class RecipeEditorScreen extends ConsumerStatefulWidget {
  final Recipe? recipe;

  const RecipeEditorScreen({
    super.key,
    this.recipe,
  });

  @override
  ConsumerState<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends ConsumerState<RecipeEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _servingsController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _cookTimeController = TextEditingController();
  final _categoryController = TextEditingController();
  final _cuisineController = TextEditingController();
  final _notesController = TextEditingController();
  final _tagInputController = TextEditingController();
  final _ingredientAmountController = TextEditingController();
  final _ingredientUnitController = TextEditingController();
  final _ingredientNameController = TextEditingController();
  final _stepTitleController = TextEditingController();
  final _stepDescriptionController = TextEditingController();
  final _stepTimerController = TextEditingController();
  final _stepTimerLabelController = TextEditingController();
  final Map<String, _StepIngredientSelection> _stepIngredientSelections = {};
  final RecipeAutofillService _autofillService = RecipeAutofillService();
  bool _isAutofilling = false;
  MeasurementSystem _autofillUnitSystem = MeasurementSystem.customary;
  late final List<TextEditingController> _previewControllers;

  DifficultyLevel _difficulty = DifficultyLevel.medium;
  final List<Ingredient> _ingredients = [];
  final List<RecipeStep> _steps = [];
  final List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    _previewControllers = [
      _titleController,
      _descriptionController,
      _imageUrlController,
      _servingsController,
      _prepTimeController,
      _cookTimeController,
      _categoryController,
      _cuisineController,
      _notesController,
    ];
    for (final controller in _previewControllers) {
      controller.addListener(_handlePreviewChange);
    }
    if (widget.recipe != null) {
      _loadRecipe(widget.recipe!);
      _handlePreviewChange();
    } else {
      _handlePreviewChange();
      _syncStepIngredientSelections();
    }
  }

  void _loadRecipe(Recipe recipe) {
    _titleController.text = recipe.title;
    _descriptionController.text = recipe.description;
    _imageUrlController.text = recipe.imageUrl ?? '';
    _servingsController.text = recipe.servings.toString();
    _prepTimeController.text = recipe.prepTimeMinutes?.toString() ?? '';
    _cookTimeController.text = recipe.cookTimeMinutes?.toString() ?? '';
    _categoryController.text = recipe.category ?? '';
    _cuisineController.text = recipe.cuisine ?? '';
    _notesController.text = recipe.notes ?? '';
    _difficulty = recipe.difficulty;
    _ingredients.addAll(recipe.ingredients);
    _steps.addAll(recipe.steps);
    if (recipe.tags != null) {
      _tags.addAll(recipe.tags!);
    }
    _syncStepIngredientSelections();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _servingsController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _categoryController.dispose();
    _cuisineController.dispose();
    _notesController.dispose();
    _tagInputController.dispose();
    _ingredientAmountController.dispose();
    _ingredientUnitController.dispose();
    _ingredientNameController.dispose();
    _stepTitleController.dispose();
    _stepDescriptionController.dispose();
    _stepTimerController.dispose();
    _stepTimerLabelController.dispose();
    for (final controller in _previewControllers) {
      controller.removeListener(_handlePreviewChange);
    }
    _disposeStepIngredientSelections();
    _autofillService.dispose();
    super.dispose();
  }

  void _handlePreviewChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe == null ? 'New Recipe' : 'Edit Recipe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'AI Extract from text',
            onPressed: _isAutofilling ? null : _showAIExtractDialog,
          ),
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            tooltip: 'Autofill from link',
            onPressed: _isAutofilling ? null : _showAutofillDialog,
          ),
          if (widget.recipe == null)
            IconButton(
              icon: const Icon(Icons.verified),
              tooltip: 'Verify with AI',
              onPressed: _isAutofilling ? null : _verifyRecipeWithAI,
            ),
          if (_isAutofilling)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save recipe',
            onPressed: _isAutofilling ? null : _saveRecipe,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1100;
          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPreviewCard(isWide),
                  const SizedBox(height: 24),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _buildBasicsCard(),
                              const SizedBox(height: 24),
                              _buildTagsCard(),
                              const SizedBox(height: 24),
                              _buildNotesCard(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            children: [
                              _buildIngredientsSection(),
                              const SizedBox(height: 24),
                              _buildStepsSection(),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildBasicsCard(),
                        const SizedBox(height: 24),
                        _buildTagsCard(),
                        const SizedBox(height: 24),
                        _buildIngredientsSection(),
                        const SizedBox(height: 24),
                        _buildStepsSection(),
                        const SizedBox(height: 24),
                        _buildNotesCard(),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPreviewCard(bool isWide) {
    final theme = Theme.of(context);
    final imageUrl = _imageUrlController.text.trim();
    final hasImage = imageUrl.isNotEmpty;
    final title = _titleController.text.trim().isEmpty
        ? 'Add a title to see a live preview'
        : _titleController.text.trim();
    final description = _descriptionController.text.trim().isEmpty
        ? 'Your description will appear here. Share why this recipe is special!'
        : _descriptionController.text.trim();
    final servings = int.tryParse(_servingsController.text);
    final prep = int.tryParse(_prepTimeController.text);
    final cook = int.tryParse(_cookTimeController.text);
    final category = _categoryController.text.trim();
    final cuisine = _cuisineController.text.trim();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: isWide ? 16 / 5 : 16 / 9,
            child: hasImage
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _buildPreviewPlaceholder(theme),
                  )
                : _buildPreviewPlaceholder(theme),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: theme.textTheme.bodySmall?.color),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (servings != null && servings > 0)
                      _buildInfoChip(Icons.people, '$servings servings'),
                    if (prep != null && prep > 0)
                      _buildInfoChip(Icons.access_time, '$prep min prep'),
                    if (cook != null && cook > 0)
                      _buildInfoChip(Icons.restaurant, '$cook min cook'),
                    _buildInfoChip(
                      Icons.auto_fix_high,
                      'Difficulty: ${_difficulty.name[0].toUpperCase()}${_difficulty.name.substring(1)}',
                    ),
                    if (category.isNotEmpty)
                      _buildInfoChip(Icons.category, category),
                    if (cuisine.isNotEmpty)
                      _buildInfoChip(Icons.public, cuisine),
                  ],
                ),
                if (_tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _tags
                        .map((tag) => Chip(
                              label: Text(tag),
                              backgroundColor:
                                  theme.colorScheme.secondaryContainer,
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Live preview updates as you type.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewPlaceholder(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surfaceContainerHighest,
            theme.colorScheme.surfaceContainerHigh,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        Icons.image,
        size: 64,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    final theme = Theme.of(context);
    return Chip(
      avatar: Icon(icon, size: 16, color: theme.colorScheme.primary),
      backgroundColor:
          theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.4),
      label: Text(label),
    );
  }

  Widget _buildBasicsCard() {
    return _SectionCard(
      title: 'Recipe basics',
      subtitle: 'Give your recipe a title, summary, and quick details.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Recipe Title *',
              hintText: 'e.g., Sunday Sauce with Fresh Basil',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a title';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description *',
              hintText: 'What makes this dish special?',
            ),
            maxLines: 3,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a description';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _imageUrlController,
            decoration: const InputDecoration(
              labelText: 'Image URL',
              hintText: 'https://…',
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 620;
              final fieldWidth =
                  isCompact ? double.infinity : (constraints.maxWidth - 16) / 2;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: fieldWidth,
                    child: TextFormField(
                      controller: _servingsController,
                      decoration: const InputDecoration(
                        labelText: 'Servings *',
                        hintText: 'e.g., 4',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: TextFormField(
                      controller: _prepTimeController,
                      decoration: const InputDecoration(
                        labelText: 'Prep Time (minutes)',
                        hintText: 'Chopping, marinating…',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 620;
              final fieldWidth =
                  isCompact ? double.infinity : (constraints.maxWidth - 16) / 2;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: fieldWidth,
                    child: TextFormField(
                      controller: _cookTimeController,
                      decoration: const InputDecoration(
                        labelText: 'Cook Time (minutes)',
                        hintText: 'Hands-off simmering, baking…',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<DifficultyLevel>(
                      key: ValueKey('difficulty-${_difficulty.name}'),
                      value: _difficulty,
                      decoration: const InputDecoration(
                        labelText: 'Difficulty',
                      ),
                      items: DifficultyLevel.values.map((level) {
                        return DropdownMenuItem(
                          value: level,
                          child: Text(level.name.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _difficulty = value;
                          });
                        }
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 620;
              final fieldWidth =
                  isCompact ? double.infinity : (constraints.maxWidth - 16) / 2;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: fieldWidth,
                    child: TextFormField(
                      controller: _categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        hintText: 'Entree, Dessert, Snack…',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: TextFormField(
                      controller: _cuisineController,
                      decoration: const InputDecoration(
                        labelText: 'Cuisine',
                        hintText: 'Italian, Thai, Fusion…',
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTagsCard() {
    return _SectionCard(
      title: 'Tags',
      subtitle: 'Add quick labels like “Weeknight”, “Vegetarian”, or “Spicy”.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 360;
          final inputWidth = isCompact ? double.infinity : 220.0;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._tags.map(
                (tag) => Chip(
                  label: Text(tag),
                  onDeleted: () => setState(() => _tags.remove(tag)),
                  deleteIcon: const Icon(Icons.close, size: 18),
                ),
              ),
              SizedBox(
                width: inputWidth,
                child: TextField(
                  controller: _tagInputController,
                  decoration: InputDecoration(
                    labelText: 'Add tag',
                    prefixIcon: const Icon(Icons.local_offer),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: 'Add tag',
                      onPressed: _handleAddTag,
                    ),
                  ),
                  textCapitalization: TextCapitalization.words,
                  onSubmitted: (_) => _handleAddTag(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleAddTag() {
    final value = _tagInputController.text.trim();
    if (value.isEmpty) return;
    if (_tags.contains(value)) {
      _showSimpleMessage('Tag "$value" already added');
      return;
    }
    setState(() {
      _tags.add(value);
    });
    _tagInputController.clear();
  }

  void _syncStepIngredientSelections() {
    final ingredientNames = _ingredients.map((i) => i.name).toSet();
    for (final ingredient in _ingredients) {
      _stepIngredientSelections.putIfAbsent(
        ingredient.name,
        () => _StepIngredientSelection(
          baseAmount: ingredient.amount,
          baseUnit: ingredient.unit,
        ),
      );
      _stepIngredientSelections[ingredient.name]!
          .updateBase(ingredient.amount, ingredient.unit);
    }

    final toRemove = _stepIngredientSelections.keys
        .where((name) => !ingredientNames.contains(name))
        .toList();
    for (final name in toRemove) {
      _stepIngredientSelections[name]?.dispose();
      _stepIngredientSelections.remove(name);
      for (final step in _steps) {
        step.ingredientsForStep
            ?.removeWhere((ingredient) => ingredient.name == name);
      }
    }
  }

  void _disposeStepIngredientSelections() {
    for (final selection in _stepIngredientSelections.values) {
      selection.dispose();
    }
    _stepIngredientSelections.clear();
  }

  Widget _buildIngredientsSection() {
    return _SectionCard(
      title: 'Ingredients',
      subtitle:
          'List every ingredient with an amount and unit. Reorder with the arrows.',
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 600;
              final amountWidth = isCompact ? double.infinity : 140.0;
              final unitWidth = isCompact ? double.infinity : 140.0;
              final nameWidth = isCompact
                  ? double.infinity
                  : constraints.maxWidth - amountWidth - unitWidth - 24;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: amountWidth,
                    child: TextField(
                      controller: _ingredientAmountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        hintText: '1, 1/2, pinch…',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: unitWidth,
                    child: TextField(
                      controller: _ingredientUnitController,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        hintText: 'cups, tsp…',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: nameWidth,
                    child: TextField(
                      controller: _ingredientNameController,
                      decoration: const InputDecoration(
                        labelText: 'Ingredient name',
                        hintText: 'Roma tomatoes, butter…',
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _addIngredientFromInputs(),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _addIngredientFromInputs,
              icon: const Icon(Icons.add),
              label: const Text('Add Ingredient'),
            ),
          ),
          const SizedBox(height: 12),
          if (_ingredients.isEmpty)
            _buildEmptyState(
              icon: Icons.list_alt,
              message: 'No ingredients yet. Start adding items above.',
            )
          else
            Column(
              children: _ingredients.asMap().entries.map((entry) {
                final index = entry.key;
                final ingredient = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text('${index + 1}'),
                    ),
                    title: Text(
                      ingredient.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(formatIngredientSummary(ingredient)),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_upward),
                          tooltip: 'Move up',
                          onPressed: index == 0
                              ? null
                              : () => _reorderIngredient(index, index - 1),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_downward),
                          tooltip: 'Move down',
                          onPressed: index == _ingredients.length - 1
                              ? null
                              : () => _reorderIngredient(index, index + 1),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Edit',
                          onPressed: () => _editIngredient(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Delete',
                          onPressed: () {
                            setState(() {
                              _ingredients.removeAt(index);
                              _syncStepIngredientSelections();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildStepsSection() {
    return _SectionCard(
      title: 'Steps',
      subtitle:
          'Give each step a clear title, optional details, timer, and linked ingredients.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _stepTitleController,
            decoration: const InputDecoration(
              labelText: 'Step title *',
              hintText: 'e.g., Sear the chicken',
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _stepDescriptionController,
            decoration: const InputDecoration(
              labelText: 'Step description',
              hintText: 'Describe what needs to happen in this step (optional)',
            ),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 620;
              final fieldWidth =
                  isCompact ? double.infinity : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: fieldWidth,
                    child: TextField(
                      controller: _stepTimerController,
                      decoration: const InputDecoration(
                        labelText: 'Timer (minutes)',
                        helperText: 'Optional',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: TextField(
                      controller: _stepTimerLabelController,
                      decoration: const InputDecoration(
                        labelText: 'Timer label',
                        helperText: 'e.g., Simmer sauce',
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          _buildStepIngredientsSelector(),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _addStepFromInputs,
              icon: const Icon(Icons.add_task),
              label: const Text('Add Step'),
            ),
          ),
          const SizedBox(height: 12),
          if (_steps.isEmpty)
            _buildEmptyState(
              icon: Icons.numbers,
              message: 'No steps yet. Walk cooks through the process above.',
            )
          else
            Column(
              children: _steps.asMap().entries.map((entry) {
                final index = entry.key;
                final step = entry.value;
                final timerMinutes =
                    step.timerSeconds != null ? step.timerSeconds! ~/ 60 : null;
                final displayTitle = step.title.isNotEmpty
                    ? step.title
                    : 'Step ${step.stepNumber}';
                final hasDescription = step.description != null &&
                    step.description!.trim().isNotEmpty;
                final stepIngredients = step.ingredientsForStep ?? [];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    isThreeLine: true,
                    leading: CircleAvatar(
                      child: Text('${step.stepNumber}'),
                    ),
                    title: Text(displayTitle),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasDescription)
                          Text(
                            step.description!,
                            style: const TextStyle(height: 1.4),
                          ),
                        if (timerMinutes != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '$timerMinutes min timer${step.timerLabel != null ? ' · ${step.timerLabel}' : ''}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                        ],
                        if (stepIngredients.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: stepIngredients
                                .map(
                                  (ingredient) => Chip(
                                    label: Text(
                                      '${formatIngredientSummary(ingredient)} ${ingredient.name}'
                                          .trim(),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_upward),
                          tooltip: 'Move up',
                          onPressed: index == 0
                              ? null
                              : () => _reorderStep(index, index - 1),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_downward),
                          tooltip: 'Move down',
                          onPressed: index == _steps.length - 1
                              ? null
                              : () => _reorderStep(index, index + 1),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Edit',
                          onPressed: () => _editStep(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Delete',
                          onPressed: () {
                            setState(() {
                              _steps.removeAt(index);
                              _renumberSteps();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildStepIngredientsSelector() {
    if (_ingredients.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          'Add ingredients to link them to specific steps.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Ingredients for this step (optional)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        ..._ingredients.map((ingredient) {
          final selection = _stepIngredientSelections.putIfAbsent(
            ingredient.name,
            () => _StepIngredientSelection(
              baseAmount: ingredient.amount,
              baseUnit: ingredient.unit,
            ),
          );
          final isLast = ingredient == _ingredients.last;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: selection.selected,
                title: Text(ingredient.name),
                subtitle: Text(formatIngredientSummary(ingredient)),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (value) {
                  setState(() {
                    selection.selected = value ?? false;
                    if (selection.selected && selection.useFullAmount) {
                      selection.updateBase(ingredient.amount, ingredient.unit);
                    }
                  });
                },
              ),
              if (selection.selected)
                Padding(
                  padding: const EdgeInsets.only(left: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Use full amount (${formatIngredientSummary(ingredient)})',
                        ),
                        value: selection.useFullAmount,
                        onChanged: (value) {
                          setState(() {
                            selection.useFullAmount = value;
                            if (value) {
                              selection.updateBase(
                                  ingredient.amount, ingredient.unit);
                            }
                          });
                        },
                      ),
                      if (!selection.useFullAmount)
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: 120,
                              child: TextField(
                                controller: selection.amountController,
                                decoration: const InputDecoration(
                                  labelText: 'Amount',
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 120,
                              child: TextField(
                                controller: selection.unitController,
                                decoration: const InputDecoration(
                                  labelText: 'Unit',
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              if (!isLast) const Divider(),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildNotesCard() {
    return _SectionCard(
      title: 'Chef notes',
      subtitle:
          'Share plating tips, storage instructions, or personal stories.',
      child: TextFormField(
        controller: _notesController,
        decoration: const InputDecoration(
          labelText: 'Notes',
          hintText: 'Optional serving suggestions, make-ahead notes…',
        ),
        maxLines: 4,
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAutofillDialog() async {
    final controller = TextEditingController();
    String? errorText;
    var dialogSystem = _autofillUnitSystem;
    final url = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Autofill from link'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Print recipe link',
                      hintText: 'https://example.com/my-recipe/print/123',
                      errorText: errorText,
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    autofocus: true,
                    onChanged: (_) {
                      if (errorText != null) {
                        setDialogState(() => errorText = null);
                      }
                    },
                    onSubmitted: (_) {
                      final value = controller.text.trim();
                      if (value.isEmpty) {
                        setDialogState(() => errorText = 'Please paste a link');
                      } else {
                        setState(() {
                          _autofillUnitSystem = dialogSystem;
                        });
                        Navigator.of(context).pop(value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tip: most sites have a “Print” button that opens a clean page. '
                    'Paste that link here for the best results.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Default unit system',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  SegmentedButton<MeasurementSystem>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: MeasurementSystem.customary,
                        label: Text('Customary'),
                        icon: Icon(Icons.local_dining),
                      ),
                      ButtonSegment(
                        value: MeasurementSystem.metric,
                        label: Text('Metric'),
                        icon: Icon(Icons.scale),
                      ),
                    ],
                    selected: <MeasurementSystem>{dialogSystem},
                    onSelectionChanged: (selection) {
                      if (selection.isEmpty) return;
                      setDialogState(() => dialogSystem = selection.first);
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Customary = cups, teaspoons, ounces. Metric = grams, milliliters.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    final value = controller.text.trim();
                    if (value.isEmpty) {
                      setDialogState(() => errorText = 'Please paste a link');
                      return;
                    }
                    setState(() {
                      _autofillUnitSystem = dialogSystem;
                    });
                    Navigator.of(context).pop(value);
                  },
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Autofill'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    if (url == null || url.trim().isEmpty) {
      return;
    }
    await _performAutofill(url.trim());
  }

  Future<void> _performAutofill(String url) async {
    setState(() {
      _isAutofilling = true;
    });
    try {
      final result = await _autofillService.fetchRecipe(
        url,
        preferredSystem: _autofillUnitSystem,
      );
      if (!mounted) return;
      setState(() {
        _autofillUnitSystem = result.preferredSystem;
        _applyAutofillResult(result);
      });
      _showSimpleMessage(
          'Recipe details imported! Review and save when ready.');
    } on RecipeAutofillException catch (error) {
      _showSimpleMessage(error.message);
    } catch (_) {
      _showSimpleMessage(
        'Autofill failed. Please make sure the link points to a public print recipe page.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAutofilling = false;
        });
      }
    }
  }

  /// AI Extract dialog - paste recipe text or URL
  Future<void> _showAIExtractDialog() async {
    final isGeminiEnabled = ref.read(isGeminiEnabledProvider);
    
    if (!isGeminiEnabled) {
      _showSimpleMessage(
        '🏴‍☠️ AI features require a Gemini API key. Configure it in gemini_config.dart',
      );
      return;
    }

    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.amber),
              SizedBox(width: 8),
              Text('AI Recipe Extract'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🏴‍☠️ Paste a recipe URL or recipe text below. '
                'The AI will extract and clean it up, adding both customary and metric units!',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Recipe URL or Text',
                  hintText: 'https://example.com/recipe or paste recipe text...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 8,
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Extract'),
            ),
          ],
        );
      },
    );

    if (result == null || result.isEmpty || !mounted) return;

    setState(() => _isAutofilling = true);

    try {
      Recipe? recipe;
      
      // Check if it's a URL
      final uri = Uri.tryParse(result);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        recipe = await ref.read(extractRecipeFromUrlProvider(result).future);
      } else {
        recipe = await ref.read(extractRecipeFromTextProvider(result).future);
      }

      if (recipe == null) {
        _showSimpleMessage('Could not extract recipe. Try a different format.');
        return;
      }

      setState(() {
        _applyRecipe(recipe!);
      });
      _showSimpleMessage('🏴‍☠️ Recipe extracted! Review and save when ready.');
    } catch (e) {
      _showSimpleMessage('AI extraction failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isAutofilling = false);
      }
    }
  }

  /// Verify current recipe with AI
  Future<void> _verifyRecipeWithAI() async {
    final isGeminiEnabled = ref.read(isGeminiEnabledProvider);
    
    if (!isGeminiEnabled) {
      _showSimpleMessage(
        '🏴‍☠️ AI features require a Gemini API key. Configure it in gemini_config.dart',
      );
      return;
    }

    if (_ingredients.isEmpty || _steps.isEmpty) {
      _showSimpleMessage('Add ingredients and steps before verifying');
      return;
    }

    setState(() => _isAutofilling = true);

    try {
      final currentRecipe = Recipe(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        servings: int.tryParse(_servingsController.text) ?? 4,
        prepTimeMinutes: int.tryParse(_prepTimeController.text) ?? 0,
        cookTimeMinutes: int.tryParse(_cookTimeController.text) ?? 0,
        category: _categoryController.text.trim(),
        notes: _notesController.text.trim(),
        tags: _tags,
      );
      currentRecipe.ingredients.addAll(_ingredients);
      currentRecipe.steps.addAll(_steps);

      final verifiedRecipe = await ref.read(verifyRecipeProvider(currentRecipe).future);

      if (verifiedRecipe == null) {
        _showSimpleMessage('Verification failed. Recipe unchanged.');
        return;
      }

      setState(() {
        _applyRecipe(verifiedRecipe);
      });
      _showSimpleMessage('🏴‍☠️ Recipe verified and enhanced! Check the improvements.');
    } catch (e) {
      _showSimpleMessage('AI verification failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isAutofilling = false);
      }
    }
  }

  void _applyRecipe(Recipe recipe) {
    _titleController.text = recipe.title;
    _descriptionController.text = recipe.description;
    _imageUrlController.text = recipe.imageUrl ?? '';
    _servingsController.text = recipe.servings.toString();
    _prepTimeController.text = (recipe.prepTimeMinutes ?? 0).toString();
    _cookTimeController.text = (recipe.cookTimeMinutes ?? 0).toString();
    _categoryController.text = recipe.category ?? '';
    _notesController.text = recipe.notes ?? '';
    
    _ingredients.clear();
    _ingredients.addAll(recipe.ingredients);
    
    _steps.clear();
    _steps.addAll(recipe.steps);
    
    _tags.clear();
    if (recipe.tags != null) {
      _tags.addAll(recipe.tags!);
    }
    
    _syncStepIngredientSelections();
  }

  void _applyAutofillResult(RecipeAutofillResult result) {
    if (result.title != null && result.title!.trim().isNotEmpty) {
      _titleController.text = result.title!.trim();
    }
    if (result.description != null && result.description!.trim().isNotEmpty) {
      _descriptionController.text = result.description!.trim();
    }
    if (result.imageUrl != null && result.imageUrl!.trim().isNotEmpty) {
      _imageUrlController.text = result.imageUrl!.trim();
    }
    if (result.servings != null && result.servings! > 0) {
      _servingsController.text = result.servings.toString();
    }
    if (result.prepTimeMinutes != null && result.prepTimeMinutes! > 0) {
      _prepTimeController.text = result.prepTimeMinutes.toString();
    }
    if (result.cookTimeMinutes != null && result.cookTimeMinutes! > 0) {
      _cookTimeController.text = result.cookTimeMinutes.toString();
    }
    if (result.ingredients.isNotEmpty) {
      _ingredients
        ..clear()
        ..addAll(result.ingredients);
    }
    if (result.steps.isNotEmpty) {
      _steps
        ..clear()
        ..addAll(result.steps);
      _renumberSteps();
    }
    _syncStepIngredientSelections();
  }

  void _addIngredientFromInputs() {
    final name = _ingredientNameController.text.trim();
    final amount = _ingredientAmountController.text.trim();
    final unit = _ingredientUnitController.text.trim();

    if (name.isEmpty || amount.isEmpty) {
      _showSimpleMessage('Please enter both an ingredient amount and name');
      return;
    }

    setState(() {
      _ingredients.add(
        Ingredient(
          name: name,
          amount: amount,
          unit: unit.isNotEmpty ? unit : null,
          measurementSystem: _guessMeasurementSystem(unit),
        ),
      );
      _syncStepIngredientSelections();
    });

    _ingredientNameController.clear();
    _ingredientAmountController.clear();
    _ingredientUnitController.clear();
  }

  void _addStepFromInputs() {
    final title = _stepTitleController.text.trim();
    if (title.isEmpty) {
      _showSimpleMessage('Step title cannot be empty');
      return;
    }
    final descriptionText = _stepDescriptionController.text.trim();
    final timerText = _stepTimerController.text.trim();
    final timerMinutes = timerText.isNotEmpty ? int.tryParse(timerText) : null;
    final labelText = _stepTimerLabelController.text.trim();
    final selectedIngredients = _collectSelectedStepIngredients();

    setState(() {
      _steps.add(
        RecipeStep(
          stepNumber: _steps.length + 1,
          title: title,
          description: descriptionText.isNotEmpty ? descriptionText : null,
          timerSeconds: timerMinutes != null ? timerMinutes * 60 : null,
          timerLabel: labelText.isNotEmpty ? labelText : null,
          ingredientsForStep:
              selectedIngredients.isEmpty ? null : selectedIngredients,
        ),
      );
    });

    _resetStepForm();
  }

  void _reorderIngredient(int oldIndex, int newIndex) {
    if (newIndex < 0 || newIndex >= _ingredients.length) return;
    setState(() {
      final item = _ingredients.removeAt(oldIndex);
      _ingredients.insert(newIndex, item);
    });
  }

  void _resetStepForm() {
    _stepTitleController.clear();
    _stepDescriptionController.clear();
    _stepTimerController.clear();
    _stepTimerLabelController.clear();
    for (final selection in _stepIngredientSelections.values) {
      selection.clearSelection();
    }
  }

  List<Ingredient> _collectSelectedStepIngredients() {
    final selections = <Ingredient>[];
    for (final entry in _stepIngredientSelections.entries) {
      final selection = entry.value;
      if (!selection.selected) continue;
      final base = _findIngredientByName(entry.key);
      if (base == null) continue;
      selections.add(selection.buildIngredient(base));
    }
    return selections;
  }

  Ingredient? _findIngredientByName(String name) {
    for (final ingredient in _ingredients) {
      if (ingredient.name == name) {
        return ingredient;
      }
    }
    return null;
  }

  void _reorderStep(int oldIndex, int newIndex) {
    if (newIndex < 0 || newIndex >= _steps.length) return;
    setState(() {
      final step = _steps.removeAt(oldIndex);
      _steps.insert(newIndex, step);
      _renumberSteps();
    });
  }

  void _renumberSteps() {
    for (var i = 0; i < _steps.length; i++) {
      _steps[i] = _steps[i].copyWith(stepNumber: i + 1);
    }
  }

  MeasurementSystem _guessMeasurementSystem(String? unit) {
    final trimmed = unit?.trim().toLowerCase() ?? '';
    if (trimmed.isEmpty) return _autofillUnitSystem;
    const metricUnits = {
      'g',
      'gram',
      'grams',
      'kg',
      'kilogram',
      'kilograms',
      'ml',
      'milliliter',
      'milliliters',
      'millilitre',
      'millilitres',
      'l',
      'liter',
      'liters',
      'litre',
      'litres',
    };
    const customaryUnits = {
      'cup',
      'cups',
      'tsp',
      'teaspoon',
      'teaspoons',
      'tbsp',
      'tablespoon',
      'tablespoons',
      'oz',
      'ounce',
      'ounces',
      'lb',
      'lbs',
      'pound',
      'pounds',
    };
    if (metricUnits.contains(trimmed)) {
      return MeasurementSystem.metric;
    }
    if (customaryUnits.contains(trimmed)) {
      return MeasurementSystem.customary;
    }
    return _autofillUnitSystem;
  }

  Future<void> _editIngredient(int index) async {
    final result = await showDialog<Ingredient>(
      context: context,
      builder: (context) =>
          IngredientDialog(initialIngredient: _ingredients[index]),
    );

    if (result != null) {
      setState(() {
        _ingredients[index] = result;
        _syncStepIngredientSelections();
      });
    }
  }

  Future<void> _editStep(int index) async {
    final result = await showDialog<RecipeStep>(
      context: context,
      builder: (context) => StepDialog(
        stepNumber: index + 1,
        initialStep: _steps[index],
        availableIngredients: _ingredients,
      ),
    );

    if (result != null) {
      setState(() {
        _steps[index] = result.copyWith(stepNumber: index + 1);
      });
    }
  }

  void _showSimpleMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one ingredient')),
      );
      return;
    }

    if (_steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one step')),
      );
      return;
    }

    final recipe = Recipe(
      title: _titleController.text,
      description: _descriptionController.text,
      imageUrl:
          _imageUrlController.text.isNotEmpty ? _imageUrlController.text : null,
      servings: int.parse(_servingsController.text),
      prepTimeMinutes: _prepTimeController.text.isNotEmpty
          ? int.parse(_prepTimeController.text)
          : null,
      cookTimeMinutes: _cookTimeController.text.isNotEmpty
          ? int.parse(_cookTimeController.text)
          : null,
      category:
          _categoryController.text.isNotEmpty ? _categoryController.text : null,
      cuisine:
          _cuisineController.text.isNotEmpty ? _cuisineController.text : null,
      difficulty: _difficulty,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      isFavorite: widget.recipe?.isFavorite ?? false,
    );

    recipe.ingredients.addAll(_ingredients);
    recipe.steps.addAll(_steps);

    final firestoreService = ref.read(firestoreServiceProvider);

    if (widget.recipe != null && widget.recipe!.firestoreId != null) {
      // Update existing recipe
      recipe.id = widget.recipe!.id;
      recipe.firestoreId = widget.recipe!.firestoreId;
      recipe.createdAt = widget.recipe!.createdAt;
      await firestoreService.updateRecipe(widget.recipe!.firestoreId!, recipe);
    } else {
      // Create new recipe
      final id = await firestoreService.addRecipe(recipe);
      if (id == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: You must be signed in to create recipes'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    if (mounted) {
      context.pop(true);
    }
  }
}

class IngredientDialog extends StatefulWidget {
  final Ingredient? initialIngredient;

  const IngredientDialog({super.key, this.initialIngredient});

  @override
  State<IngredientDialog> createState() => _IngredientDialogState();
}

class _IngredientDialogState extends State<IngredientDialog> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _unitController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialIngredient != null) {
      _nameController.text = widget.initialIngredient!.name;
      _amountController.text = widget.initialIngredient!.amount;
      _unitController.text = widget.initialIngredient!.unit ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialIngredient != null;
    return AlertDialog(
      title: Text(isEditing ? 'Edit Ingredient' : 'Add Ingredient'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: 'Amount',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _unitController,
            decoration: const InputDecoration(
              labelText: 'Unit',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty &&
                _amountController.text.isNotEmpty) {
              final unitText = _unitController.text.trim();
              Navigator.of(context).pop(
                Ingredient(
                  name: _nameController.text,
                  amount: _amountController.text,
                  unit: unitText.isNotEmpty ? unitText : null,
                  measurementSystem:
                      widget.initialIngredient?.measurementSystem ??
                          MeasurementSystem.customary,
                  secondaryAmount: widget.initialIngredient?.secondaryAmount,
                  secondaryUnit: widget.initialIngredient?.secondaryUnit,
                  secondarySystem: widget.initialIngredient?.secondarySystem,
                  notes: widget.initialIngredient?.notes,
                ),
              );
            }
          },
          child: Text(isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

class StepDialog extends StatefulWidget {
  final int stepNumber;
  final RecipeStep? initialStep;
  final List<Ingredient> availableIngredients;

  const StepDialog({
    super.key,
    required this.stepNumber,
    this.initialStep,
    required this.availableIngredients,
  });

  @override
  State<StepDialog> createState() => _StepDialogState();
}

class _StepDialogState extends State<StepDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _timerController = TextEditingController();
  final _timerLabelController = TextEditingController();
  final Map<String, _StepIngredientSelection> _ingredientSelections = {};
  String? _titleError;

  @override
  void initState() {
    super.initState();
    if (widget.initialStep != null) {
      _titleController.text = widget.initialStep!.title;
      _descriptionController.text = widget.initialStep!.description ?? '';
      if (widget.initialStep!.timerSeconds != null) {
        _timerController.text = '${widget.initialStep!.timerSeconds! ~/ 60}';
      }
      _timerLabelController.text = widget.initialStep!.timerLabel ?? '';
    }

    for (final ingredient in widget.availableIngredients) {
      _ingredientSelections[ingredient.name] = _StepIngredientSelection(
        baseAmount: ingredient.amount,
        baseUnit: ingredient.unit,
      );
    }

    final initialIngredients = widget.initialStep?.ingredientsForStep ?? [];
    for (final ingredient in initialIngredients) {
      final selection = _ingredientSelections[ingredient.name];
      if (selection == null) continue;
      selection.selected = true;
      final matchesBase = ingredient.amount == selection.baseAmount &&
          (ingredient.unit ?? '') == (selection.baseUnit ?? '');
      selection.useFullAmount = matchesBase;
      if (!matchesBase) {
        selection.amountController.text = ingredient.amount;
        selection.unitController.text = ingredient.unit ?? '';
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _timerController.dispose();
    _timerLabelController.dispose();
    for (final selection in _ingredientSelections.values) {
      selection.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialStep != null;
    return AlertDialog(
      title: Text('${isEditing ? 'Edit' : 'Add'} Step ${widget.stepNumber}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Step title *',
                errorText: _titleError,
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _timerController,
              decoration: const InputDecoration(
                labelText: 'Timer (minutes)',
                helperText: 'Optional',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _timerLabelController,
              decoration: const InputDecoration(
                labelText: 'Timer label',
                helperText: 'Optional',
              ),
            ),
            const SizedBox(height: 12),
            _buildIngredientSelector(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }

  Widget _buildIngredientSelector() {
    if (widget.availableIngredients.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Ingredients for this step (optional)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        const SizedBox(height: 8),
        ...widget.availableIngredients.map((ingredient) {
          final selection = _ingredientSelections[ingredient.name]!;
          final isLast = ingredient == widget.availableIngredients.last;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: selection.selected,
                title: Text(ingredient.name),
                subtitle: Text(formatIngredientSummary(ingredient)),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (value) {
                  setState(() {
                    selection.selected = value ?? false;
                    if (selection.selected && selection.useFullAmount) {
                      selection.updateBase(ingredient.amount, ingredient.unit);
                    }
                  });
                },
              ),
              if (selection.selected)
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Use full amount (${formatIngredientSummary(ingredient)})',
                        ),
                        value: selection.useFullAmount,
                        onChanged: (value) {
                          setState(() {
                            selection.useFullAmount = value;
                            if (value) {
                              selection.updateBase(
                                  ingredient.amount, ingredient.unit);
                            }
                          });
                        },
                      ),
                      if (!selection.useFullAmount)
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: 120,
                              child: TextField(
                                controller: selection.amountController,
                                decoration: const InputDecoration(
                                  labelText: 'Amount',
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 120,
                              child: TextField(
                                controller: selection.unitController,
                                decoration: const InputDecoration(
                                  labelText: 'Unit',
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              if (!isLast) const Divider(),
            ],
          );
        }),
      ],
    );
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() {
        _titleError = 'Please enter a title';
      });
      return;
    }
    setState(() {
      _titleError = null;
    });

    final descriptionText = _descriptionController.text.trim();
    final timerText = _timerController.text.trim();
    final timerMinutes = timerText.isNotEmpty ? int.tryParse(timerText) : null;
    final timerLabelText = _timerLabelController.text.trim();
    final selectedIngredients = _collectSelectedIngredients();

    Navigator.of(context).pop(
      RecipeStep(
        stepNumber: widget.stepNumber,
        title: title,
        description: descriptionText.isNotEmpty ? descriptionText : null,
        timerSeconds: timerMinutes != null ? timerMinutes * 60 : null,
        timerLabel: timerLabelText.isNotEmpty ? timerLabelText : null,
        ingredientsForStep:
            selectedIngredients.isEmpty ? null : selectedIngredients,
      ),
    );
  }

  List<Ingredient> _collectSelectedIngredients() {
    final selections = <Ingredient>[];
    for (final entry in _ingredientSelections.entries) {
      final selection = entry.value;
      if (!selection.selected) continue;
      final base = _findIngredient(entry.key);
      if (base == null) continue;
      selections.add(selection.buildIngredient(base));
    }
    return selections;
  }

  Ingredient? _findIngredient(String name) {
    for (final ingredient in widget.availableIngredients) {
      if (ingredient.name == name) {
        return ingredient;
      }
    }
    return null;
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
            ],
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _StepIngredientSelection {
  bool selected = false;
  bool useFullAmount = true;
  String baseAmount;
  String? baseUnit;
  final TextEditingController amountController;
  final TextEditingController unitController;

  _StepIngredientSelection({
    required this.baseAmount,
    required this.baseUnit,
  })  : amountController = TextEditingController(text: baseAmount),
        unitController = TextEditingController(text: baseUnit ?? '');

  void updateBase(String amount, String? unit) {
    baseAmount = amount;
    baseUnit = unit;
    if (useFullAmount) {
      amountController.text = amount;
      unitController.text = unit ?? '';
    }
  }

  void clearSelection() {
    selected = false;
    useFullAmount = true;
    amountController.text = baseAmount;
    unitController.text = baseUnit ?? '';
  }

  Ingredient buildIngredient(Ingredient base) {
    final amountText =
        useFullAmount ? baseAmount : amountController.text.trim();
    final unitText = useFullAmount ? baseUnit : unitController.text.trim();
    final resolvedAmount = amountText.isNotEmpty ? amountText : baseAmount;
    final resolvedUnit =
        unitText != null && unitText.isNotEmpty ? unitText : null;
    return base.copyWith(
      amount: resolvedAmount,
      unit: resolvedUnit,
    );
  }

  void dispose() {
    amountController.dispose();
    unitController.dispose();
  }
}

String formatAmountUnitText(String amount, String? unit) {
  final trimmedAmount = amount.trim();
  final trimmedUnit = unit?.trim() ?? '';
  if (trimmedAmount.isEmpty && trimmedUnit.isEmpty) {
    return '';
  }
  if (trimmedUnit.isEmpty) return trimmedAmount;
  if (trimmedAmount.isEmpty) return trimmedUnit;
  return '$trimmedAmount $trimmedUnit';
}

String formatIngredientSummary(Ingredient ingredient) {
  final primary = formatAmountUnitText(ingredient.amount, ingredient.unit);
  final hasSecondary = ingredient.secondaryAmount != null &&
      ingredient.secondaryAmount!.trim().isNotEmpty;
  if (hasSecondary) {
    final secondary = formatAmountUnitText(
      ingredient.secondaryAmount!,
      ingredient.secondaryUnit,
    );
    if (secondary.isNotEmpty) {
      if (primary.isEmpty) return secondary;
      return '$primary ($secondary)';
    }
  }
  return primary;
}
