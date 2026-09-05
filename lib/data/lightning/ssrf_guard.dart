import 'dart:io';

/// The zap flow builds HTTP requests to a domain taken straight from a
/// Nostr author's profile (`lud16`) — content anyone can put anything in.
/// Without this check, a crafted Lightning address (e.g.
/// `x@169.254.169.254` or `x@my-router.local`) would make the reader's own
/// device issue an HTTP request to their local network or loopback
/// interface on the author's behalf: a classic client-side SSRF.
///
/// This blocks the obvious cases — literal private/loopback/link-local IPs
/// and well-known non-routable hostname suffixes. It does **not** defend
/// against DNS rebinding (a public hostname whose DNS record points at a
/// private IP at request time): doing that would require resolving DNS and
/// pinning the connection to the resolved address ourselves, which
/// `package:http`'s high-level client doesn't expose a way to do. Documented
/// as a known residual risk rather than silently unhandled — see
/// ARCHITECTURE.md.
bool isPubliclyRoutable(String host) {
  final trimmed = host.trim().toLowerCase();
  if (trimmed.isEmpty) return false;

  if (trimmed == 'localhost' || trimmed.endsWith('.localhost')) return false;
  for (final suffix in const [
    '.local',
    '.internal',
    '.test',
    '.invalid',
    '.example',
  ]) {
    if (trimmed.endsWith(suffix)) return false;
  }

  final address = InternetAddress.tryParse(trimmed);
  if (address == null) return true; // a symbolic hostname, not a literal IP

  if (address.isLoopback || address.isLinkLocal || address.isMulticast)
    return false;

  if (address.type == InternetAddressType.IPv4) {
    final b = address.rawAddress;
    // RFC 1918 private ranges.
    if (b[0] == 10) return false;
    if (b[0] == 172 && b[1] >= 16 && b[1] <= 31) return false;
    if (b[0] == 192 && b[1] == 168) return false;
    // RFC 6598 carrier-grade NAT (100.64.0.0/10).
    if (b[0] == 100 && b[1] >= 64 && b[1] <= 127) return false;
    // Cloud metadata endpoint (AWS/GCP/Azure all use 169.254.169.254, also
    // covered by isLinkLocal above, kept explicit for clarity).
    if (b[0] == 169 && b[1] == 254) return false;
  } else {
    // Unique local addresses, fc00::/7.
    if (address.rawAddress[0] & 0xfe == 0xfc) return false;
  }

  return true;
}

bool isSafeExternalRequestUri(Uri uri) {
  if (uri.scheme != 'https') return false;
  return isPubliclyRoutable(uri.host);
}
