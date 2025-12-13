import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:recipe_keeper/models/ingredient.dart';
import 'package:recipe_keeper/models/recipe.dart';
import 'package:recipe_keeper/providers/firebase_providers.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  final String recipeId;
  final Recipe? recipe;

  const RecipeDetailScreen({super.key, required this.recipeId, this.recipe});

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  Recipe? _currentRecipe;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentRecipe = widget.recipe;
    if (_currentRecipe == null) _loadRecipe();
  }

  Future<void> _loadRecipe() async {
    setState(() => _isLoading = true);
    final firestoreService = ref.read(firestoreServiceProvider);
    final recipe = await firestoreService.getRecipeById(widget.recipeId);
    if (mounted)
      setState(() {
        _currentRecipe = recipe;
        _isLoading = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: CircularProgressIndicator()));
    }

    if (_currentRecipe == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Not Found')),
        body: Center(
            child: ElevatedButton(
                onPressed: () => context.go('/'), child: const Text('Back'))),
      );
    }

    final recipe = _currentRecipe!;
    final theme = Theme.of(context);
    final totalTime =
        (recipe.prepTimeMinutes ?? 0) + (recipe.cookTimeMinutes ?? 0);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar with image
          SliverAppBar(
            expandedHeight: recipe.imageUrl != null ? 300 : 120,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                recipe.title,
                style: const TextStyle(
                  shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                ),
              ),
              background: recipe.imageUrl != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: recipe.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Center(
                                child: CircularProgressIndicator()),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.restaurant, size: 64),
                          ),
                        ),
                        // Gradient overlay for better text readability
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      color: theme.colorScheme.primaryContainer,
                      child: Center(
                        child: Icon(
                          Icons.restaurant,
                          size: 64,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: recipe.isFavorite ? Colors.red : null,
                ),
                tooltip: recipe.isFavorite
                    ? 'Remove from favorites'
                    : 'Add to favorites',
                onPressed: () async {
                  if (recipe.firestoreId == null) return;
                  final firestoreService = ref.read(firestoreServiceProvider);
                  await firestoreService.toggleFavorite(
                      recipe.firestoreId!, !recipe.isFavorite);
                  await _loadRecipe();
                },
              ),
              PopupMenuButton(
                icon: const Icon(Icons.more_vert),
                itemBuilder: (c) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (v) async {
                  if (v == 'edit') {
                    final result = await context.push<bool>(
                      '/recipe/${widget.recipeId}/edit',
                      extra: _currentRecipe,
                    );
                    if (result == true && mounted) {
                      await _loadRecipe();
                    }
                  } else if (v == 'delete') {
                    if (recipe.firestoreId == null) return;
                    final conf = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Delete Recipe'),
                        content: Text(
                            'Are you sure you want to delete "${recipe.title}"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (conf == true) {
                      if (!mounted) return;
                      // ignore: use_build_context_synchronously
                      final router = GoRouter.of(context);
                      final firestoreService =
                          ref.read(firestoreServiceProvider);
                      await firestoreService.deleteRecipe(recipe.firestoreId!);
                      if (!mounted) return;
                      router.go('/');
                    }
                  }
                },
              ),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick info cards
                  Row(
                    children: [
                      Expanded(
                        child: _InfoCard(
                          icon: Icons.schedule,
                          label: 'Prep',
                          value: recipe.prepTimeMinutes != null
                              ? '${recipe.prepTimeMinutes}m'
                              : '-',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _InfoCard(
                          icon: Icons.timer,
                          label: 'Cook',
                          value: recipe.cookTimeMinutes != null
                              ? '${recipe.cookTimeMinutes}m'
                              : '-',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _InfoCard(
                          icon: Icons.restaurant,
                          label: 'Servings',
                          value: '${recipe.servings}',
                        ),
                      ),
                    ],
                  ),

                  if (totalTime > 0) ...[
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.access_time,
                                size: 20, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Total: ${totalTime}m',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Metadata chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: Icon(
                          Icons.bar_chart,
                          size: 18,
                          color: _getDifficultyColor(recipe.difficulty),
                        ),
                        label: Text(
                          recipe.difficulty.name.toUpperCase(),
                          style: TextStyle(
                            color: _getDifficultyColor(recipe.difficulty),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: _getDifficultyColor(recipe.difficulty)
                            .withValues(alpha: 0.1),
                      ),
                      if (recipe.category != null)
                        Chip(
                          avatar: const Icon(Icons.category, size: 18),
                          label: Text(recipe.category!),
                        ),
                      if (recipe.cuisine != null)
                        Chip(
                          avatar: const Icon(Icons.public, size: 18),
                          label: Text(recipe.cuisine!),
                        ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Description
                  if (recipe.description.isNotEmpty) ...[
                    Text(
                      recipe.description,
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Tags
                  if (recipe.tags != null && recipe.tags!.isNotEmpty) ...[
                    const Divider(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.local_offer,
                            size: 20, color: theme.colorScheme.secondary),
                        const SizedBox(width: 8),
                        Text(
                          'Tags',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: recipe.tags!
                          .map((tag) => Chip(
                                label: Text(tag),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                labelStyle: const TextStyle(fontSize: 12),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Ingredients
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.shopping_basket,
                          size: 24, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        'Ingredients',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${recipe.ingredients.length} items',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:
                            recipe.ingredients.asMap().entries.map((entry) {
                          final i = entry.value;
                          final isLast =
                              entry.key == recipe.ingredients.length - 1;
                          return Padding(
                            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '${_formatIngredientAmount(i)} ${i.name}'
                                        .trim(),
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Instructions
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.format_list_numbered,
                          size: 24, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        'Instructions',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${recipe.steps.length} steps',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...recipe.steps.map((step) {
                    final displayTitle = step.title.isNotEmpty
                        ? step.title
                        : 'Step ${step.stepNumber}';
                    final hasDescription = step.description != null &&
                        step.description!.trim().isNotEmpty;
                    final timerMinutes = step.timerSeconds != null
                        ? step.timerSeconds! ~/ 60
                        : null;
                    final stepIngredients = step.ingredientsForStep ?? [];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              child: Text(
                                '${step.stepNumber}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayTitle,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  if (hasDescription) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      step.description!,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(height: 1.5),
                                    ),
                                  ],
                                  if (stepIngredients.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      'Ingredients for this step',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children:
                                          stepIngredients.map((ingredient) {
                                        return Chip(
                                          label: Text(
                                            '${_formatIngredientAmount(ingredient)} ${ingredient.name}'
                                                .trim(),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                  if (timerMinutes != null) ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.timer,
                                          size: 16,
                                          color: theme.colorScheme.secondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$timerMinutes minutes${step.timerLabel != null ? ' · ${step.timerLabel}' : ''}',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            color: theme.colorScheme.secondary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (!hasDescription &&
                                      stepIngredients.isEmpty &&
                                      timerMinutes == null)
                                    Text(
                                      'No additional details for this step.',
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(height: 1.5),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // Notes
                  if (recipe.notes != null && recipe.notes!.isNotEmpty) ...[
                    const Divider(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.note,
                            size: 20, color: theme.colorScheme.secondary),
                        const SizedBox(width: 8),
                        Text(
                          'Chef\'s Notes',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Card(
                      color: theme.colorScheme.secondaryContainer
                          .withValues(alpha: 0.3),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          recipe.notes!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 80), // Space for FAB
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push('/recipe/${recipe.id}/cook', extra: recipe),
        icon: const Icon(Icons.restaurant_menu),
        label: const Text('Start Cooking'),
        heroTag: 'cook_button',
      ),
    );
  }

  Color _getDifficultyColor(DifficultyLevel difficulty) {
    switch (difficulty) {
      case DifficultyLevel.easy:
        return Colors.green;
      case DifficultyLevel.medium:
        return Colors.orange;
      case DifficultyLevel.hard:
        return Colors.red;
    }
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

  String _formatIngredientAmount(Ingredient ingredient) {
    final primary = _formatAmountUnit(ingredient.amount, ingredient.unit);
    final hasSecondary = ingredient.secondaryAmount != null &&
        ingredient.secondaryAmount!.trim().isNotEmpty;
    if (hasSecondary) {
      final secondary = _formatAmountUnit(
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
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, size: 24, color: theme.colorScheme.primary),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
