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

  DifficultyLevel _difficulty = DifficultyLevel.medium;
  final List<Ingredient> _ingredients = [];
  final List<RecipeStep> _steps = [];
  final List<String> _tags = [];
  
  bool _isSaving = false;
  int? _expandedIngredientIndex;
  int? _expandedStepIndex;

  // Common suggestions for autocomplete
  final List<String> _categoryOptions = [
    'Breakfast', 'Lunch', 'Dinner', 'Dessert', 'Appetizer', 
    'Snack', 'Beverage', 'Salad', 'Soup', 'Bread', 'Sauce'
  ];
  
  final List<String> _cuisineOptions = [
    'American', 'Italian', 'Mexican', 'Chinese', 'Japanese',
    'Indian', 'French', 'Thai', 'Mediterranean', 'Greek', 'Korean'
  ];

  final List<String> _unitOptions = [
    'cup', 'cups', 'tbsp', 'tsp', 'oz', 'lb', 'g', 'kg', 'ml', 'l',
    'whole', 'pinch', 'dash', 'to taste', 'clove', 'cloves'
  ];

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe == null ? 'New Recipe' : 'Edit Recipe'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveRecipe,
              tooltip: 'Save Recipe',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBasicInfoSection(),
              const SizedBox(height: 20),
              _buildTimingSection(),
              const SizedBox(height: 20),
              _buildCategorySection(),
              const SizedBox(height: 20),
              _buildTagsSection(),
              const SizedBox(height: 20),
              _buildIngredientsSection(),
              const SizedBox(height: 20),
              _buildStepsSection(),
              const SizedBox(height: 20),
              _buildNotesSection(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: _isSaving
          ? null
          : FloatingActionButton.extended(
              onPressed: _saveRecipe,
              icon: const Icon(Icons.save),
              label: const Text('Save Recipe'),
            ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Basic Information', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Recipe Title',
                hintText: 'e.g., Grandma\'s Chocolate Chip Cookies',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.restaurant_menu),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) => value?.isEmpty ?? true ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'What makes this recipe special?',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) => value?.isEmpty ?? true ? 'Description is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _imageUrlController,
              decoration: const InputDecoration(
                labelText: 'Image URL (optional)',
                hintText: 'https://example.com/recipe-image.jpg',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.image),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Timing & Difficulty', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _servingsController,
                    decoration: const InputDecoration(
                      labelText: 'Servings',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.people),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<DifficultyLevel>(
                    value: _difficulty,
                    decoration: const InputDecoration(
                      labelText: 'Difficulty',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.speed),
                    ),
                    items: DifficultyLevel.values.map((level) {
                      IconData icon;
                      Color? color;
                      switch (level) {
                        case DifficultyLevel.easy:
                          icon = Icons.sentiment_satisfied;
                          color = Colors.green;
                          break;
                        case DifficultyLevel.medium:
                          icon = Icons.sentiment_neutral;
                          color = Colors.orange;
                          break;
                        case DifficultyLevel.hard:
                          icon = Icons.sentiment_very_dissatisfied;
                          color = Colors.red;
                          break;
                      }
                      return DropdownMenuItem(
                        value: level,
                        child: Row(
                          children: [
                            Icon(icon, size: 18, color: color),
                            const SizedBox(width: 8),
                            Text(level.name[0].toUpperCase() + level.name.substring(1)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _difficulty = value);
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
                    controller: _prepTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Prep Time',
                      suffixText: 'min',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.timer),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cookTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Cook Time',
                      suffixText: 'min',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.local_fire_department),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            if (_prepTimeController.text.isNotEmpty || _cookTimeController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Total: ${_getTotalTime()} minutes',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  int _getTotalTime() {
    final prep = int.tryParse(_prepTimeController.text) ?? 0;
    final cook = int.tryParse(_cookTimeController.text) ?? 0;
    return prep + cook;
  }

  Widget _buildCategorySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category & Cuisine', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Autocomplete<String>(
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return _categoryOptions.where((option) =>
                          option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                    },
                    onSelected: (selection) {
                      _categoryController.text = selection;
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      controller.text = _categoryController.text;
                      controller.addListener(() {
                        _categoryController.text = controller.text;
                      });
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          hintText: 'e.g., Dinner, Dessert',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        textCapitalization: TextCapitalization.words,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Autocomplete<String>(
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return _cuisineOptions.where((option) =>
                          option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                    },
                    onSelected: (selection) {
                      _cuisineController.text = selection;
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      controller.text = _cuisineController.text;
                      controller.addListener(() {
                        _cuisineController.text = controller.text;
                      });
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Cuisine',
                          hintText: 'e.g., Italian, Mexican',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.public),
                        ),
                        textCapitalization: TextCapitalization.words,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tags', style: Theme.of(context).textTheme.titleLarge),
                FilledButton.tonalIcon(
                  onPressed: _addTag,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Tag'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_tags.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_offer, 
                      color: Theme.of(context).colorScheme.secondary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Add tags to help organize and find recipes (e.g., vegetarian, quick, spicy)',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tags.map((tag) => Chip(
                  avatar: const Icon(Icons.local_offer, size: 16),
                  label: Text(tag),
                  onDeleted: () {
                    setState(() => _tags.remove(tag));
                  },
                  deleteIcon: const Icon(Icons.close, size: 18),
                )).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Ingredients', style: Theme.of(context).textTheme.titleLarge),
                FilledButton.tonalIcon(
                  onPressed: _addIngredient,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Ingredient'),
                ),
              ],
            ),
            if (_ingredients.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.error.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, 
                        color: Theme.of(context).colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'At least one ingredient is required',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              const SizedBox(height: 12),
            ..._ingredients.asMap().entries.map((entry) {
              final index = entry.key;
              final ingredient = entry.value;
              final isExpanded = _expandedIngredientIndex == index;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: isExpanded ? 4 : 1,
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: Text('${index + 1}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      title: Text(ingredient.name),
                      subtitle: Text('${ingredient.amount} ${ingredient.unit}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy, size: 20),
                            onPressed: () => _duplicateIngredient(index),
                            tooltip: 'Duplicate',
                          ),
                          IconButton(
                            icon: Icon(isExpanded ? Icons.expand_less : Icons.edit, size: 20),
                            onPressed: () {
                              setState(() {
                                _expandedIngredientIndex = isExpanded ? null : index;
                              });
                            },
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                            onPressed: () => _removeIngredient(index),
                            tooltip: 'Delete',
                          ),
                        ],
                      ),
                    ),
                    if (isExpanded)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: _buildIngredientEditor(index),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientEditor(int index) {
    final ingredient = _ingredients[index];
    final nameController = TextEditingController(text: ingredient.name);
    final amountController = TextEditingController(text: ingredient.amount);
    final unitController = TextEditingController(text: ingredient.unit);

    return Column(
      children: [
        TextFormField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Ingredient Name',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: (value) {
            _ingredients[index] = Ingredient(
              name: value,
              amount: ingredient.amount,
              unit: ingredient.unit,
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) {
                  _ingredients[index] = Ingredient(
                    name: ingredient.name,
                    amount: value,
                    unit: ingredient.unit,
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: Autocomplete<String>(
                initialValue: TextEditingValue(text: ingredient.unit),
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return _unitOptions;
                  }
                  return _unitOptions.where((option) =>
                      option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                },
                onSelected: (selection) {
                  _ingredients[index] = Ingredient(
                    name: ingredient.name,
                    amount: ingredient.amount,
                    unit: selection,
                  );
                  setState(() {});
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  controller.text = unitController.text;
                  controller.addListener(() {
                    _ingredients[index] = Ingredient(
                      name: ingredient.name,
                      amount: ingredient.amount,
                      unit: controller.text,
                    );
                  });
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _expandedIngredientIndex = null;
              });
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Done'),
          ),
        ),
      ],
    );
  }

  Widget _buildStepsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Instructions', style: Theme.of(context).textTheme.titleLarge),
                FilledButton.tonalIcon(
                  onPressed: _addStep,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Step'),
                ),
              ],
            ),
            if (_steps.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.error.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, 
                        color: Theme.of(context).colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'At least one step is required',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              const SizedBox(height: 12),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _steps.length,
              onReorder: _reorderSteps,
              itemBuilder: (context, index) {
                final step = _steps[index];
                final isExpanded = _expandedStepIndex == index;
                
                return Card(
                  key: ValueKey(step.stepNumber),
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: isExpanded ? 4 : 1,
                  child: Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                          child: Text('${step.stepNumber}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                        title: Text(
                          step.instruction,
                          maxLines: isExpanded ? null : 2,
                          overflow: isExpanded ? null : TextOverflow.ellipsis,
                        ),
                        subtitle: step.timerSeconds != null
                            ? Row(
                                children: [
                                  const Icon(Icons.timer, size: 14),
                                  const SizedBox(width: 4),
                                  Text('${step.timerSeconds! ~/ 60} min${step.timerLabel != null ? ' - ${step.timerLabel}' : ''}'),
                                ],
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.drag_handle, 
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            IconButton(
                              icon: Icon(isExpanded ? Icons.expand_less : Icons.edit, size: 20),
                              onPressed: () {
                                setState(() {
                                  _expandedStepIndex = isExpanded ? null : index;
                                });
                              },
                              tooltip: 'Edit',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                              onPressed: () => _removeStep(index),
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                      ),
                      if (isExpanded)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: _buildStepEditor(index),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepEditor(int index) {
    final step = _steps[index];
    final instructionController = TextEditingController(text: step.instruction);
    final timerController = TextEditingController(
      text: step.timerSeconds != null ? (step.timerSeconds! ~/ 60).toString() : '',
    );
    final timerLabelController = TextEditingController(text: step.timerLabel ?? '');

    return Column(
      children: [
        TextFormField(
          controller: instructionController,
          decoration: const InputDecoration(
            labelText: 'Instruction',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (value) {
            _steps[index] = RecipeStep(
              stepNumber: step.stepNumber,
              instruction: value,
              timerSeconds: step.timerSeconds,
              timerLabel: step.timerLabel,
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: timerController,
                decoration: const InputDecoration(
                  labelText: 'Timer (minutes)',
                  border: OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: Icon(Icons.timer, size: 20),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) {
                  _steps[index] = RecipeStep(
                    stepNumber: step.stepNumber,
                    instruction: step.instruction,
                    timerSeconds: value.isNotEmpty ? int.parse(value) * 60 : null,
                    timerLabel: step.timerLabel,
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: timerLabelController,
                decoration: const InputDecoration(
                  labelText: 'Timer Label',
                  border: OutlineInputBorder(),
                  isDense: true,
                  hintText: 'e.g., Baking',
                ),
                textCapitalization: TextCapitalization.words,
                onChanged: (value) {
                  _steps[index] = RecipeStep(
                    stepNumber: step.stepNumber,
                    instruction: step.instruction,
                    timerSeconds: step.timerSeconds,
                    timerLabel: value.isNotEmpty ? value : null,
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _expandedStepIndex = null;
              });
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Done'),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Additional Notes', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Tips, variations, or storage instructions...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
    );
  }

  void _addTag() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Tag'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Tag name',
            hintText: 'e.g., vegetarian, quick, spicy',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              Navigator.pop(context, value);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(context, controller.text);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && !_tags.contains(result)) {
      setState(() => _tags.add(result));
    }
  }

  void _addIngredient() {
    setState(() {
      _ingredients.add(Ingredient(
        name: 'New ingredient',
        amount: '1',
        unit: 'cup',
      ));
      _expandedIngredientIndex = _ingredients.length - 1;
    });
  }

  void _duplicateIngredient(int index) {
    final ingredient = _ingredients[index];
    setState(() {
      _ingredients.insert(index + 1, Ingredient(
        name: ingredient.name,
        amount: ingredient.amount,
        unit: ingredient.unit,
      ));
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
      if (_expandedIngredientIndex == index) {
        _expandedIngredientIndex = null;
      } else if (_expandedIngredientIndex != null && _expandedIngredientIndex! > index) {
        _expandedIngredientIndex = _expandedIngredientIndex! - 1;
      }
    });
  }

  void _addStep() {
    setState(() {
      _steps.add(RecipeStep(
        stepNumber: _steps.length + 1,
        instruction: 'Describe this step...',
        timerSeconds: null,
        timerLabel: null,
      ));
      _expandedStepIndex = _steps.length - 1;
    });
  }

  void _removeStep(int index) {
    setState(() {
      _steps.removeAt(index);
      _renumberSteps();
      if (_expandedStepIndex == index) {
        _expandedStepIndex = null;
      } else if (_expandedStepIndex != null && _expandedStepIndex! > index) {
        _expandedStepIndex = _expandedStepIndex! - 1;
      }
    });
  }

  void _reorderSteps(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
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

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one ingredient'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one step'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final recipe = Recipe(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrl: _imageUrlController.text.trim().isNotEmpty 
            ? _imageUrlController.text.trim() 
            : null,
        servings: int.parse(_servingsController.text),
        prepTimeMinutes: _prepTimeController.text.isNotEmpty 
            ? int.parse(_prepTimeController.text) 
            : null,
        cookTimeMinutes: _cookTimeController.text.isNotEmpty 
            ? int.parse(_cookTimeController.text) 
            : null,
        category: _categoryController.text.trim().isNotEmpty 
            ? _categoryController.text.trim() 
            : null,
        cuisine: _cuisineController.text.trim().isNotEmpty 
            ? _cuisineController.text.trim() 
            : null,
        difficulty: _difficulty,
        notes: _notesController.text.trim().isNotEmpty 
            ? _notesController.text.trim() 
            : null,
        isFavorite: widget.recipe?.isFavorite ?? false,
      );

      recipe.ingredients.addAll(_ingredients);
      recipe.steps.addAll(_steps);
      if (_tags.isNotEmpty) {
        recipe.tags = _tags;
      }

      final firestoreService = ref.read(firestoreServiceProvider);
      
      if (widget.recipe != null && widget.recipe!.firestoreId != null) {
        recipe.id = widget.recipe!.id;
        recipe.firestoreId = widget.recipe!.firestoreId;
        recipe.createdAt = widget.recipe!.createdAt;
        await firestoreService.updateRecipe(widget.recipe!.firestoreId!, recipe);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recipe updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
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
          setState(() => _isSaving = false);
          return;
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recipe created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      if (mounted) {
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving recipe: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isSaving = false);
    }
  }
}
