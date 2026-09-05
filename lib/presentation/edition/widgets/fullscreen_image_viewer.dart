import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A tap-to-open full-screen viewer for a story's image(s): pinch-to-zoom
/// (`InteractiveViewer`) per image, swipe between images when there's more
/// than one, and an explicit "Close" button (a bare tap-anywhere-to-dismiss
/// gesture is offered too, but isn't the only affordance — a plain tap can
/// end up contested by `InteractiveViewer`'s own gesture recognizers in the
/// same spot) — on a plain black backdrop rather than the newspaper's own
/// paper texture, since a photo is not an editorial surface.
class FullscreenImageViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const FullscreenImageViewer({
    super.key,
    required this.urls,
    this.initialIndex = 0,
  });

  static Route<void> route(List<String> urls, {int initialIndex = 0}) {
    return PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, animation, _) => FadeTransition(
        opacity: animation,
        child: FullscreenImageViewer(urls: urls, initialIndex: initialIndex),
      ),
    );
  }

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  late final PageController _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.urls.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                // A concrete, always-non-zero box regardless of loading
                // state — without this, `CachedNetworkImage` (which has no
                // intrinsic size until its bytes actually decode) can
                // render at zero size inside `InteractiveViewer`'s loose
                // constraints, leaving nothing visible but the close
                // button on top of a plain black screen.
                child: SizedBox.expand(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: CachedNetworkImage(
                        imageUrl: widget.urls[index],
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(color: Colors.white54),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white54,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  if (widget.urls.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Text(
                        '${_index + 1} / ${widget.urls.length}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
