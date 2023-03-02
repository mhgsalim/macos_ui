import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:macos_ui/src/library.dart';

/// {@template macosSwitch}
/// A switch is a control that offers a binary choice between two mutually
/// exclusive states — on and off.
///
/// A switch shows that it's on when the [activeColor] is visible and off when
/// the [trackColor] is visible.
/// {@endtemplate}
class MacosSwitch extends StatefulWidget {
  /// {@macro macosSwitch}
  const MacosSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.dragStartBehavior = DragStartBehavior.start,
    this.activeColor,
    this.trackColor,
    this.knobColor,
    this.semanticLabel,
  });

  /// Whether this switch is on or off.
  ///
  /// Must not be null.
  final bool value;

  /// Called when the user toggles with switch on or off.
  ///
  /// The switch passes the new value to the callback but does not actually
  /// change state until the parent widget rebuilds the switch with the new
  /// value.
  ///
  /// If null, the switch will be displayed as disabled, which has a reduced opacity.
  ///
  /// The callback provided to onChanged should update the state of the parent
  /// [StatefulWidget] using the [State.setState] method, so that the parent
  /// gets rebuilt; for example:
  ///
  /// ```dart
  /// MacosSwitch(
  ///   value: _giveVerse,
  ///   onChanged: (bool newValue) {
  ///     setState(() {
  ///       _giveVerse = newValue;
  ///     });
  ///   },
  /// )
  /// ```
  final ValueChanged<bool>? onChanged;

  /// {@macro flutter.cupertino.CupertinoSwitch.dragStartBehavior}
  final DragStartBehavior dragStartBehavior;

  /// The color to use for the track when this switch is on.
  ///
  /// Defaults to [MacosThemeData.primaryColor] when null.
  final MacosColor? activeColor;

  /// The color to use for track when this switch is off.
  ///
  /// Defaults to [MacosTheme.primaryColor] when null.
  final MacosColor? trackColor;

  /// The color to use for the switch's knob.
  final MacosColor? knobColor;

  /// The semantic label used by screen readers.
  final String? semanticLabel;

  @override
  State<MacosSwitch> createState() => _MacosSwitchState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty(
      'checked',
      value: value,
      ifFalse: 'unchecked',
    ));
    properties.add(EnumProperty('dragStartBehavior', dragStartBehavior));
    properties.add(FlagProperty(
      'enabled',
      value: onChanged == null,
      ifFalse: 'disabled',
    ));
    properties.add(ColorProperty('activeColor', activeColor));
    properties.add(ColorProperty('trackColor', trackColor));
    properties.add(ColorProperty('knobColor', knobColor));
    properties.add(StringProperty('semanticLabel', semanticLabel));
  }
}

class _MacosSwitchState extends State<MacosSwitch>
    with TickerProviderStateMixin {
  late TapGestureRecognizer _tap;
  late HorizontalDragGestureRecognizer _drag;

  late AnimationController _positionController;
  late CurvedAnimation position;

  late AnimationController _reactionController;
  late Animation<double> _reaction;

  bool get isInteractive => widget.onChanged != null;

  // A non-null boolean value that changes to true at the end of a drag if the
  // switch must be animated to the position indicated by the widget's value.
  bool needsPositionAnimation = false;

  @override
  void initState() {
    super.initState();

    _tap = TapGestureRecognizer()
      ..onTapDown = _handleTapDown
      ..onTapUp = _handleTapUp
      ..onTap = _handleTap
      ..onTapCancel = _handleTapCancel;
    _drag = HorizontalDragGestureRecognizer()
      ..onStart = _handleDragStart
      ..onUpdate = _handleDragUpdate
      ..onEnd = _handleDragEnd
      ..dragStartBehavior = widget.dragStartBehavior;

    _positionController = AnimationController(
      duration: _kToggleDuration,
      value: widget.value ? 1.0 : 0.0,
      vsync: this,
    );
    position = CurvedAnimation(
      parent: _positionController,
      curve: Curves.linear,
    );
    _reactionController = AnimationController(
      duration: _kReactionDuration,
      vsync: this,
    );
    _reaction = CurvedAnimation(
      parent: _reactionController,
      curve: Curves.ease,
    );
  }

  @override
  void didUpdateWidget(MacosSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    _drag.dragStartBehavior = widget.dragStartBehavior;

    if (needsPositionAnimation || oldWidget.value != widget.value) {
      _resumePositionAnimation(isLinear: needsPositionAnimation);
    }
  }

  // `isLinear` must be true if the position animation is trying to move the
  // knob to the closest end after the most recent drag animation, so the curve
  // does not change when the controller's value is not 0 or 1.
  //
  // It can be set to false when it's an implicit animation triggered by
  // widget.value changes.
  void _resumePositionAnimation({bool isLinear = true}) {
    needsPositionAnimation = false;
    position
      ..curve = isLinear ? Curves.linear : Curves.ease
      ..reverseCurve = isLinear ? Curves.linear : Curves.ease.flipped;
    if (widget.value) {
      _positionController.forward();
    } else {
      _positionController.reverse();
    }
  }

  void _handleTapDown(TapDownDetails details) {
    if (isInteractive) {
      needsPositionAnimation = false;
    }
    _reactionController.forward();
  }

  void _handleTap() {
    if (isInteractive) {
      widget.onChanged!(!widget.value);
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (isInteractive) {
      needsPositionAnimation = false;
      _reactionController.reverse();
    }
  }

  void _handleTapCancel() {
    if (isInteractive) {
      _reactionController.reverse();
    }
  }

  void _handleDragStart(DragStartDetails details) {
    if (isInteractive) {
      needsPositionAnimation = false;
      _reactionController.forward();
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (isInteractive) {
      position
        ..curve = Curves.linear
        ..reverseCurve = Curves.linear;
      final double delta = details.primaryDelta! / _kTrackInnerLength;
      switch (Directionality.of(context)) {
        case TextDirection.rtl:
          _positionController.value -= delta;
          break;
        case TextDirection.ltr:
          _positionController.value += delta;
          break;
      }
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    // Deferring the animation to the next build phase.
    setState(() {
      needsPositionAnimation = true;
    });
    // Call onChanged when the user's intent to change value is clear.
    if (position.value >= 0.5 != widget.value) {
      widget.onChanged!(!widget.value);
    }
    _reactionController.reverse();
  }

  @override
  void dispose() {
    _tap.dispose();
    _drag.dispose();

    _positionController.dispose();
    _reactionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMacosTheme(context));
    final MacosThemeData theme = MacosTheme.of(context);
    MacosColor borderColor = theme.brightness.isDark
        ? const MacosColor.fromRGBO(90, 90, 90, 1.0)
        : const MacosColor.fromRGBO(210, 207, 208, 1.0);
    MacosColor activeColor = MacosColor(MacosDynamicColor.resolve(
      widget.activeColor ?? theme.primaryColor,
      context,
    ).value);
    MacosColor trackColor = widget.trackColor ??
        (theme.brightness.isDark
            ? const MacosColor.fromRGBO(54, 54, 54, 1.0)
            : const MacosColor.fromRGBO(228, 226, 228, 1.0));
    MacosColor knobColor = widget.knobColor ??
        (theme.brightness.isDark
            ? const MacosColor.fromRGBO(207, 207, 207, 1.0)
            : MacosColors.white);

    // Shot in the dark to try and get the border color correct for each
    // possible color
    if (widget.value) {
      if (theme.brightness.isDark) {
        borderColor.computeLuminance() > 0.5
            ? borderColor = MacosColor.darken(activeColor, 20)
            : borderColor = MacosColor.lighten(activeColor, 20);
      } else {
        borderColor.computeLuminance() > 0.5
            ? borderColor = MacosColor.darken(activeColor, 20)
            : borderColor = MacosColor.lighten(activeColor, 20);
      }
    }

    return Semantics(
      label: widget.semanticLabel,
      checked: widget.value,
      child: _MacosSwitchRenderObjectWidget(
        value: widget.value,
        activeColor: activeColor,
        trackColor: trackColor,
        knobColor: knobColor,
        borderColor: borderColor,
        onChanged: widget.onChanged,
        textDirection: Directionality.of(context),
        state: this,
      ),
    );
  }
}

class _MacosSwitchRenderObjectWidget extends LeafRenderObjectWidget {
  const _MacosSwitchRenderObjectWidget({
    required this.value,
    required this.activeColor,
    required this.trackColor,
    required this.knobColor,
    required this.borderColor,
    required this.onChanged,
    required this.textDirection,
    required this.state,
  });
  final bool value;
  final MacosColor activeColor;
  final MacosColor trackColor;
  final MacosColor knobColor;
  final MacosColor borderColor;
  final ValueChanged<bool>? onChanged;
  final TextDirection textDirection;
  final _MacosSwitchState state;

  @override
  _RenderMacosSwitch createRenderObject(BuildContext context) {
    return _RenderMacosSwitch(
      value: value,
      activeColor: activeColor,
      trackColor: trackColor,
      knobColor: knobColor,
      borderColor: borderColor,
      onChanged: onChanged,
      textDirection: textDirection,
      state: state,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMacosSwitch renderObject,
  ) {
    assert(renderObject._state == state);
    renderObject
      ..value = value
      ..activeColor = activeColor
      ..trackColor = trackColor
      ..knobColor = knobColor
      ..borderColor = borderColor
      ..onChanged = onChanged
      ..textDirection = textDirection;
  }
}

const double _kTrackWidth = 36.0;
const double _kTrackHeight = 20.0;
const double _kTrackRadius = _kTrackHeight / 2.0;
const double _kTrackInnerStart = _kTrackHeight / 2.0;
const double _kTrackInnerEnd = _kTrackWidth - _kTrackInnerStart;
const double _kTrackInnerLength = _kTrackInnerEnd - _kTrackInnerStart;
const double _kSwitchWidth = 59.0;
const double _kSwitchHeight = 39.0;
const Size _kKnobSize = Size(19.5, 19.5);
const Duration _kReactionDuration = Duration(milliseconds: 400);
const Duration _kToggleDuration = Duration(milliseconds: 300);

class _RenderMacosSwitch extends RenderConstrainedBox {
  _RenderMacosSwitch({
    required bool value,
    required MacosColor activeColor,
    required MacosColor trackColor,
    required MacosColor knobColor,
    required MacosColor borderColor,
    required ValueChanged<bool>? onChanged,
    required TextDirection textDirection,
    required _MacosSwitchState state,
  })  : _value = value,
        _activeColor = activeColor,
        _trackColor = trackColor,
        _knobPainter = MacosSwitchKnobPainter(
          color: knobColor,
          // borderColor: borderColor,
        ),
        _borderColor = borderColor,
        _onChanged = onChanged,
        _textDirection = textDirection,
        _state = state,
        super(
          additionalConstraints: const BoxConstraints.tightFor(
            width: _kSwitchWidth,
            height: _kSwitchHeight,
          ),
        ) {
    state.position.addListener(markNeedsPaint);
    state._reaction.addListener(markNeedsPaint);
  }

  final _MacosSwitchState _state;

  bool get value => _value;
  bool _value;
  set value(bool newValue) {
    if (newValue == _value) {
      return;
    }
    _value = newValue;
    markNeedsSemanticsUpdate();
  }

  MacosColor get activeColor => _activeColor;
  MacosColor _activeColor;
  set activeColor(MacosColor value) {
    if (value == _activeColor) {
      return;
    }
    _activeColor = value;
    markNeedsPaint();
  }

  MacosColor get trackColor => _trackColor;
  MacosColor _trackColor;
  set trackColor(MacosColor value) {
    if (value == _trackColor) {
      return;
    }
    _trackColor = value;
    markNeedsPaint();
  }

  MacosColor get knobColor => _knobPainter.color;
  MacosSwitchKnobPainter _knobPainter;
  set knobColor(MacosColor value) {
    if (value == knobColor) {
      return;
    }
    _knobPainter = MacosSwitchKnobPainter(
      color: value,
      // borderColor: borderColor,
    );
    markNeedsPaint();
  }

  MacosColor get borderColor => _borderColor;
  MacosColor _borderColor;
  set borderColor(MacosColor value) {
    if (value == borderColor) {
      return;
    }
    _borderColor = value;
    markNeedsPaint();
  }

  ValueChanged<bool>? get onChanged => _onChanged;
  ValueChanged<bool>? _onChanged;
  set onChanged(ValueChanged<bool>? value) {
    if (value == _onChanged) {
      return;
    }
    final bool wasInteractive = isInteractive;
    _onChanged = value;
    if (wasInteractive != isInteractive) {
      markNeedsPaint();
      markNeedsSemanticsUpdate();
    }
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) {
      return;
    }
    _textDirection = value;
    markNeedsPaint();
  }

  bool get isInteractive => onChanged != null;

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    assert(debugHandleEvent(event, entry));
    if (event is PointerDownEvent && isInteractive) {
      _state._drag.addPointer(event);
      _state._tap.addPointer(event);
    }
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);

    if (isInteractive) {
      config.onTap = _state._handleTap;
    }

    config.isEnabled = isInteractive;
    config.isToggled = _value;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final Canvas canvas = context.canvas;

    final double currentValue = _state.position.value;
    final double currentReactionValue = _state._reaction.value;

    final double visualPosition;
    switch (textDirection) {
      case TextDirection.rtl:
        visualPosition = 1.0 - currentValue;
        break;
      case TextDirection.ltr:
        visualPosition = currentValue;
        break;
    }

    final Paint paint = Paint()
      ..color = MacosColor.lerp(trackColor, activeColor, currentValue);

    final Rect trackRect = Rect.fromLTWH(
      offset.dx + (size.width - _kTrackWidth) / 2.0,
      offset.dy + (size.height - _kTrackHeight) / 2.0,
      _kTrackWidth,
      _kTrackHeight,
    );
    final RRect trackRRect = RRect.fromRectAndRadius(
      trackRect,
      const Radius.circular(_kTrackRadius),
    );
    canvas.drawRRect(trackRRect, paint);
    canvas.drawRRect(
      trackRRect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke,
    );

    final double currentKnobExtension =
        MacosSwitchKnobPainter.extension * currentReactionValue;
    final double knobLeft = lerpDouble(
      trackRect.left + _kTrackInnerStart - MacosSwitchKnobPainter.radius,
      trackRect.left +
          _kTrackInnerEnd -
          MacosSwitchKnobPainter.radius -
          currentKnobExtension,
      visualPosition,
    )!;
    final double knobRight = lerpDouble(
      trackRect.left +
          _kTrackInnerStart +
          MacosSwitchKnobPainter.radius +
          currentKnobExtension,
      trackRect.left + _kTrackInnerEnd + MacosSwitchKnobPainter.radius,
      visualPosition,
    )!;
    final double knobCenterY = offset.dy + size.height / 2.0;
    final Rect knobBounds = Rect.fromLTRB(
      knobLeft,
      knobCenterY - MacosSwitchKnobPainter.radius,
      knobRight,
      knobCenterY + MacosSwitchKnobPainter.radius,
    );

    _clipRRectLayer.layer = context.pushClipRRect(
      needsCompositing,
      Offset.zero,
      knobBounds,
      trackRRect,
      (PaintingContext innerContext, Offset offset) {
        _knobPainter.paint(innerContext.canvas, knobBounds);
      },
      oldLayer: _clipRRectLayer.layer,
    );
  }

  final LayerHandle<ClipRRectLayer> _clipRRectLayer =
      LayerHandle<ClipRRectLayer>();

  @override
  void dispose() {
    _clipRRectLayer.layer = null;
    super.dispose();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(FlagProperty(
      'value',
      value: value,
      ifTrue: 'checked',
      ifFalse: 'unchecked',
      showName: true,
    ));
    description.add(FlagProperty(
      'isInteractive',
      value: isInteractive,
      ifTrue: 'enabled',
      ifFalse: 'disabled',
      showName: true,
      defaultValue: true,
    ));
  }
}

const List<BoxShadow> _kSwitchBoxShadows = <BoxShadow>[
  BoxShadow(
    color: Color(0x26000000),
    offset: Offset(0, 3),
    blurRadius: 8.0,
  ),
  BoxShadow(
    color: Color(0x0F000000),
    offset: Offset(0, 3),
    blurRadius: 1.0,
  ),
];

/// Paints a macOS-style switch knob.
///
/// Used by [MacosSwitch].
class MacosSwitchKnobPainter {
  /// Creates an object that paints a macOS-style switch knob.
  const MacosSwitchKnobPainter({
    required this.color,
    // required this.borderColor,
    this.shadows = _kSwitchBoxShadows,
  });

  /// The color of the interior of the knob.
  final MacosColor color;
  // final MacosColor borderColor;

  /// The list of [BoxShadow] to paint below the knob.
  ///
  /// Must not be null.
  final List<BoxShadow> shadows;

  /// Half the default diameter of the knob.
  static double radius = _kKnobSize.height / 2.0;

  /// The default amount the knob should be extended horizontally when pressed.
  static const double extension = 7.0;

  /// Paints the knob onto the given canvas in the given rectangle.
  ///
  /// Consider using [radius] and [extension] when deciding how large a
  /// rectangle to use for the knob.
  void paint(Canvas canvas, Rect rect) {
    final RRect rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(rect.shortestSide / 2.0),
    );

    for (final BoxShadow shadow in shadows) {
      canvas.drawRRect(rrect.shift(shadow.offset), shadow.toPaint());
    }

    /*canvas.drawRRect(
      rrect.inflate(0.5),
      Paint()..color = borderColor,
    );*/
    canvas.drawRRect(rrect, Paint()..color = color);
  }
}
