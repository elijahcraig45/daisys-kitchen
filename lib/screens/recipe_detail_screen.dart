import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:recipe_keeper/models/ingredient.dart';
import 'package:recipe_keeper/models/recipe.dart';
import 'package:recipe_keeper/providers/firebase_providers.dart';
import 'package:recipe_keeper/theme/app_theme.dart';
import 'package:recipe_keeper/utils/snackbar_helper.dart';

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

  /// Whether the signed-in user wrote this. Recipes predating `createdBy` have no author,
  /// and are treated as the viewer's own so they remain editable rather than becoming
  /// read-only for everybody.
  bool _isMine(Recipe recipe) {
    final uid = ref.read(currentUserProvider).valueOrNull?.uid;
    return recipe.createdBy == null || recipe.createdBy == uid;
  }

  /// Save is a bookmark: the author's later corrections are what you see. It becomes a
  /// copy of your own the first time you edit it.
  Widget _buildSaveButton(Recipe recipe) {
    final saved = ref.watch(savedRecipeIdsProvider).valueOrNull ?? const <String>{};
    final isSaved = recipe.firestoreId != null && saved.contains(recipe.firestoreId);
    return IconButton(
      icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
      tooltip: isSaved ? 'Remove from my recipes' : 'Save to my recipes',
      onPressed: () async {
        final ok = await ref
            .read(firestoreServiceProvider)
            .setSaved(recipe, !isSaved);
        if (!mounted) return;
        if (ok) {
          SnackBarHelper.showSuccess(
            context,
            isSaved ? 'Removed from your recipes.' : 'Saved to your recipes.',
          );
        } else {
          SnackBarHelper.showError(context, 'Could not change that. Try again.');
        }
      },
    );
  }

  Future<String?> _forkForEditing(Recipe recipe) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Make your own copy'),
        content: const Text(
          'This recipe belongs to someone else. Editing it will create your own copy, '
          'kept private until you choose otherwise. The original stays as it is.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Make a copy'),
          ),
        ],
      ),
    );
    if (proceed != true) return null;

    final id = await ref.read(firestoreServiceProvider).forkForEditing(recipe);
    if (!mounted) return null;
    if (id == null) {
      SnackBarHelper.showError(context, 'Could not copy that recipe.');
    }
    return id;
  }

  Future<void> _reportRecipe(Recipe recipe) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Report this recipe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('An admin will take a look. The author is not told who reported it.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLength: 300,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'What is wrong with it?',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text.trim()),
            child: const Text('Report'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty || recipe.firestoreId == null) return;

    final ok = await ref
        .read(firestoreServiceProvider)
        .reportRecipe(recipe.firestoreId!, reason);
    if (!mounted) return;
    if (ok) {
      SnackBarHelper.showSuccess(context, 'Reported. Thank you.');
    } else {
      SnackBarHelper.showError(context, 'Could not send that report.');
    }
  }

  Future<void> _loadRecipe() async {
    setState(() => _isLoading = true);
    final firestoreService = ref.read(firestoreServiceProvider);
    final recipe = await firestoreService.getRecipeById(widget.recipeId);
    if (mounted) {
      setState(() {
        _currentRecipe = recipe;
        _isLoading = false;
      });
    }
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
    final hasImage = recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar with image
          SliverAppBar(
            expandedHeight: hasImage ? 300 : 120,
            pinned: true,
            // Over a photo the bar sits on a dark scrim, so its contents have to
            // invert; without one it follows the theme like any other app bar.
            foregroundColor: hasImage ? AppSemanticColors.onScrim : null,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                recipe.title,
                style: hasImage
                    ? theme.textTheme.titleLarge?.copyWith(
                        color: AppSemanticColors.onScrim,
                        shadows: const [
                          Shadow(color: Color(0xCC000000), blurRadius: 8),
                        ],
                      )
                    : theme.textTheme.titleLarge,
              ),
              background: hasImage
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
                  color: recipe.isFavorite
                      ? Theme.of(context).colorScheme.secondary
                      : null,
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
              if (!_isMine(recipe)) _buildSaveButton(recipe),
              PopupMenuButton(
                icon: const Icon(Icons.more_vert),
                itemBuilder: (c) => [
                  if (!_isMine(recipe))
                    const PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.flag_outlined),
                          SizedBox(width: 8),
                          Text('Report'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
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
                        Icon(Icons.delete_outline,
                            color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 8),
                        Text('Delete',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      ],
                    ),
                  ),
                ],
                onSelected: (v) async {
                  if (v == 'report') {
                    await _reportRecipe(recipe);
                  } else if (v == 'edit') {
                    // Editing someone else's recipe makes a copy rather than changing
                    // theirs. The rules would refuse the write anyway; doing it silently
                    // would be worse than explaining it.
                    if (!_isMine(recipe)) {
                      // Router captured before the awaits, the same way the delete path
                      // below does it — a mounted check on the State does not tell the
                      // analyzer anything about this builder's context.
                      final router = GoRouter.of(context);
                      final forkedId = await _forkForEditing(recipe);
                      if (forkedId == null || !mounted) return;
                      final forked = await ref
                          .read(firestoreServiceProvider)
                          .getRecipeById(forkedId);
                      if (!mounted) return;
                      await router.push<bool>('/recipe/$forkedId/edit', extra: forked);
                      if (mounted) await _loadRecipe();
                      return;
                    }
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
                              backgroundColor:
                                  Theme.of(context).colorScheme.error,
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
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: AppTheme.maxContentWidth),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                              size: 16,
                              color: _difficultyAccent(recipe.difficulty),
                            ),
                            label: Text(_difficultyLabel(recipe.difficulty)),
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
                          style:
                              theme.textTheme.bodyLarge?.copyWith(height: 1.6),
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
                                padding:
                                    EdgeInsets.only(bottom: isLast ? 0 : 12),
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
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayTitle,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.bold),
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
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
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
                                              color:
                                                  theme.colorScheme.secondary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$timerMinutes minutes${step.timerLabel != null ? ' · ${step.timerLabel}' : ''}',
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                color:
                                                    theme.colorScheme.secondary,
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
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(
            '/recipe/${recipe.firestoreId ?? widget.recipeId}/cook',
            extra: recipe),
        icon: const Icon(Icons.restaurant_menu),
        label: const Text('Start Cooking'),
        heroTag: 'cook_button',
      ),
    );
  }

  /// A single muted accent per difficulty, drawn from the theme rather than
  /// traffic-light colours.
  Color _difficultyAccent(DifficultyLevel difficulty) {
    final status = context.statusColors;
    switch (difficulty) {
      case DifficultyLevel.easy:
        return status.success;
      case DifficultyLevel.medium:
        return status.warning;
      case DifficultyLevel.hard:
        return Theme.of(context).colorScheme.error;
    }
  }

  String _difficultyLabel(DifficultyLevel difficulty) {
    return difficulty.name[0].toUpperCase() + difficulty.name.substring(1);
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
