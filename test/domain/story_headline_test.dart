import 'package:flutter_test/flutter_test.dart';
import 'package:relay_gazette/domain/usecases/story_headline.dart';

void main() {
  test('empty content produces an empty headline and no body', () {
    final result = extractHeadline('   ');
    expect(result.headline, '');
    expect(result.body, isNull);
  });

  test(
    'a short note (under the threshold) becomes the headline with no body',
    () {
      final result = extractHeadline('gm nostr, off to touch some grass');
      expect(result.headline, 'gm nostr, off to touch some grass');
      expect(result.body, isNull);
    },
  );

  test('trims surrounding whitespace', () {
    final result = extractHeadline('  hello world  ');
    expect(result.headline, 'hello world');
  });

  test('a long note splits at the end of its first sentence', () {
    const content =
        'This is the opening sentence of a much longer note. '
        'It keeps going for a while after that, well past the short-note threshold, '
        'to make sure the split actually happens correctly here and the body is not empty.';
    expect(content.length, greaterThan(150));

    final result = extractHeadline(content);
    expect(
      result.headline,
      'This is the opening sentence of a much longer note.',
    );
    expect(result.body, startsWith('It keeps going'));
  });

  test('a long note splits at the first newline when that comes first', () {
    const content =
        'Short first line\nAnd then a much longer second paragraph that runs on '
        'well past the short-note threshold just to be sure this test is unambiguous.';
    expect(content.length, greaterThan(100));

    final result = extractHeadline(content);
    expect(result.headline, 'Short first line');
    expect(result.body, startsWith('And then'));
  });

  test(
    'never invents or summarizes text — body is exactly the remaining original text',
    () {
      const content =
          'First sentence goes here as the headline candidate for this test case. '
          'Second sentence follows immediately after that one, well past the threshold.';
      expect(content.length, greaterThan(100));

      final result = extractHeadline(content);
      expect(
        '${result.headline} ${result.body}'.replaceAll(RegExp(r'\s+'), ' '),
        content.replaceAll(RegExp(r'\s+'), ' '),
      );
    },
  );

  test('a long note with no natural break is hard-truncated with an ellipsis, '
      'while the body contains the remaining text', () {
    final content = 'a' * 300; // no punctuation, no newline anywhere
    final result = extractHeadline(content);
    expect(result.headline.endsWith('…'), isTrue);
    expect(result.headline.length, lessThan(content.length));
    expect(result.body, 'a' * 160); // nothing lost or duplicated
  });

  test('a note with no natural break shorter than the hard cap does not throw '
      '(regression: substring(0, 140) crashed on a 139-char note)', () {
    final content =
        'a' * 139; // over the 100-char threshold, under the 140-char cap
    final result = extractHeadline(content);
    expect(result.headline, '$content…');
    expect(result.body, isNull);
  });

  test('a note with no natural break keeps its opening out of the body', () {
    const content =
        'A very long unbroken note that deliberately has no sentence ending or newline so the title must be cut at the hard cap and the rest must remain only in the body for full-column reading';

    final result = extractHeadline(content);

    expect(result.headline, endsWith('…'));
    expect(result.body, isNot(contains(result.headline.replaceFirst('…', ''))));
    expect('${result.headline.replaceFirst('…', '')}${result.body}', content);
  });

  test(
    'a note whose only sentence break lands exactly at the end produces no body',
    () {
      const content =
          'This single long sentence runs on for quite a good while before it '
          'finally, at long last, comes to an end right here.';
      expect(content.length, greaterThan(100));
      expect(
        content.length,
        lessThanOrEqualTo(140),
      ); // within the search window

      final result = extractHeadline(content);
      expect(result.headline, content);
      expect(result.body, isNull);
    },
  );

  test(
    'question marks and exclamation points also count as sentence breaks',
    () {
      const content =
          'Did anyone else\'s Nostr client crash just now, out of nowhere? '
          'Mine did, right after the update rolled out earlier today.';
      expect(content.length, greaterThan(100));

      final result = extractHeadline(content);
      expect(
        result.headline,
        'Did anyone else\'s Nostr client crash just now, out of nowhere?',
      );
    },
  );
}
