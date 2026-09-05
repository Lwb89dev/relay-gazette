import 'package:flutter_test/flutter_test.dart';
import 'package:relay_gazette/data/lightning/ssrf_guard.dart';

void main() {
  group('isPubliclyRoutable', () {
    test('accepts ordinary public IPv4 addresses', () {
      expect(isPubliclyRoutable('8.8.8.8'), isTrue);
      expect(isPubliclyRoutable('1.1.1.1'), isTrue);
    });

    test('accepts an ordinary public hostname', () {
      expect(isPubliclyRoutable('example.com'), isTrue);
      expect(isPubliclyRoutable('getalby.com'), isTrue);
    });

    test('rejects loopback addresses', () {
      expect(isPubliclyRoutable('127.0.0.1'), isFalse);
      expect(isPubliclyRoutable('::1'), isFalse);
    });

    test('rejects "localhost" and its subdomains', () {
      expect(isPubliclyRoutable('localhost'), isFalse);
      expect(isPubliclyRoutable('sub.localhost'), isFalse);
    });

    test('rejects RFC 1918 private IPv4 ranges', () {
      expect(isPubliclyRoutable('10.0.0.1'), isFalse);
      expect(isPubliclyRoutable('172.16.0.1'), isFalse);
      expect(isPubliclyRoutable('172.31.255.255'), isFalse);
      expect(isPubliclyRoutable('192.168.1.1'), isFalse);
    });

    test('does not reject a public address that merely looks close to a private range', () {
      // 172.15.x and 172.32.x are outside the 172.16.0.0/12 private block.
      expect(isPubliclyRoutable('172.15.0.1'), isTrue);
      expect(isPubliclyRoutable('172.32.0.1'), isTrue);
    });

    test('rejects the cloud metadata / link-local address', () {
      expect(isPubliclyRoutable('169.254.169.254'), isFalse);
    });

    test('rejects RFC 6598 carrier-grade NAT range', () {
      expect(isPubliclyRoutable('100.64.0.1'), isFalse);
    });

    test('rejects common non-routable hostname suffixes', () {
      expect(isPubliclyRoutable('router.local'), isFalse);
      expect(isPubliclyRoutable('service.internal'), isFalse);
      expect(isPubliclyRoutable('name.test'), isFalse);
    });

    test('rejects an empty host', () {
      expect(isPubliclyRoutable(''), isFalse);
      expect(isPubliclyRoutable('   '), isFalse);
    });

    test('rejects IPv6 unique local addresses', () {
      expect(isPubliclyRoutable('fc00::1'), isFalse);
      expect(isPubliclyRoutable('fd12:3456:789a::1'), isFalse);
    });
  });

  group('isSafeExternalRequestUri', () {
    test('accepts an https URI to a public host', () {
      expect(isSafeExternalRequestUri(Uri.parse('https://example.com/.well-known/lnurlp/alice')), isTrue);
    });

    test('rejects plain http, even to a public host', () {
      expect(isSafeExternalRequestUri(Uri.parse('http://example.com/cb')), isFalse);
    });

    test('rejects an https URI whose host is a private IP', () {
      expect(isSafeExternalRequestUri(Uri.parse('https://192.168.1.1/cb')), isFalse);
    });

    test('rejects an https URI targeting a non-standard port on a private/loopback host', () {
      expect(isSafeExternalRequestUri(Uri.parse('https://127.0.0.1:8443/cb')), isFalse);
    });
  });
}
