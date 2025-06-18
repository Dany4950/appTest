import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html show window, document;

/// Entrypoint of the application.
void main() {
  runApp(const MyApp());
}

/// [MaterialApp] of the application.
class MyApp extends StatelessWidget { 
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: HomePage());
  }
}

/// Home page displaying [RectangleArea]s in a [Stack].
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: constraints.maxWidth / 6,
                top: constraints.maxHeight / 6,
                child: ContextMenu(
                  child: RectangleArea(
                    label: 'Top left',
                    color: Colors.yellow,
                    size: constraints.biggest.shortestSide / 4,
                  ),
                ),
              ),
              Positioned(
                right: constraints.maxWidth / 6,
                top: constraints.maxHeight / 6,
                child: ContextMenu(
                  child: RectangleArea(
                    label: 'Top right',
                    color: Colors.green,
                    size: constraints.biggest.shortestSide / 4,
                  ),
                ),
              ),
              Positioned(
                right: constraints.maxWidth / 6,
                bottom: constraints.maxHeight / 6,
                child: ContextMenu(
                  child: RectangleArea(
                    label: 'Bottom right',
                    color: Colors.blue,
                    size: constraints.biggest.shortestSide / 4,
                  ),
                ),
              ),
              Positioned(
                left: constraints.maxWidth / 6,
                bottom: constraints.maxHeight / 6,
                child: ContextMenu(
                  child: RectangleArea(
                    label: 'Bottom left',
                    color: Colors.purple,
                    size: constraints.biggest.shortestSide / 4,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// [Container] with the provided [label], [size] and [color].
class RectangleArea extends StatelessWidget {
  const RectangleArea({
    super.key,
    required this.label,
    required this.size,
    required this.color,
  });

  /// Text to display in the center of this widget.
  final String label;

  /// Color to display the [Container] with.
  final Color color;

  /// Size of the [Container].
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color),
      child: Center(child: Text(label)),
    );
  }
}

/// Custom Interceptor widget that disables default browser context menu on Web
/// and works on both Web and native platforms
class Interceptor extends StatelessWidget {
  final Widget child;

  const Interceptor({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return GestureDetector(
        onSecondaryTap: () {
          // Prevent default context menu on web by handling the event
        },
        child: _WebInterceptor(child: child),
      );
    } else {
      // On native platforms, just return the child
      return child;
    }
  }
}

class _WebInterceptor extends StatefulWidget {
  final Widget child;

  const _WebInterceptor({Key? key, required this.child}) : super(key: key);

  @override
  _WebInterceptorState createState() => _WebInterceptorState();
}

class _WebInterceptorState extends State<_WebInterceptor> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _disableContextMenu();
    }
  }

  void _disableContextMenu() {
    try {
      html.document.addEventListener('contextmenu', (event) {
        event.preventDefault();
      });
    } catch (e) {
      // Handle any errors gracefully
      print('Could not disable context menu: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Reusable ContextMenu widget that wraps around a child widget
/// and displays a custom context menu on right-click
class ContextMenu extends StatefulWidget {
  final Widget child;

  const ContextMenu({Key? key, required this.child}) : super(key: key);

  @override
  _ContextMenuState createState() => _ContextMenuState();
}

class _ContextMenuState extends State<ContextMenu> {
  OverlayEntry? _overlayEntry;
  final GlobalKey _childKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Interceptor(
      child: GestureDetector(
        key: _childKey,
        onSecondaryTapDown: _showContextMenu,
        onTap: _hideContextMenu,
        child: widget.child,
      ),
    );
  }

  void _showContextMenu(TapDownDetails details) {
    _hideContextMenu(); // Hide any existing menu first
    
    final RenderBox renderBox = _childKey.currentContext!.findRenderObject() as RenderBox;
    final Size childSize = renderBox.size;
    final Offset childPosition = renderBox.localToGlobal(Offset.zero);
    
    _overlayEntry = _createOverlayEntry(details.globalPosition, childPosition, childSize);
    Overlay.of(context)!.insert(_overlayEntry!);
  }

  void _hideContextMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry(Offset tapPosition, Offset childPosition, Size childSize) {
    return OverlayEntry(
      builder: (context) => _ContextMenuOverlay(
        tapPosition: tapPosition,
        childPosition: childPosition,
        childSize: childSize,
        onDismiss: _hideContextMenu,
        onItemSelected: (String item) {
          // As requested, clicking on options should have no effect
          print('Selected: $item');
          _hideContextMenu();
        },
      ),
    );
  }

  @override
  void dispose() {
    _hideContextMenu();
    super.dispose();
  }
}

class _ContextMenuOverlay extends StatefulWidget {
  final Offset tapPosition;
  final Offset childPosition;
  final Size childSize;
  final VoidCallback onDismiss;
  final Function(String) onItemSelected;

  const _ContextMenuOverlay({
    Key? key,
    required this.tapPosition,
    required this.childPosition,
    required this.childSize,
    required this.onDismiss,
    required this.onItemSelected,
  }) : super(key: key);

  @override
  _ContextMenuOverlayState createState() => _ContextMenuOverlayState();
}

class _ContextMenuOverlayState extends State<_ContextMenuOverlay> {
  final GlobalKey _menuKey = GlobalKey();
  Offset _menuPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _menuPosition = widget.tapPosition;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateMenuPosition();
    });
  }

  void _calculateMenuPosition() {
    final RenderBox? menuRenderBox = _menuKey.currentContext?.findRenderObject() as RenderBox?;
    if (menuRenderBox == null) return;

    final Size menuSize = menuRenderBox.size;
    final Size screenSize = MediaQuery.of(context).size;
    
    double x = widget.tapPosition.dx;
    double y = widget.tapPosition.dy;

    // Ensure menu stays within screen bounds
    if (x + menuSize.width > screenSize.width) {
      x = screenSize.width - menuSize.width - 10;
    }
    if (y + menuSize.height > screenSize.height) {
      y = screenSize.height - menuSize.height - 10;
    }

    // Ensure menu doesn't cover the child widget
    final Rect childRect = Rect.fromLTWH(
      widget.childPosition.dx,
      widget.childPosition.dy,
      widget.childSize.width,
      widget.childSize.height,
    );

    final Rect menuRect = Rect.fromLTWH(x, y, menuSize.width, menuSize.height);

    if (childRect.overlaps(menuRect)) {
      // Try positioning to the right of the child
      if (widget.childPosition.dx + widget.childSize.width + menuSize.width < screenSize.width) {
        x = widget.childPosition.dx + widget.childSize.width + 5;
        y = widget.childPosition.dy;
      }
      // Try positioning below the child
      else if (widget.childPosition.dy + widget.childSize.height + menuSize.height < screenSize.height) {
        x = widget.childPosition.dx;
        y = widget.childPosition.dy + widget.childSize.height + 5;
      }
      // Try positioning to the left of the child
      else if (widget.childPosition.dx - menuSize.width > 0) {
        x = widget.childPosition.dx - menuSize.width - 5;
        y = widget.childPosition.dy;
      }
      // Try positioning above the child
      else if (widget.childPosition.dy - menuSize.height > 0) {
        x = widget.childPosition.dx;
        y = widget.childPosition.dy - menuSize.height - 5;
      }
    }

    // Final bounds check
    x = x.clamp(0.0, (screenSize.width - menuSize.width).clamp(0.0, double.infinity));
    y = y.clamp(0.0, (screenSize.height - menuSize.height).clamp(0.0, double.infinity));

    if (mounted) {
      setState(() {
        _menuPosition = Offset(x, y);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Invisible overlay to detect taps outside menu
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),
        // Context menu
        Positioned(
          left: _menuPosition.dx,
          top: _menuPosition.dy,
          child: Material(
            key: _menuKey,
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMenuItem('Create', Icons.add),
                  Divider(height: 1),
                  _buildMenuItem('Edit', Icons.edit),
                  Divider(height: 1),
                  _buildMenuItem('Remove', Icons.delete),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(String title, IconData icon) {
    return InkWell(
      onTap: () => widget.onItemSelected(title),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade700),
            SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
