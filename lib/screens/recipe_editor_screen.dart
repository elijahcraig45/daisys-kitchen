import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_keeper/models/recipe.dart';
import 'package:recipe_keeper/models/ingredient.dart';
import 'package:recipe_keeper/models/recipe_step.dart';
import 'package:recipe_keeper/providers/firebase_providers.dart';

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
  final _stepInstructionController = TextEditingController();
  final _stepTimerController = TextEditingController();
  final _stepTimerLabelController = TextEditingController();

  DifficultyLevel _difficulty = DifficultyLevel.medium;
  final List<Ingredient> _ingredients = [];
  final List<RecipeStep> _steps = [];
  final List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    if (widget.recipe != null) {
      _loadRecipe(widget.recipe!);
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
    _stepInstructionController.dispose();
    _stepTimerController.dispose();
    _stepTimerLabelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe == null ? 'New Recipe' : 'Edit Recipe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveRecipe,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Recipe Title *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
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
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _imageUrlController,
                decoration: const InputDecoration(
                  labelText: 'Image URL (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _servingsController,
                      decoration: const InputDecoration(
                        labelText: 'Servings *',
                        border: OutlineInputBorder(),
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _prepTimeController,
                      decoration: const InputDecoration(
                        labelText: 'Prep Time (min)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cookTimeController,
                      decoration: const InputDecoration(
                        labelText: 'Cook Time (min)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<DifficultyLevel>(
                      value: _difficulty,
                      decoration: const InputDecoration(
                        labelText: 'Difficulty',
                        border: OutlineInputBorder(),
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
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _cuisineController,
                      decoration: const InputDecoration(
                        labelText: 'Cuisine',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildTagsSection(),
              const SizedBox(height: 24),
              _buildIngredientsSection(),
              const SizedBox(height: 24),
              _buildStepsSection(),
              const SizedBox(height: 24),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Wrap(
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
              width: 220,
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
        ),
      ],
    );
  }

  void _handleAddTag() {
    final value = _tagInputController.text.trim();
    if (value.isEmpty) return;
    if (_tags.contains(value)) {
      _showSimpleMessage('Tag \"$value\" already added');
      return;
    }
    setState(() {
      _tags.add(value);
    });
    _tagInputController.clear();
  }

  Widget _buildIngredientsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ingredients',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 140,
                      child: TextField(
                        controller: _ingredientAmountController,
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: TextField(
                        controller: _ingredientUnitController,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      child: TextField(
                        controller: _ingredientNameController,
                        decoration: const InputDecoration(
                          labelText: 'Ingredient name',
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _addIngredientFromInputs(),
                      ),
                    ),
                  ],
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
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_ingredients.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.list_alt, color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No ingredients added yet. Use the form above to build your list.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
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
                  subtitle: Text('${ingredient.amount} ${ingredient.unit}'.trim()),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_upward),
                        tooltip: 'Move up',
                        onPressed: index == 0 ? null : () => _reorderIngredient(index, index - 1),
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
    );
  }

  Widget _buildStepsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Steps',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _stepInstructionController,
                  decoration: const InputDecoration(
                    labelText: 'Instruction',
                    hintText: 'Describe what needs to happen in this step',
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _stepTimerLabelController,
                        decoration: const InputDecoration(
                          labelText: 'Timer label',
                          helperText: 'e.g., Simmer sauce',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _addStepFromInputs,
                    icon: const Icon(Icons.add_task),
                    label: const Text('Add Step'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_steps.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.numbers, color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No steps yet. Add instructions so cooks can follow along.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: _steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              final timerMinutes = step.timerSeconds != null ? step.timerSeconds! ~/ 60 : null;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text('${step.stepNumber}'),
                  ),
                  title: Text(step.instruction),
                  subtitle: timerMinutes != null
                      ? Text(
                          '${timerMinutes} min timer${step.timerLabel != null ? ' · ${step.timerLabel}' : ''}',
                        )
                      : null,
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_upward),
                        tooltip: 'Move up',
                        onPressed: index == 0 ? null : () => _reorderStep(index, index - 1),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_downward),
                        tooltip: 'Move down',
                        onPressed: index == _steps.length - 1 ? null : () => _reorderStep(index, index + 1),
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
    );
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
      _ingredients.add(Ingredient(name: name, amount: amount, unit: unit));
    });

    _ingredientNameController.clear();
    _ingredientAmountController.clear();
    _ingredientUnitController.clear();
  }

  void _addStepFromInputs() {
    final instruction = _stepInstructionController.text.trim();
    if (instruction.isEmpty) {
      _showSimpleMessage('Step instruction cannot be empty');
      return;
    }
    final timerText = _stepTimerController.text.trim();
    final timerMinutes = timerText.isNotEmpty ? int.tryParse(timerText) : null;
    final labelText = _stepTimerLabelController.text.trim();

    setState(() {
      _steps.add(
        RecipeStep(
          stepNumber: _steps.length + 1,
          instruction: instruction,
          timerSeconds: timerMinutes != null ? timerMinutes * 60 : null,
          timerLabel: labelText.isNotEmpty ? labelText : null,
        ),
      );
    });

    _stepInstructionController.clear();
    _stepTimerController.clear();
    _stepTimerLabelController.clear();
  }

  void _reorderIngredient(int oldIndex, int newIndex) {
    if (newIndex < 0 || newIndex >= _ingredients.length) return;
    setState(() {
      final item = _ingredients.removeAt(oldIndex);
      _ingredients.insert(newIndex, item);
    });
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

  Future<void> _editIngredient(int index) async {
    final result = await showDialog<Ingredient>(
      context: context,
      builder: (context) => IngredientDialog(initialIngredient: _ingredients[index]),
    );

    if (result != null) {
      setState(() {
        _ingredients[index] = result;
      });
    }
  }

  Future<void> _editStep(int index) async {
    final result = await showDialog<RecipeStep>(
      context: context,
      builder: (context) => StepDialog(
        stepNumber: index + 1,
        initialStep: _steps[index],
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
      imageUrl: _imageUrlController.text.isNotEmpty ? _imageUrlController.text : null,
      servings: int.parse(_servingsController.text),
      prepTimeMinutes: _prepTimeController.text.isNotEmpty 
          ? int.parse(_prepTimeController.text) 
          : null,
      cookTimeMinutes: _cookTimeController.text.isNotEmpty 
          ? int.parse(_cookTimeController.text) 
          : null,
      category: _categoryController.text.isNotEmpty ? _categoryController.text : null,
      cuisine: _cuisineController.text.isNotEmpty ? _cuisineController.text : null,
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
      _unitController.text = widget.initialIngredient!.unit;
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
                _amountController.text.isNotEmpty &&
                _unitController.text.isNotEmpty) {
              Navigator.of(context).pop(
                Ingredient(
                  name: _nameController.text,
                  amount: _amountController.text,
                  unit: _unitController.text,
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

  const StepDialog({super.key, required this.stepNumber, this.initialStep});

  @override
  State<StepDialog> createState() => _StepDialogState();
}

class _StepDialogState extends State<StepDialog> {
  final _instructionController = TextEditingController();
  final _timerController = TextEditingController();
  final _timerLabelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialStep != null) {
      _instructionController.text = widget.initialStep!.instruction;
      if (widget.initialStep!.timerSeconds != null) {
        _timerController.text = '${widget.initialStep!.timerSeconds! ~/ 60}';
      }
      _timerLabelController.text = widget.initialStep!.timerLabel ?? '';
    }
  }

  @override
  void dispose() {
    _instructionController.dispose();
    _timerController.dispose();
    _timerLabelController.dispose();
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
              controller: _instructionController,
              decoration: const InputDecoration(
                labelText: 'Instruction',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _timerController,
              decoration: const InputDecoration(
                labelText: 'Timer (minutes, optional)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _timerLabelController,
              decoration: const InputDecoration(
                labelText: 'Timer Label (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_instructionController.text.isNotEmpty) {
              Navigator.of(context).pop(
                RecipeStep(
                  stepNumber: widget.stepNumber,
                  instruction: _instructionController.text,
                  timerSeconds: _timerController.text.isNotEmpty
                      ? int.parse(_timerController.text) * 60
                      : null,
                  timerLabel: _timerLabelController.text.isNotEmpty
                      ? _timerLabelController.text
                      : null,
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
