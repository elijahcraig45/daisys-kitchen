import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/firebase_providers.dart';
import '../services/household_service.dart';
import '../theme/app_theme.dart';
import '../utils/snackbar_helper.dart';

/// Create a household, invite someone to it, or leave it.
///
/// Deliberately one screen with two states — in a household, or not — rather than a flow.
/// There is very little to configure, and a wizard for "type a name" would be more
/// ceremony than the feature deserves.
class HouseholdScreen extends ConsumerStatefulWidget {
  const HouseholdScreen({super.key});

  @override
  ConsumerState<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends ConsumerState<HouseholdScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  bool _busy = false;
  String? _inviteCode;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  HouseholdService get _service => ref.read(householdServiceProvider);

  /// Every call goes through here so the buttons cannot be pressed twice, and so a
  /// refusal from the server is shown as written rather than translated.
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on HouseholdException catch (e) {
      if (mounted) SnackBarHelper.showError(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final householdAsync = ref.watch(myHouseholdProvider);
    final signedIn = ref.watch(currentUserProvider).valueOrNull != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Household')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (!signedIn)
                _buildSignInPrompt()
              else
                householdAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) =>
                      const _Explainer('Could not load your household.'),
                  data: (household) => household == null
                      ? _buildNoHousehold()
                      : _buildHousehold(household),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignInPrompt() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Explainer('Share recipes and one grocery list.'),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _signIn,
          icon: const Icon(Icons.login),
          label: const Text('Sign in with Google'),
        ),
      ],
    );
  }

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      final result = await ref.read(authServiceProvider).signInWithGoogle();
      if (!mounted) return;
      if (result == null) SnackBarHelper.showWarning(context, 'Sign-in was cancelled.');
    } catch (e) {
      if (mounted) SnackBarHelper.showError(context, 'Sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildNoHousehold() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Explainer(
          'Share recipes and one grocery list. You can be in one at a time.',
        ),
        const SizedBox(height: 24),
        Text('Start one', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          maxLength: 100,
          decoration: const InputDecoration(
            labelText: 'What should we call it?',
            hintText: 'Our Kitchen',
          ),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : () => _run(() async {
                    await _service.create(_nameController.text.trim());
                    if (mounted) {
                      SnackBarHelper.showSuccess(context, 'Household created.');
                    }
                  }),
          child: const Text('Create household'),
        ),
        const SizedBox(height: 32),
        Text('Or join one', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _codeController,
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Invite code',
            hintText: 'ABC123',
          ),
        ),
        FilledButton.tonal(
          onPressed: _busy
              ? null
              : () => _run(() async {
                    final name = await _service.join(_codeController.text);
                    if (mounted && name != null) {
                      SnackBarHelper.showSuccess(context, 'Joined $name.');
                    }
                  }),
          child: const Text('Join'),
        ),
      ],
    );
  }

  Widget _buildHousehold(Household household) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(household.name, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        FutureBuilder<Map<String, String>>(
          future: _service.memberNames(household),
          builder: (context, snap) {
            final names = snap.data ?? const {};
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: household.memberUids
                  .map((uid) => ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(names[uid] ?? 'Someone'),
                        subtitle: uid == household.createdBy
                            ? const Text('Started this household')
                            : null,
                      ))
                  .toList(),
            );
          },
        ),
        const Divider(height: 32),
        Text('Invite someone', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const _Explainer('Codes last two weeks. A new one replaces the old.'),
        const SizedBox(height: 12),
        if (_inviteCode != null) ...[
          Card(
            child: ListTile(
              title: SelectableText(
                _inviteCode!,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      letterSpacing: 6,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copy',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _inviteCode!));
                  SnackBarHelper.showSuccess(context, 'Code copied.');
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        FilledButton.tonal(
          onPressed: _busy
              ? null
              : () => _run(() async {
                    final code = await _service.createInvite();
                    if (mounted) setState(() => _inviteCode = code);
                  }),
          child: Text(_inviteCode == null ? 'Create an invite code' : 'Make a new code'),
        ),
        const Divider(height: 32),
        TextButton(
          onPressed: _busy ? null : _confirmLeave,
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Leave this household'),
        ),
      ],
    );
  }

  Future<void> _confirmLeave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Leave this household?'),
        // Says what happens to the recipes, because that is the question anyone would
        // have and the answer is reassuring: nothing is deleted.
        content: const Text(
          'You will stop seeing recipes shared with the household, and its grocery '
          'list. Nothing is deleted — recipes stay with whoever wrote them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _run(() async {
      await _service.leave();
      if (mounted) {
        setState(() => _inviteCode = null);
        SnackBarHelper.showInfo(context, 'You have left the household.');
      }
    });
  }
}

class _Explainer extends StatelessWidget {
  const _Explainer(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
    );
  }
}
