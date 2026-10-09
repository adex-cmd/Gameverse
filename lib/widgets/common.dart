import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/responsive.dart';

class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 52,
    this.expand = false,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;
  final bool expand;

  /// Tighter side padding, for narrow spots such as the phone carousel.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, color: Colors.white, size: context.rs(20)),
          SizedBox(width: context.rs(8)),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: context.rs(15),
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.gradient,
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(height / 2),
            child: SizedBox(
              height: height,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.rs(dense ? 14 : 22),
                ),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A soft outlined button that sits next to [GradientButton].
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 52,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      shape: StadiumBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: AppColors.text),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final button = ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withValues(alpha: 0.10),
          child: InkWell(
            onTap: onPressed,
            child: SizedBox.square(
              dimension: size,
              child: Icon(icon, size: size * 0.48, color: AppColors.text),
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => AppColors.gradient.createShader(bounds),
      child: Text(text, style: style),
    );
  }
}

/// Small rounded label, e.g. "1940" or "480p".
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.icon, this.highlighted = false});
  final String label;
  final IconData? icon;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: highlighted ? AppColors.gradient : null,
        color: highlighted ? null : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: AppColors.text),
            const SizedBox(width: 4),
          ],
          // Flexible so a long label shortens instead of overflowing a narrow row.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated placeholder shown while content loads.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, this.width, this.height, this.radius = 14});
  final double? width;
  final double? height;
  final double radius;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value * 3 - 1;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(t - 1, -0.3),
              end: Alignment(t + 1, 0.3),
              colors: const [
                AppColors.surface,
                AppColors.surfaceHigh,
                AppColors.surface,
              ],
            ),
          ),
        );
      },
    );
  }
}

class GradientProgressBar extends StatelessWidget {
  const GradientProgressBar({
    super.key,
    required this.value,
    this.height = 6,
    this.muted = false,
  });

  /// 0..1, or null when the size is unknown.
  final double? value;
  final double height;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height);
    if (value == null) {
      return ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          height: height,
          child: const LinearProgressIndicator(
            backgroundColor: AppColors.surfaceHigh,
            color: AppColors.accent,
          ),
        ),
      );
    }
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: radius,
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value!.clamp(0.0, 1.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: muted ? null : AppColors.gradient,
            color: muted ? AppColors.textDim : null,
          ),
        ),
      ),
    );
  }
}

/// A network image that fades in, shimmers while loading, and falls back
/// to a branded placeholder when the image is missing.
class NetworkPoster extends StatelessWidget {
  const NetworkPoster(this.url, {super.key, this.fit = BoxFit.cover});
  final String? url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (url == null) return const PosterPlaceholder();
    return Image.network(
      url!,
      fit: fit,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, sync) {
        if (sync) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 350),
          child: child,
        );
      },
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const Shimmer(radius: 0),
      errorBuilder: (context, error, stack) => const PosterPlaceholder(),
    );
  }
}

class PosterPlaceholder extends StatelessWidget {
  const PosterPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A1422), Color(0xFF1B1B2B)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.movie_creation_outlined,
          size: 36,
          color: Colors.white.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: displayStyle(context.rs(26)))),
        ?trailing,
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.gutter + 8,
        vertical: context.rs(40),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: context.rs(84),
            height: context.rs(84),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.accent.withValues(alpha: 0.25),
                  AppColors.accent2.withValues(alpha: 0.15),
                ],
              ),
            ),
            child: Icon(icon, size: context.rs(38), color: AppColors.text),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: displayStyle(context.rs(28)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textDim, height: 1.4),
          ),
          if (action != null) ...[const SizedBox(height: 22), action!],
        ],
      ),
    );
  }
}
