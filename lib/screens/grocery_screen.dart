import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/firebase_providers.dart';
import '../services/grocery_service.dart';
import '../theme/app_theme.dart';
import '../utils/snackbar_helper.dart';

/// The household's grocery list, grouped by store section.
class GroceryScreen extends ConsumerStatefulWidget {
  const GroceryScreen({super.key});

  @override
  ConsumerState<GroceryScreen> createState() => _GroceryScreenState();
}

class _GroceryScreenState extends ConsumerState<GroceryScreen> {
  final _addController = TextEditingController();

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final household = ref.watch(myHouseholdProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Groceries'),
        actions: [
          if (household != null)
            IconButton(
              icon: const Icon(Icons.cleaning_services_outlined),
              tooltip: 'Clear what is done',
              onPressed: () async {
                // Messenger captured up front: a mounted check on the State says nothing
                // to the analyzer about this closure's context.
                final messenger = ScaffoldMessenger.of(context);
                final cleared =
                    await ref.read(groceryServiceProvider).clearDone(household.id);
                messenger.showSnackBar(SnackBar(
                  content: Text(cleared == 0
                      ? 'Nothing to clear.'
                      : 'Cleared $cleared item(s).'),
                ));
              },
            ),
        ],
      ),
      body: household == null ? _buildNoHousehold() : _buildList(household.id),
    );
  }

  Widget _buildNoHousehold() {
    // A list is a household thing, so this explains rather than showing an empty page.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shopping_basket_outlined, size: 48),
              const SizedBox(height: 16),
              Text(
                'The list belongs to a household',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Set one up and everyone in it shares the same list, so whoever passes the '
                'shop can pick things up.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pushNamed('/household'),
                child: const Text('Set up a household'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(String householdId) {
    final itemsAsync = ref.watch(groceryItemsProvider(householdId));

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _addController,
                decoration: InputDecoration(
                  labelText: 'Add something',
                  hintText: '2 lemons',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _add(householdId),
                  ),
                ),
                onSubmitted: (_) => _add(householdId),
              ),
            ),
            Expanded(
              child: itemsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(
                  child: Text('Could not load the list. Check your connection.'),
                ),
                data: (items) =>
                    items.isEmpty ? _buildEmpty() : _buildGrouped(householdId, items),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Nothing on the list. Add something above, or open a recipe and send its '
          'ingredients here.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
        ),
      ),
    );
  }

  Widget _buildGrouped(String householdId, List<GroceryItem> items) {
    // Already sorted by the service into store order with finished items last; this only
    // inserts a heading when the section changes.
    final rows = <Widget>[];
    String? currentAisle;
    var doneHeaderShown = false;

    for (final item in items) {
      if (item.done && !doneHeaderShown) {
        rows.add(_heading('In the basket'));
        doneHeaderShown = true;
        currentAisle = null;
      }
      if (!item.done && item.aisle != currentAisle) {
        currentAisle = item.aisle;
        rows.add(_heading(_aisleLabel(item.aisle)));
      }
      rows.add(_buildRow(householdId, item));
    }

    return ListView(padding: const EdgeInsets.only(bottom: 24), children: rows);
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.colors.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
        ),
      );

  Widget _buildRow(String householdId, GroceryItem item) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Theme.of(context).colorScheme.errorContainer,
        child: const Icon(Icons.delete_outline),
      ),
      onDismissed: (_) async {
        await ref.read(groceryServiceProvider).remove(householdId, item);
        if (mounted) SnackBarHelper.showInfo(context, 'Removed ${item.display}.');
      },
      child: CheckboxListTile(
        value: item.done,
        onChanged: (value) => ref
            .read(groceryServiceProvider)
            .setDone(householdId, item, value ?? false),
        title: Text(
          item.display,
          style: item.done
              ? TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: context.colors.onSurfaceVariant,
                )
              : null,
        ),
        subtitle: _buildSubtitle(item),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget? _buildSubtitle(GroceryItem item) {
    final parts = [
      if (item.quantityLabel.isNotEmpty) item.quantityLabel,
      // Where it came from, so a merged line can be traced back rather than being a
      // number you have to trust.
      if (item.sourceTitles.isNotEmpty) 'for ${item.sourceTitles.join(', ')}',
    ];
    return parts.isEmpty ? null : Text(parts.join(' · '));
  }

  String _aisleLabel(String aisle) => switch (aisle) {
        'produce' => 'Produce',
        'bakery' => 'Bakery',
        'meat' => 'Meat',
        'seafood' => 'Seafood',
        'dairy' => 'Dairy and eggs',
        'frozen' => 'Frozen',
        'pantry' => 'Pantry',
        'spices' => 'Herbs and spices',
        'drinks' => 'Drinks',
        'household' => 'Household',
        _ => 'Anything else',
      };

  Future<void> _add(String householdId) async {
    final text = _addController.text.trim();
    if (text.isEmpty) return;
    final ok = await ref.read(groceryServiceProvider).addManual(householdId, text);
    if (!mounted) return;
    if (ok) {
      _addController.clear();
    } else {
      SnackBarHelper.showError(context, 'Could not add that.');
    }
  }
}
