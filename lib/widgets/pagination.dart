import 'package:flutter/material.dart';
import '../core/app_constants.dart';

/// Pagination state and logic for lists
class PaginationController<T> extends ChangeNotifier {

  PaginationController({
    required this.loadPage,
    this.pageSize = DatabaseConstants.defaultPageSize,
  });
  final Future<List<T>> Function(int offset, int limit) loadPage;
  final int pageSize;

  final List<T> _items = [];
  bool _loading = false;
  bool _hasMore = true;
  String? _error;
  int _currentPage = 0;

  List<T> get items => List.unmodifiable(_items);
  bool get loading => _loading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  int get itemCount => _items.length;
  int get currentPage => _currentPage;

  /// Load initial page
  Future<void> loadInitial() async {
    _currentPage = 0;
    _items.clear();
    _hasMore = true;
    _error = null;
    notifyListeners();
    
    await loadNext();
  }

  /// Load next page
  Future<void> loadNext() async {
    if (_loading || !_hasMore) return;

    try {
      _loading = true;
      _error = null;
      notifyListeners();

      final offset = _currentPage * pageSize;
      final newItems = await loadPage(offset, pageSize);

      if (newItems.length < pageSize) {
        _hasMore = false;
      }

      _items.addAll(newItems);
      _currentPage++;
      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
    }
  }

  /// Refresh list from beginning
  Future<void> refresh() async {
    await loadInitial();
  }

  /// Add item optimistically
  void addItem(T item) {
    _items.insert(0, item);
    notifyListeners();
  }

  /// Update item
  void updateItem(int index, T item) {
    if (index >= 0 && index < _items.length) {
      _items[index] = item;
      notifyListeners();
    }
  }

  /// Remove item
  void removeItem(T item) {
    _items.remove(item);
    notifyListeners();
  }

  /// Remove item at index
  void removeAt(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
      notifyListeners();
    }
  }

  /// Clear all items
  void clear() {
    _items.clear();
    _currentPage = 0;
    _hasMore = true;
    _error = null;
    notifyListeners();
  }
}

/// Lazy loading list view with pagination
class PaginatedListView<T> extends StatefulWidget {

  const PaginatedListView({
    required this.controller, required this.itemBuilder, super.key,
    this.separator,
    this.loadingWidget,
    this.emptyWidget,
    this.errorWidget,
    this.padding,
    this.scrollController,
    this.shrinkWrap = false,
    this.physics,
  });
  final PaginationController<T> controller;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget? separator;
  final Widget? loadingWidget;
  final Widget? emptyWidget;
  final Widget? errorWidget;
  final EdgeInsets? padding;
  final ScrollController? scrollController;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
    
    // Load initial data
    if (widget.controller.items.isEmpty && !widget.controller.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controller.loadInitial();
      });
    }
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      widget.controller.loadNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        final controller = widget.controller;

        // Error state
        if (controller.error != null && controller.items.isEmpty) {
          return widget.errorWidget ??
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Error: ${controller.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: controller.loadInitial,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
        }

        // Empty state
        if (controller.items.isEmpty && !controller.loading) {
          return widget.emptyWidget ??
              const Center(
                child: Text('No items'),
              );
        }

        // List with items
        return ListView.separated(
          controller: _scrollController,
          padding: widget.padding,
          shrinkWrap: widget.shrinkWrap,
          physics: widget.physics,
          itemCount: controller.items.length + (controller.hasMore ? 1 : 0),
          separatorBuilder: (context, index) {
            if (index >= controller.items.length) {
              return const SizedBox.shrink();
            }
            return widget.separator ?? const SizedBox.shrink();
          },
          itemBuilder: (context, index) {
            if (index >= controller.items.length) {
              return widget.loadingWidget ??
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
            }

            return widget.itemBuilder(
              context,
              controller.items[index],
              index,
            );
          },
        );
      },
    );
  }
}

/// Sliver version for CustomScrollView
class SliverPaginatedList<T> extends StatefulWidget {

  const SliverPaginatedList({
    required this.controller, required this.itemBuilder, super.key,
    this.loadingWidget,
  });
  final PaginationController<T> controller;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget? loadingWidget;

  @override
  State<SliverPaginatedList<T>> createState() => _SliverPaginatedListState<T>();
}

class _SliverPaginatedListState<T> extends State<SliverPaginatedList<T>> {
  @override
  void initState() {
    super.initState();
    if (widget.controller.items.isEmpty && !widget.controller.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controller.loadInitial();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        final controller = widget.controller;

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index >= controller.items.length) {
                // Load more trigger
                if (controller.hasMore && !controller.loading) {
                  controller.loadNext();
                }
                
                return widget.loadingWidget ??
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
              }

              return widget.itemBuilder(
                context,
                controller.items[index],
                index,
              );
            },
            childCount: controller.items.length + (controller.hasMore ? 1 : 0),
          ),
        );
      },
    );
  }
}

/// Grid version with pagination
class PaginatedGridView<T> extends StatefulWidget {

  const PaginatedGridView({
    required this.controller, required this.itemBuilder, super.key,
    this.crossAxisCount = 2,
    this.childAspectRatio = 1.0,
    this.crossAxisSpacing = 8.0,
    this.mainAxisSpacing = 8.0,
    this.padding,
    this.scrollController,
  });
  final PaginationController<T> controller;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final int crossAxisCount;
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final EdgeInsets? padding;
  final ScrollController? scrollController;

  @override
  State<PaginatedGridView<T>> createState() => _PaginatedGridViewState<T>();
}

class _PaginatedGridViewState<T> extends State<PaginatedGridView<T>> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
    
    if (widget.controller.items.isEmpty && !widget.controller.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controller.loadInitial();
      });
    }
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      widget.controller.loadNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        final controller = widget.controller;

        if (controller.items.isEmpty && !controller.loading) {
          return const Center(child: Text('No items'));
        }

        return GridView.builder(
          controller: _scrollController,
          padding: widget.padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: widget.crossAxisCount,
            childAspectRatio: widget.childAspectRatio,
            crossAxisSpacing: widget.crossAxisSpacing,
            mainAxisSpacing: widget.mainAxisSpacing,
          ),
          itemCount: controller.items.length + (controller.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= controller.items.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            return widget.itemBuilder(
              context,
              controller.items[index],
              index,
            );
          },
        );
      },
    );
  }
}
