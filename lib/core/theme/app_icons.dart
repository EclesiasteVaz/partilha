import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Icon names used across the app.
///
/// `AGENTS.md` §47 requires UI code to reach icons through a project-owned API
/// so the icon implementation can change without rewriting widgets. This is
/// that boundary: the only file in the project allowed to import
/// `package:hugeicons`.
///
/// Names are grouped by the domain concept they serve rather than by the
/// visual shape, so a future swap to a different icon set changes this file
/// only.
///
/// Every value below was verified to exist in the pinned `hugeicons` version.
/// A missing name is a compile error here, not a blank box at runtime.
abstract final class AppIcons {
  // Transfer
  /// Send a file to the selected device.
  static const IconData send = HugeIcons.strokeRoundedUpload01;

  /// Receive a file from the selected device.
  static const IconData receive = HugeIcons.strokeRoundedDownload01;

  /// Generic share action.
  static const IconData share = HugeIcons.strokeRoundedShare01;

  /// Abort an in-flight transfer.
  static const IconData cancel = HugeIcons.strokeRoundedCancel01;

  /// Retry a failed transfer.
  static const IconData retry = HugeIcons.strokeRoundedRefresh;

  /// Transfer completed successfully.
  static const IconData completed = HugeIcons.strokeRoundedCheckmarkCircle01;

  // Files
  /// A single file.
  static const IconData file = HugeIcons.strokeRoundedFile01;

  /// A folder. Not used for transfer; folder transfer is out of MVP scope
  /// (`AGENTS.md` §25), this is only for navigating a source folder.
  static const IconData folder = HugeIcons.strokeRoundedFolder01;

  /// Add files to the selection.
  static const IconData add = HugeIcons.strokeRoundedAdd01;

  /// Remove a file from the selection.
  static const IconData remove = HugeIcons.strokeRoundedDelete01;

  // Devices and pairing
  /// A nearby device of unknown type.
  static const IconData device = HugeIcons.strokeRoundedSmartPhone01;

  /// A desktop peer.
  static const IconData computer = HugeIcons.strokeRoundedComputer;

  /// A laptop peer.
  static const IconData laptop = HugeIcons.strokeRoundedLaptop;

  /// Show the QR code this device publishes for pairing.
  static const IconData qrCode = HugeIcons.strokeRoundedQrCode;

  /// Scan a peer's QR code.
  static const IconData scan = HugeIcons.strokeRoundedQrCode01;

  /// Bluetooth transport indicator.
  static const IconData bluetooth = HugeIcons.strokeRoundedBluetooth;

  // Status
  /// Something failed.
  static const IconData error = HugeIcons.strokeRoundedAlert02;

  /// Something recoverable needs attention.
  static const IconData warning = HugeIcons.strokeRoundedAlert02;

  /// Neutral information.
  static const IconData info = HugeIcons.strokeRoundedInformationCircle;

  // Navigation
  /// App settings.
  static const IconData settings = HugeIcons.strokeRoundedConfiguration01;

  /// Overflow menu.
  static const IconData menu = HugeIcons.strokeRoundedMenu01;

  /// Navigate back.
  static const IconData back = HugeIcons.strokeRoundedArrowLeft01;

  // Metadata
  /// A queued transfer has not started yet.
  static const IconData queued = HugeIcons.strokeRoundedClock01;
}

/// Renders an [AppIcons] value.
///
/// Wraps the third-party widget so screens depend on a project-owned component
/// (§47, §51). Colour defaults to [IconThemeData.color] so an icon inherits its
/// surroundings instead of being hard-coded, and size falls back to a sensible
/// default rather than the package's fixed 24.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  /// One of the [AppIcons] values.
  final IconData icon;

  /// Logical pixels. Defaults to [IconThemeData.size].
  final double? size;

  /// Overrides [IconThemeData.color].
  final Color? color;

  /// Accessible name.
  ///
  /// §50 requires semantic labels. Pass null only when the icon is purely
  /// decorative and sits next to a text label that already names it; pass a
  /// label when the icon is the only carrier of meaning, such as an icon-only
  /// button.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final IconThemeData iconTheme = IconTheme.of(context);
    final Widget child = HugeIcon(
      icon: icon,
      size: size ?? iconTheme.size ?? 24,
      // Falls back through the theme so an icon is never left uncoloured, then
      // to the scheme's body colour as a last resort.
      color:
          color ??
          iconTheme.color ??
          DefaultTextStyle.of(context).style.color ??
          Theme.of(context).colorScheme.onSurface,
    );

    if (semanticLabel == null) return ExcludeSemantics(child: child);

    return Semantics(label: semanticLabel, child: child);
  }
}
