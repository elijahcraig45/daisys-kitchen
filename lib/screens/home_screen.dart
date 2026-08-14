import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_keeper/models/recipe.dart';
import 'package:recipe_keeper/providers/firebase_providers.dart';
import 'package:recipe_keeper/providers/gemini_providers.dart';
import 'package:recipe_keeper/services/import_export_service.dart';
import 'package:recipe_keeper/theme/app_theme.dart';
import 'package:recipe_keeper/utils/app_constants.dart';
import 'package:recipe_keeper/utils/debouncer.dart';
import 'package:recipe_keeper/utils/snackbar_helper.dart';
import 'package:recipe_keeper/widgets/recipe_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final String? initialCategory;

  const HomeScreen({super.key, this.initialCategory});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  final _searchDebouncer = Debouncer();
  final _importExportService = ImportExportService();

  @override
  void initState() {
    super.initState();
    final initialCategory = widget.initialCategory;
    if (initialCategory != null) {
      // Provider state cannot be written while the widget is initialising.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(selectedCategoryProvider.notifier).state = initialCategory;
        }
      });
    }
  }

  @override
  void dispose() {
    _searchDebouncer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(recipesStreamProvider);
    final categories = ref.watch(categoriesProvider);
    final authService = ref.watch(authServiceProvider);
    final userAsync = ref.watch(currentUserProvider);
    final isAdmin = ref.watch(isAdminProvider).valueOrNull ?? false;
    final selectedDifficulty = ref.watch(selectedDifficultyProvider);
    final showFavoritesOnly = ref.watch(showFavoritesOnlyProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 900;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.restaurant_menu, size: 28),
            const SizedBox(width: 12),
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).appBarTheme.foregroundColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        actions: [
          if (showFavoritesOnly)
            Chip(
              avatar: Icon(Icons.favorite,
                  size: 16, color: Theme.of(context).colorScheme.secondary),
              label: const Text('Favorites'),
              onDeleted: () =>
                  ref.read(showFavoritesOnlyProvider.notifier).state = false,
              deleteIcon: const Icon(Icons.close, size: 18),
            ),
          const SizedBox(width: 8),
          // Auth UI
          userAsync.when(
            data: (user) {
              if (user == null) {
                return IconButton(
                  icon: const Icon(Icons.login),
                  tooltip: 'Sign In',
                  onPressed: () => _showSignInDialog(context, ref),
                );
              }
              // Get user data from the actual user object
              final displayName = user.displayName ?? user.email ?? 'User';
              final photoUrl = user.photoURL;

              return PopupMenuButton<String>(
                icon: CircleAvatar(
                  radius: 16,
                  backgroundImage:
                      photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? Text(displayName[0].toUpperCase())
                      : null,
                ),
                tooltip: displayName,
                onSelected: (value) async {
                  if (value == 'signout') {
                    await authService.signOut();
                    if (mounted) {
                      SnackBarHelper.showInfo(context, 'Signed out.');
                    }
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (isAdmin)
                          Text(
                            'Admin',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: context.statusColors.success),
                          ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'signout',
                    child: Row(
                      children: [
                        Icon(Icons.logout),
                        SizedBox(width: 8),
                        Text('Sign Out'),
                      ],
                    ),
                  ),
                ],
              );
            },
            loading: () => const SizedBox(width: 48),
            error: (_, __) => const SizedBox(width: 48),
          ),
          const SizedBox(width: 8),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.file_download),
                    SizedBox(width: 8),
                    Text('Import Recipes'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.file_upload),
                    SizedBox(width: 8),
                    Text('Export All'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'favorites',
                child: Row(
                  children: [
                    Icon(Icons.favorite),
                    SizedBox(width: 8),
                    Text('Show Favorites'),
                  ],
                ),
              ),
            ],
            onSelected: (value) async {
              if (value == 'import') {
                await _importRecipes();
              } else if (value == 'export') {
                await _exportAllRecipes();
              } else if (value == 'favorites') {
                ref.read(showFavoritesOnlyProvider.notifier).state = true;
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Sidebar for wide screens
          if (isWideScreen)
            Container(
              width: 280,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  right: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: _buildSidebar(categories),
            ),

          // Main content
          Expanded(
            child: Column(
              children: [
                // Search and filters
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                        maxWidth: AppTheme.maxContentWidth - 48),
                    child: Column(
                      children: [
                        // Search bar
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText:
                                'Search recipes by name, ingredients, or tags...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      _searchDebouncer.cancel();
                                      ref
                                          .read(searchQueryProvider.notifier)
                                          .state = '';
                                      setState(() {});
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (value) {
                            setState(() {});
                            _searchDebouncer(() {
                              if (!mounted) return;
                              ref.read(searchQueryProvider.notifier).state =
                                  value;
                            });
                          },
                        ),

                        // Filter chips (mobile)
                        if (!isWideScreen) ...[
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildDifficultyChip(DifficultyLevel.easy),
                                const SizedBox(width: 8),
                                _buildDifficultyChip(DifficultyLevel.medium),
                                const SizedBox(width: 8),
                                _buildDifficultyChip(DifficultyLevel.hard),
                                if (selectedDifficulty != null) ...[
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () => ref
                                        .read(
                                            selectedDifficultyProvider.notifier)
                                        .state = null,
                                    icon: const Icon(Icons.clear),
                                    label: const Text('Clear'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Recipe grid
                Expanded(
                  child: recipesAsync.when(
                    data: (_) {
                      final filteredRecipes =
                          ref.watch(firestoreFilteredRecipesProvider);

                      if (filteredRecipes.isEmpty) {
                        return _buildEmptyState();
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) => _buildRecipeGrid(
                          filteredRecipes,
                          constraints.maxWidth,
                        ),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              size: 40,
                              color: Theme.of(context).colorScheme.error),
                          const SizedBox(height: 16),
                          Text('Error: $error'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: userAsync.when(
        data: (user) => user != null
            ? FloatingActionButton.extended(
                onPressed: () => _showAddRecipeOptions(context),
                icon: const Icon(Icons.add),
                label: const Text('New Recipe'),
              )
            : null,
        loading: () => null,
        error: (_, __) => null,
      ),
    );
  }

  Widget _buildSidebar(List<String> categories) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Text(
            'Categories',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.all_inclusive),
          title: const Text('All Recipes'),
          selected: ref.watch(selectedCategoryProvider) == null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          onTap: () => ref.read(selectedCategoryProvider.notifier).state = null,
        ),
        const Divider(),
        ...categories.map((category) {
          return ListTile(
            leading: const Icon(Icons.category),
            title: Text(category),
            selected: ref.watch(selectedCategoryProvider) == category,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            onTap: () =>
                ref.read(selectedCategoryProvider.notifier).state = category,
          );
        }),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
          child: Text(
            'Difficulty',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        _buildDifficultyListTile(DifficultyLevel.easy),
        _buildDifficultyListTile(DifficultyLevel.medium),
        _buildDifficultyListTile(DifficultyLevel.hard),
      ],
    );
  }

  Widget _buildDifficultyListTile(DifficultyLevel level) {
    final icons = {
      DifficultyLevel.easy: Icons.sentiment_satisfied,
      DifficultyLevel.medium: Icons.sentiment_neutral,
      DifficultyLevel.hard: Icons.whatshot,
    };

    return ListTile(
      leading: Icon(icons[level]),
      title: Text(level.name[0].toUpperCase() + level.name.substring(1)),
      selected: ref.watch(selectedDifficultyProvider) == level,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      onTap: () {
        final notifier = ref.read(selectedDifficultyProvider.notifier);
        notifier.state = notifier.state == level ? null : level;
      },
    );
  }

  Widget _buildDifficultyChip(DifficultyLevel level) {
    final icons = {
      DifficultyLevel.easy: Icons.sentiment_satisfied,
      DifficultyLevel.medium: Icons.sentiment_neutral,
      DifficultyLevel.hard: Icons.whatshot,
    };

    return FilterChip(
      avatar: Icon(icons[level], size: 18),
      label: Text(level.name[0].toUpperCase() + level.name.substring(1)),
      selected: ref.watch(selectedDifficultyProvider) == level,
      onSelected: (selected) {
        ref.read(selectedDifficultyProvider.notifier).state =
            selected ? level : null;
      },
    );
  }

  Widget _buildRecipeGrid(List<Recipe> recipes, double availableWidth) {
    // Cap the measure so cards stay a comfortable reading width on large
    // displays instead of stretching into a four-across sprawl.
    final contentWidth = availableWidth > AppTheme.maxContentWidth
        ? AppTheme.maxContentWidth
        : availableWidth;

    int crossAxisCount = 1;
    if (contentWidth > 1000) {
      crossAxisCount = 3;
    } else if (contentWidth > 640) {
      crossAxisCount = 2;
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppTheme.maxContentWidth),
        child: GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.82,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
          ),
          itemCount: recipes.length,
          itemBuilder: (context, index) => _buildRecipeCard(recipes[index]),
        ),
      ),
    );
  }

  Widget _buildRecipeCard(Recipe recipe) {
    return RecipeCard(
      recipe: recipe,
      onTap: () => context.push(
        '/recipe/${recipe.firestoreId}',
        extra: recipe,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu,
            size: 44,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 20),
          Text(
            'No recipes found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to create a recipe, or import an existing collection.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _importRecipes() async {
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final recipes = await _importExportService.importRecipes();

      if (recipes.isEmpty) {
        return;
      }

      // Add each recipe to Firestore
      int successCount = 0;
      for (final recipe in recipes) {
        final id = await firestoreService.addRecipe(recipe);
        if (id != null) successCount++;
      }

      if (mounted) {
        SnackBarHelper.showSuccess(
            context, 'Imported $successCount of ${recipes.length} recipe(s).');
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Import failed: $e');
      }
    }
  }

  Future<void> _exportAllRecipes() async {
    try {
      final recipesAsync = ref.read(recipesStreamProvider);
      final recipes = recipesAsync.value ?? [];

      if (recipes.isEmpty) {
        if (mounted) {
          SnackBarHelper.showInfo(context, 'There are no recipes to export.');
        }
        return;
      }

      await _importExportService.exportAllRecipes(recipes);

      if (mounted) {
        SnackBarHelper.showSuccess(
            context, 'Exported ${recipes.length} recipe(s).');
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Export failed: $e');
      }
    }
  }

  void _showSignInDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign In'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sign in to add, edit, or manage recipes.'),
            SizedBox(height: 16),
            Text(
              'Public viewing does not require sign-in.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              final authService = ref.read(authServiceProvider);

              try {
                final result = await authService.signInWithGoogle();
                if (result != null && mounted) {
                  final user = result.user;
                  SnackBarHelper.showSuccess(context,
                      'Welcome, ${user?.displayName ?? user?.email ?? 'friend'}.');
                } else if (mounted) {
                  SnackBarHelper.showWarning(context, 'Sign-in was cancelled.');
                }
              } catch (e) {
                if (mounted) {
                  SnackBarHelper.showError(context, 'Sign-in failed: $e');
                }
              }
            },
            icon: const Icon(Icons.login),
            label: const Text('Sign in with Google'),
          ),
        ],
      ),
    );
  }

  /// Show options for adding a recipe
  void _showAddRecipeOptions(BuildContext context) {
    final isGeminiEnabled =
        ref.read(isGeminiEnabledProvider).valueOrNull ?? false;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.add_circle_outline, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Add New Recipe',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Step-by-step editor
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_note),
                ),
                title: const Text('Step-by-Step Editor'),
                subtitle:
                    const Text('Create recipe manually with full control'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/recipe/new');
                },
              ),

              const SizedBox(height: 12),

              // Quick paste with AI
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isGeminiEnabled
                        ? Theme.of(context).colorScheme.tertiaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    size: 20,
                    color: isGeminiEnabled
                        ? Theme.of(context).colorScheme.onTertiaryContainer
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
                title: Row(
                  children: [
                    const Text('Quick Paste Import'),
                    if (isGeminiEnabled) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.verified,
                          size: 16, color: context.statusColors.success),
                    ],
                  ],
                ),
                subtitle: Text(
                  isGeminiEnabled
                      ? 'Paste a whole recipe and let AI structure it'
                      : 'Requires a Gemini API key in Remote Config',
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                enabled: isGeminiEnabled,
                onTap: isGeminiEnabled
                    ? () {
                        Navigator.pop(context);
                        _showQuickPasteImport(context);
                      }
                    : null,
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// Show quick paste import dialog
  Future<void> _showQuickPasteImport(BuildContext context) async {
    final controller = TextEditingController();
    bool isProcessing = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.tertiary, size: 22),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Quick Paste Import'),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste your entire recipe below — ingredients, steps, servings, everything. '
                  'The AI will structure it into a proper recipe with both customary and metric units.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Paste Recipe Here',
                    hintText:
                        'Title: Chocolate Chip Cookies\n\nIngredients:\n- 2 cups flour\n- 1 cup sugar\n...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 12,
                  enabled: !isProcessing,
                  autofocus: true,
                ),
                if (isProcessing) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text(
                    'Extracting your recipe...',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  isProcessing ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: isProcessing || controller.text.trim().isEmpty
                  ? null
                  : () async {
                      final text = controller.text.trim();
                      setDialogState(() => isProcessing = true);

                      try {
                        // Extract recipe using Gemini
                        final recipe = await ref.read(
                          extractRecipeFromTextProvider(text).future,
                        );

                        if (!context.mounted) return;

                        if (recipe == null) {
                          Navigator.pop(dialogContext);
                          SnackBarHelper.showWarning(context,
                              'Could not extract a recipe. Try again with more detail.');
                          return;
                        }

                        // Save the recipe
                        final firestoreService =
                            ref.read(firestoreServiceProvider);
                        final authService = ref.read(authServiceProvider);
                        final user = authService.currentUser;

                        if (user != null) {
                          await firestoreService.addRecipe(recipe);
                        }

                        Navigator.pop(dialogContext);

                        if (!context.mounted) return;

                        SnackBarHelper.showSuccess(context,
                            'Added "${recipe.title}" to your collection.');
                      } catch (e) {
                        if (!context.mounted) return;
                        Navigator.pop(dialogContext);
                        SnackBarHelper.showError(context, 'Import failed: $e');
                      }
                    },
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Import Recipe'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
  }
}
