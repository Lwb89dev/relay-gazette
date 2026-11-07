import 'package:flutter/material.dart';

import '../theme/aged_paper_surface.dart';
import '../theme/gazette_colors.dart';
import 'edition_sources_page.dart';
import 'interactions_page.dart';
import 'sign_in_step.dart';

/// The 3-page onboarding shown the first time the app runs, before any
/// reader identity is saved: what an edition is (page 1), what you can do
/// with a story (page 2), then sign in (page 3). Pages 1-2 are swipeable
/// or advanced with "Next"; page 3 owns its own progression (Continue,
/// Amber, or bunker), so no "Next" is shown there.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _controller = PageController();
  int _page = 0;

  static const _pageCount = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.gazetteColors;
    return Scaffold(
      body: AgedPaperSurface(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (page) => setState(() => _page = page),
                children: const [
                  EditionSourcesPage(),
                  InteractionsPage(),
                  SignInStep(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pageCount; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 22 : 8,
                      height: 4,
                      decoration: BoxDecoration(
                        color: i == _page ? colors.accent : colors.rule,
                      ),
                    ),
                ],
              ),
            ),
            if (_page < _pageCount - 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: TextButton(onPressed: _next, child: const Text('Next')),
              ),
          ],
        ),
      ),
    );
  }
}
