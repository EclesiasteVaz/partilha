/// Spacing scale.
///
/// A single 4pt base so gaps are visually commensurate. Exposes named steps
/// rather than a numeric scale because a caller writing `AppSpacing.gutter`
/// cannot accidentally invent a one-off value, which is the failure mode
/// `AGENTS.md` §46 describes as hard-coded tokens.
abstract final class AppSpacing {
  /// 4pt. Small gaps inside a control.
  static const double xxs = 4;

  /// 8pt. Gap between tightly related elements.
  static const double xs = 8;

  /// 12pt. Default gap inside a component.
  static const double sm = 12;

  /// 16pt. Default gap between components.
  static const double md = 16;

  /// 24pt. Separates logical groups.
  static const double lg = 24;

  /// 32pt. Separates major sections.
  static const double xl = 32;

  /// 48pt. Page-level breathing room.
  static const double xxl = 48;

  /// Horizontal page padding.
  ///
  /// §49 requires responsive behaviour, and page padding is the first thing
  /// that has to change with width: a phone needs 16pt, a desktop needs more
  /// or content stretches edge to edge.
  static double pageHorizontal(double width) => switch (width) {
    < 600 => md,
    < 1000 => lg,
    _ => xl,
  };

  /// Content width cap.
  ///
  /// Caps line length on desktop instead of letting text run the full window
  /// width, which §49 explicitly warns against.
  static const double maxContentWidth = 720;
}

/// Corner radius scale.
abstract final class AppRadii {
  /// 4pt. Chips and badges.
  static const double xs = 4;

  /// 8pt. Buttons and inputs.
  static const double sm = 8;

  /// 12pt. Cards.
  static const double md = 12;

  /// 16pt. Sheets and large surfaces.
  static const double lg = 16;

  /// Fully rounded, for pills and avatars.
  static const double full = 999;
}

/// Icon sizes.
abstract final class AppIconSizes {
  /// Inline with body text.
  static const double sm = 16;

  /// Default in buttons and list rows.
  static const double md = 24;

  /// Empty-state and feature illustration.
  static const double lg = 32;

  /// Hero imagery.
  static const double xl = 48;
}

/// Minimum interactive target.
///
/// §50 requires appropriate touch targets. `MaterialTapTargetSize.padded`
/// gives 48x48, but a token keeps the requirement explicit and testable rather
/// than inherited from whichever widget happens to be used.
abstract final class AppSizes {
  /// Minimum width and height for anything tappable.
  static const double minTouchTarget = 48;
}
