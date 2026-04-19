import 'package:flutter/material.dart';

/// Carousel navigation arrow button
class CarouselArrow extends StatelessWidget {

  const CarouselArrow({
    required this.icon, required this.onTap, super.key,
  });
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, 
            color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

/// Carousel page indicator
class CarouselIndicator extends StatelessWidget {

  const CarouselIndicator({
    required this.currentPage, required this.pageCount, required this.label, super.key,
  });
  final int currentPage;
  final int pageCount;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            label,
            key: ValueKey(currentPage),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
        const SizedBox(width: 6),
        ...List.generate(
          pageCount,
          (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(left: 3),
            width: i == currentPage ? 14 : 5,
            height: 5,
            decoration: BoxDecoration(
              color: i == currentPage
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
      ],
    );
  }
}

/// Page view with navigation controls and indicators
class NavigablePageView extends StatefulWidget {

  const NavigablePageView({
    required this.pages, required this.labels, super.key,
    this.height = 260,
  });
  final List<Widget> pages;
  final List<String> labels;
  final double height;

  @override
  State<NavigablePageView> createState() => _NavigablePageViewState();
}

class _NavigablePageViewState extends State<NavigablePageView> {
  late PageController _controller;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.pages.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, index) => widget.pages[index],
            ),
            // Left arrow
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: CarouselArrow(
                  icon: Icons.chevron_left_rounded,
                  onTap: () => _goToPage(
                      (_currentPage - 1 + widget.pages.length) % widget.pages.length),
                ),
              ),
            ),
            // Right arrow
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: CarouselArrow(
                  icon: Icons.chevron_right_rounded,
                  onTap: () => _goToPage((_currentPage + 1) % widget.pages.length),
                ),
              ),
            ),
            // Page indicator
            Positioned(
              top: 0,
              right: 6,
              child: CarouselIndicator(
                currentPage: _currentPage,
                pageCount: widget.pages.length,
                label: widget.labels[_currentPage],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

