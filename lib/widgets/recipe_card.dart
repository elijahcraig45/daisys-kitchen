import 'package:flutter/material.dart';
import 'package:recipe_keeper/models/recipe.dart';

/// Grid tile for a single recipe.
///
/// Metadata is rendered as a quiet single-accent row rather than a run of
/// coloured chips, so a wall of cards reads as one calm surface.
class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.recipe,
    required this.onTap,
  });

  final Recipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Image(recipe: recipe),
                  if (recipe.isFavorite)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _Badge(
                        child: Icon(
                          Icons.favorite,
                          size: 14,
                          color: colors.secondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (recipe.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        recipe.description,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const Spacer(),
                    _MetaRow(recipe: recipe),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Image extends StatelessWidget {
  const _Image({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final url = recipe.imageUrl;
    if (url == null || url.isEmpty) {
      return const _ImagePlaceholder();
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const _ImagePlaceholder(),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      color: colors.surfaceContainerHigh,
      child: Center(
        child: Icon(
          Icons.restaurant_menu,
          size: 36,
          color: colors.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        shape: BoxShape.circle,
        border: Border.all(color: colors.outlineVariant),
      ),
      child: child,
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final parts = <String>[
      if (recipe.totalTimeMinutes > 0) _formatMinutes(recipe.totalTimeMinutes),
      if (recipe.servings > 0)
        '${recipe.servings} serving${recipe.servings == 1 ? '' : 's'}',
      _difficultyLabel(recipe.difficulty),
    ];

    return Row(
      children: [
        Icon(Icons.schedule, size: 14, color: colors.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            parts.join('  ·  '),
            style: theme.textTheme.labelMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  static String _formatMinutes(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours hr' : '$hours hr $rest min';
  }

  static String _difficultyLabel(DifficultyLevel level) {
    return level.name[0].toUpperCase() + level.name.substring(1);
  }
}
