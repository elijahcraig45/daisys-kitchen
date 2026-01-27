import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_keeper/models/recipe.dart';
import 'package:recipe_keeper/providers/firebase_providers.dart';
import 'package:recipe_keeper/providers/gemini_providers.dart';
import 'package:recipe_keeper/services/import_export_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final String? initialCategory;
  
  const HomeScreen({super.key, this.initialCategory});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  final _importExportService = ImportExportService();
  String? _selectedCategory;
  DifficultyLevel? _selectedDifficulty;
  bool _showFavoritesOnly = false;
  
  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(recipesStreamProvider);
    final categories = ref.watch(categoriesProvider);
    final authService = ref.watch(authServiceProvider);
    final userAsync = ref.watch(currentUserProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 900;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.restaurant_menu, size: 28),
            const SizedBox(width: 12),
            const Text(
              'Recipe Keeper',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          if (_showFavoritesOnly)
            Chip(
              avatar: const Icon(Icons.favorite, size: 18, color: Colors.red),
              label: const Text('Favorites'),
              onDeleted: () => setState(() => _showFavoritesOnly = false),
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
                  backgroundImage: photoUrl != null
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl == null
                      ? Text(displayName[0].toUpperCase())
                      : null,
                ),
                tooltip: displayName,
                onSelected: (value) async {
                  if (value == 'signout') {
                    await authService.signOut();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Signed out successfully')),
                      );
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
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (isAdmin)
                          const Text(
                            'Admin',
                            style: TextStyle(color: Colors.green, fontSize: 12),
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
                setState(() => _showFavoritesOnly = true);
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
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Search bar
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search recipes by name, ingredients, or tags...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref.read(searchQueryProvider.notifier).state = '';
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) {
                          ref.read(searchQueryProvider.notifier).state = value;
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
                              if (_selectedDifficulty != null) ...[
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: () => setState(() => _selectedDifficulty = null),
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
                
                // Recipe grid
                Expanded(
                  child: recipesAsync.when(
                    data: (recipes) {
                      var filteredRecipes = recipes;
                      
                      // Apply category filter
                      if (_selectedCategory != null) {
                        filteredRecipes = filteredRecipes
                            .where((r) => r.category?.toLowerCase() == _selectedCategory!.toLowerCase())
                            .toList();
                      }
                      
                      // Apply difficulty filter
                      if (_selectedDifficulty != null) {
                        filteredRecipes = filteredRecipes
                            .where((r) => r.difficulty == _selectedDifficulty)
                            .toList();
                      }
                      
                      // Apply favorites filter
                      if (_showFavoritesOnly) {
                        filteredRecipes = filteredRecipes.where((r) => r.isFavorite).toList();
                      }
                      
                      if (filteredRecipes.isEmpty) {
                        return _buildEmptyState();
                      }
                      
                      return _buildRecipeGrid(filteredRecipes, screenWidth);
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 64, color: Colors.red),
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
        const Text(
          'Categories',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.all_inclusive),
          title: const Text('All Recipes'),
          selected: _selectedCategory == null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          onTap: () => setState(() => _selectedCategory = null),
        ),
        const Divider(),
        ...categories.map((category) {
          return ListTile(
            leading: const Icon(Icons.category),
            title: Text(category),
            selected: _selectedCategory == category,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            onTap: () => setState(() => _selectedCategory = category),
          );
        }),
        const Divider(),
        const Text(
          'Difficulty',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
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
      selected: _selectedDifficulty == level,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      onTap: () => setState(() {
        _selectedDifficulty = _selectedDifficulty == level ? null : level;
      }),
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
      selected: _selectedDifficulty == level,
      onSelected: (selected) {
        setState(() {
          _selectedDifficulty = selected ? level : null;
        });
      },
    );
  }
  
  Widget _buildRecipeGrid(List<Recipe> recipes, double screenWidth) {
    int crossAxisCount = 1;
    if (screenWidth > 1400) {
      crossAxisCount = 4;
    } else if (screenWidth > 1000) {
      crossAxisCount = 3;
    } else if (screenWidth > 600) {
      crossAxisCount = 2;
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return _buildRecipeCard(recipe);
      },
    );
  }
  
  Widget _buildRecipeCard(Recipe recipe) {
    final hasImage = recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty;
    
    return Card(
      child: InkWell(
        onTap: () => context.push('/recipe/${recipe.firestoreId ?? recipe.id}', extra: recipe),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image or placeholder
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasImage)
                    Image.network(
                      recipe.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildImagePlaceholder(recipe);
                      },
                    )
                  else
                    _buildImagePlaceholder(recipe),
                  
                  // Favorite badge
                  if (recipe.isFavorite)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  
                  // Difficulty badge
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getDifficultyColor(recipe.difficulty),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        recipe.difficulty.name.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Recipe details
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (recipe.description.isNotEmpty)
                      Text(
                        recipe.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const Spacer(),
                    Row(
                      children: [
                        if (recipe.prepTimeMinutes != null) ...[
                          const Icon(Icons.access_time, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${recipe.prepTimeMinutes}m',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                        if (recipe.cookTimeMinutes != null) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.local_fire_department, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${recipe.cookTimeMinutes}m',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                        const Spacer(),
                        Icon(
                          Icons.people,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.servings}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildImagePlaceholder(Recipe recipe) {
    final colors = [
      Colors.blue[100]!,
      Colors.green[100]!,
      Colors.orange[100]!,
      Colors.purple[100]!,
      Colors.red[100]!,
    ];
    
    return Container(
      color: colors[recipe.id % colors.length],
      child: const Center(
        child: Icon(
          Icons.restaurant,
          size: 64,
          color: Colors.white70,
        ),
      ),
    );
  }
  
  Color _getDifficultyColor(DifficultyLevel level) {
    switch (level) {
      case DifficultyLevel.easy:
        return Colors.green;
      case DifficultyLevel.medium:
        return Colors.orange;
      case DifficultyLevel.hard:
        return Colors.red;
    }
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No recipes found',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to create recipes or import existing ones',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported $successCount of ${recipes.length} recipe(s)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportAllRecipes() async {
    try {
      final recipesAsync = ref.read(recipesStreamProvider);
      final recipes = recipesAsync.value ?? [];
      
      if (recipes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No recipes to export')),
          );
        }
        return;
      }

      await _importExportService.exportAllRecipes(recipes);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${recipes.length} recipe(s)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Welcome, ${user?.displayName ?? user?.email ?? 'User'}!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sign-in was cancelled'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sign-in failed: ${e.toString()}'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                    ),
                  );
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
    final isGeminiEnabled = ref.read(isGeminiEnabledProvider);
    
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
                subtitle: const Text('Create recipe manually with full control'),
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
                      ? Colors.amber.shade100
                      : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: isGeminiEnabled ? Colors.amber.shade700 : Colors.grey,
                  ),
                ),
                title: Row(
                  children: [
                    const Text('Quick Paste Import'),
                    if (isGeminiEnabled) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.verified, size: 16, color: Colors.green),
                    ],
                  ],
                ),
                subtitle: Text(
                  isGeminiEnabled
                    ? '🏴‍☠️ Paste entire recipe - AI structures it for ye'
                    : 'Requires Gemini API key in gemini_config.dart',
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
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.amber, size: 28),
              SizedBox(width: 12),
              Expanded(
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
                  '🏴‍☠️ Paste yer entire recipe below - ingredients, steps, servings, everything! '
                  'The AI will structure it into a proper recipe with both customary and metric units.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Paste Recipe Here',
                    hintText: 'Title: Chocolate Chip Cookies\n\nIngredients:\n- 2 cups flour\n- 1 cup sugar\n...',
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
                    '🏴‍☠️ The AI be workin\' its magic...',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isProcessing ? null : () => Navigator.pop(dialogContext),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🏴‍☠️ Could not extract recipe. Try again with more details.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      
                      // Save the recipe
                      final firestoreService = ref.read(firestoreServiceProvider);
                      final authService = ref.read(authServiceProvider);
                      final user = authService.currentUser;
                      
                      if (user != null) {
                        await firestoreService.addRecipe(recipe);
                      }
                      
                      Navigator.pop(dialogContext);
                      
                      if (!context.mounted) return;
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('🏴‍☠️ Recipe "${recipe.title}" added to yer collection!'),
                          backgroundColor: Colors.green,
                          action: SnackBarAction(
                            label: 'View',
                            textColor: Colors.white,
                            onPressed: () {
                              // Navigate to recipe detail if it has an ID
                              if (recipe.firestoreId != null) {
                                context.push('/recipe/${recipe.firestoreId}');
                              }
                            },
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('🏴‍☠️ Import failed: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
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
