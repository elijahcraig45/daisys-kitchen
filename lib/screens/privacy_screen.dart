import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/app_constants.dart';

/// Privacy and terms.
///
/// An in-app route rather than a static file: `firebase.json` rewrites every path to the
/// Flutter app, and `build/web` is regenerated on each build, so a hand-placed HTML file
/// would be overwritten.
///
/// Written from what the code actually does — the fields in `_updateUserProfile`, the
/// visibility rules, and which accounts can reach Gemini — rather than from a template.
/// A privacy policy that describes a different app is worse than none, because it is a
/// claim rather than an omission.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy and terms')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppTheme.maxContentWidth),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: const [
              _Section('The short version', [
                'You can browse ${AppConstants.appName} without an account. Signing in lets '
                    'you keep your own recipes, share some with a household, and publish '
                    'some to everyone.',
                'Your email address is never shown to other people. Recipes are attributed '
                    'by display name only.',
                'Nothing here is advertised, sold, or shared with anyone beyond the '
                    'services listed below.',
              ]),
              _Section('What is stored when you sign in', [
                'From your Google account: your email address, display name and profile '
                    'photo URL, plus the time you last signed in. The email is used to '
                    'identify your account and is not visible to other users.',
                'Whether you are an administrator, and whether AI features are enabled for '
                    'your account. Neither can be set by you.',
                'Which household you belong to, if any.',
              ]),
              _Section('What is stored when you use it', [
                'Recipes you write, including their ingredients, steps, notes and any image '
                    'link you provide.',
                'Which recipes you have favourited and which you have saved from the '
                    'community. Both are private to you.',
                'Grocery list items for your household, and a record of what has been '
                    'ticked off, so the list can suggest things you buy regularly.',
                'Reports you file about a recipe, including who filed them. Reports are '
                    'visible only to administrators — an author is never told who reported '
                    'their recipe.',
              ]),
              _Section('Who can see your recipes', [
                'Every recipe is private, shared with your household, or published to the '
                    'community, and you choose which. New recipes start private.',
                'Private means only you. Household means the people in your household. '
                    'Published means anyone, including people who are not signed in.',
                'Changing a recipe back to private removes it from the community, but '
                    'anyone who already saved a copy of their own keeps that copy.',
              ]),
              _Section('Other services involved', [
                'Google Firebase hosts the site, handles sign-in, and stores the data '
                    'above. It is subject to Google’s privacy policy.',
                'Google Gemini is used to help import a recipe from a link or pasted text. '
                    'The text being imported is sent to Google for that purpose. This is '
                    'limited to specific accounts and is off for everyone else.',
                'When you import from a link, the page at that link is fetched by this '
                    'app’s own server so the browser does not have to. Only the page '
                    'content is used.',
                'There is no analytics, no advertising, and no third-party tracking.',
              ]),
              _Section('Deleting your data', [
                'There is no self-serve delete yet. You can delete individual recipes at '
                    'any time, and leave a household at any time.',
                'To remove your account and everything attached to it, ask the '
                    'administrator and it will be done by hand. This is stated plainly '
                    'because a promise of a button that does not exist would be worse than '
                    'an inconvenient truth.',
              ]),
              _Section('Using the community library', [
                'Publish only recipes you are happy for anyone to read and reuse. You keep '
                    'whatever rights you had in what you wrote; publishing lets other '
                    'people read it, save it, and make their own copy.',
                'Do not publish anything abusive, misleading about food safety, or that is '
                    'not yours to share. Anything published can be reported, and an '
                    'administrator can unpublish or remove it.',
                'This is a small, hand-run site rather than a moderated platform. Reports '
                    'are read by a person, not a queue, so a response may take a while.',
              ]),
              _Section('Changes', [
                'If what is collected or who can see it changes, this page changes with it. '
                    'It is written from the code rather than kept alongside it.',
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.paragraphs);

  final String title;
  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          ...paragraphs.map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                      height: 1.5,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
