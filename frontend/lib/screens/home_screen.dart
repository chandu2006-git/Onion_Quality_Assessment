import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
import '../widgets/app_shell.dart';
import '../widgets/brand_mark.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/surfaces.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      child: SingleChildScrollView(
        child: Column(
          children: const [
            _HeroSection(),
            _MetricsBand(),
            _WhySection(),
            _HowItWorksSection(),
            _StandardsContextSection(),
            _WorkflowSection(),
            AppFooter(),
          ],
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.primary,
      padding: const EdgeInsets.only(top: AppTheme.s48, bottom: AppTheme.xxl),
      child: ContentContainer(
        maxWidth: AppTheme.maxContentWidth,
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < 700
              ? AppTheme.gutter
              : AppTheme.s48,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            final text = const _HeroText();
            final visual = const _HeroVisual();
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 5, child: text),
                  const SizedBox(width: AppTheme.xxl),
                  Expanded(flex: 6, child: visual),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                text,
                const SizedBox(height: AppTheme.xl),
                visual,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeroText extends StatelessWidget {
  const _HeroText();

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BrandMark(onDark: true),
        const SizedBox(height: AppTheme.lg),
        Text(
          'ONION DETECT',
          style: AppTextStyles.display.copyWith(
            color: AppTheme.white,
            fontSize: compact ? 34 : 44,
          ),
        ),
        const SizedBox(height: AppTheme.s8),
        Text(
          AppConfig.tagline,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.lightGreen,
          ),
        ),
        const SizedBox(height: AppTheme.lg),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.md,
            vertical: AppTheme.s12,
          ),
          decoration: BoxDecoration(
            color: AppTheme.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
            border: Border.all(color: AppTheme.amber.withValues(alpha: 0.7)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.arrow_downward, size: 17, color: AppTheme.amber),
              const SizedBox(width: AppTheme.s8),
              Flexible(
                child: Text(
                  AppConfig.workflowStatement,
                  style: const TextStyle(
                    color: AppTheme.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.lg),
        Text(
          'An AI-assisted visual inspection workflow that identifies individual '
          'onion bulbs, evaluates their health condition, and records the '
          'observations for human verification.',
          style: AppTextStyles.body.copyWith(color: AppTheme.lightGreen),
        ),
        const SizedBox(height: AppTheme.xl),
        Wrap(
          spacing: AppTheme.md,
          runSpacing: AppTheme.s12,
          children: [
            FilledButton(
              onPressed: () => context.go('/start'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.white,
                foregroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
              ),
              child: const Text('START INSPECTION →'),
            ),
            OutlinedButton(
              onPressed: () => context.go('/about'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.white,
                side: const BorderSide(color: AppTheme.lightGreen),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 19),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  letterSpacing: 1,
                ),
              ),
              child: const Text('METHODOLOGY & STANDARDS →'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Hero visual: the designed inspection-pattern placeholder (the project ships
/// no bundled hero photograph, so no asset load is attempted).
class _HeroVisual extends StatelessWidget {
  const _HeroVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.circular(AppTheme.panelRadius),
        border: Border.all(color: AppTheme.secondaryGreen.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _HeroPlaceholder(),
            Positioned(
              left: AppTheme.md,
              bottom: AppTheme.md,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.s12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.charcoal.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(AppTheme.chipRadius),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.center_focus_strong, size: 13, color: AppTheme.lightGreen),
                    SizedBox(width: 6),
                    Text(
                      'INDIVIDUAL BULB OBSERVATIONS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: AppTheme.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Designed placeholder that communicates computer-vision inspection without
/// pretending to be an AI screenshot.
class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _InspectionPatternPainter());
  }
}

class _InspectionPatternPainter extends CustomPainter {
  const _InspectionPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppTheme.primaryDark, AppTheme.secondaryGreen],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), background);

    final grid = Paint()
      ..color = AppTheme.lightGreen.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += size.width / 12) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += size.height / 8) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Three onion forms with restrained detection boxes.
    _drawBulb(canvas, size, 0.26, 0.42, 0.17, AppTheme.healthy);
    _drawBulb(canvas, size, 0.53, 0.58, 0.14, AppTheme.healthy);
    _drawBulb(canvas, size, 0.74, 0.38, 0.12, AppTheme.unhealthy);
  }

  void _drawBulb(
    Canvas canvas,
    Size size,
    double cx,
    double cy,
    double radiusFactor,
    Color boxColour,
  ) {
    final centre = Offset(size.width * cx, size.height * cy);
    final radius = size.shortestSide * radiusFactor;

    canvas.drawCircle(
      centre,
      radius,
      Paint()..color = AppTheme.white.withValues(alpha: 0.16),
    );
    canvas.drawCircle(
      centre,
      radius * 0.72,
      Paint()
        ..color = AppTheme.lightGreen.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawLine(
      Offset(centre.dx, centre.dy - radius * 1.16),
      Offset(centre.dx, centre.dy - radius * 0.72),
      Paint()
        ..color = AppTheme.lightGreen.withValues(alpha: 0.5)
        ..strokeWidth = 2,
    );

    final box = Rect.fromCenter(
      center: centre,
      width: radius * 2.5,
      height: radius * 2.3,
    );
    canvas.drawRect(
      box,
      Paint()
        ..color = boxColour.withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawRect(
      Rect.fromLTWH(box.left, box.top - 15, 42, 15),
      Paint()..color = boxColour.withValues(alpha: 0.95),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


class _MetricsBand extends StatelessWidget {
  const _MetricsBand();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.offWhite,
      padding: const EdgeInsets.symmetric(vertical: AppTheme.xxl),
      child: ContentContainer(
        maxWidth: AppTheme.maxContentWidth,
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < 700
              ? AppTheme.gutter
              : AppTheme.s48,
          vertical: AppTheme.s8,
        ),
        child: const ResponsiveCardGrid(
          minCardWidth: 250,
          maxColumns: 4,
          children: [
            MetricCard(
              value: '97.0%',
              title: 'mAP@50',
              description: 'YOLOv8n external validation.',
              icon: Icons.center_focus_strong,
            ),
            MetricCard(
              value: '99.38%',
              title: 'Test Accuracy',
              description: 'Held-out 802-image classification test set.',
              icon: Icons.science_outlined,
            ),
            MetricCard(
              value: 'INDIVIDUAL',
              title: 'Bulb Analysis',
              description: 'Each detected onion is evaluated separately.',
              icon: Icons.scatter_plot_outlined,
            ),
            MetricCard(
              value: 'HUMAN',
              title: 'Verified',
              description: 'Final inspection decision remains with the inspector.',
              icon: Icons.verified_user_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

class _PageSection extends StatelessWidget {
  const _PageSection({required this.title, required this.children, this.subtitle});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(title: title, subtitle: subtitle),
          const SizedBox(height: AppTheme.lg),
          ...children,
        ],
      ),
    );
  }
}

class _SectionFrame extends StatelessWidget {
  const _SectionFrame({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.white,
      padding: const EdgeInsets.symmetric(vertical: AppTheme.xxl),
      child: ContentContainer(
        maxWidth: AppTheme.maxContentWidth,
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < 700
              ? AppTheme.gutter
              : AppTheme.s48,
          vertical: AppTheme.s8,
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    );
  }
}

class _WhySection extends StatelessWidget {
  const _WhySection();

  @override
  Widget build(BuildContext context) {
    return const _SectionFrame(
      children: [
        _PageSection(
          title: 'Why onion inspection matters',
          children: [
            Text(
              'India is one of the world\u2019s major onion-producing and exporting '
              'countries, making consistent quality assessment important across '
              'production, storage, sorting and export workflows.',
              style: AppTypo.body,
            ),
            SizedBox(height: AppTheme.md),
            Text(
              'Visual inspection and grading can require significant manual effort. '
              'ONION DETECT adds a computer-vision observation layer that can assist '
              'inspectors by identifying individual bulbs and producing structured '
              'inspection evidence. It does not replace manual inspection.',
              style: AppTypo.body,
            ),
          ],
        ),
      ],
    );
  }
}


class _StandardsContextSection extends StatelessWidget {
  const _StandardsContextSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.white,
      padding: const EdgeInsets.symmetric(vertical: AppTheme.xxl),
      child: ContentContainer(
        maxWidth: AppTheme.maxContentWidth,
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < 700
              ? AppTheme.gutter
              : AppTheme.s48,
          vertical: AppTheme.s8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SectionHeading(
              title: 'Standards & quality context',
              subtitle: 'Reference context only — ONION DETECT does not assign official grades.',
            ),
            SizedBox(height: AppTheme.lg),
            ResponsiveCardGrid(
              minCardWidth: 300,
              maxColumns: 2,
              children: [
                PanelCard(
                  label: 'AGMARK reference',
                  child: Text(
                    'Indian grade standards for onions define quality requirements across specified grades and include parameters relating to firmness, compactness, cleanliness, sprouting and specified defects.',
                    style: AppTypo.body,
                  ),
                ),
                PanelCard(
                  label: 'APEDA reference',
                  child: Text(
                    'APEDA provides export-oriented agricultural quality, pack-house and traceability frameworks relevant to fresh produce supply chains.',
                    style: AppTypo.body,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkflowSection extends StatelessWidget {
  const _WorkflowSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.lightGreen,
      padding: const EdgeInsets.symmetric(vertical: AppTheme.xxl),
      child: ContentContainer(
        maxWidth: AppTheme.maxContentWidth,
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < 700
              ? AppTheme.gutter
              : AppTheme.s48,
          vertical: AppTheme.s8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeading(title: 'Why this workflow'),
            const SizedBox(height: AppTheme.lg),
            ResponsiveCardGrid(
              minCardWidth: 260,
              maxColumns: 3,
              children: const [
                PanelCard(
                  label: 'Consistency',
                  child: Text('Structured AI observations for individual bulbs.', style: AppTypo.body),
                ),
                PanelCard(
                  label: 'Traceability',
                  child: Text('Inspection metadata, image evidence and verification status can be preserved in a report.', style: AppTypo.body),
                ),
                PanelCard(
                  label: 'Human control',
                  child: Text('The inspector retains final verification authority.', style: AppTypo.body),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection();

  static const List<List<dynamic>> _steps = [
    ['01', 'DETECT', 'YOLOv8n identifies individual onion bulbs.', Icons.center_focus_strong],
    [
      '02',
      'ASSESS',
      'Each detected bulb is cropped and evaluated independently using MobileNetV2.',
      Icons.biotech_outlined,
    ],
    [
      '03',
      'VERIFY',
      'A human inspector reviews each AI observation and can confirm or override it.',
      Icons.fact_check_outlined,
    ],
    [
      '04',
      'RECORD',
      'The verified inspection is converted into a structured PDF report.',
      Icons.description_outlined,
    ],
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.offWhite,
      padding: const EdgeInsets.symmetric(vertical: AppTheme.xxl),
      child: ContentContainer(
        maxWidth: AppTheme.maxContentWidth,
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < 700
              ? AppTheme.gutter
              : AppTheme.s48,
          vertical: AppTheme.s8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeading(
              title: 'How it works',
              subtitle:
                  'Four stages from sample submission to a recorded, verifiable report.',
            ),
            const SizedBox(height: AppTheme.lg),
            ResponsiveCardGrid(
              minCardWidth: 230,
              maxColumns: 4,
              children: _steps
                  .map(
                    (step) => PanelCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                step[0] as String,
                                style: AppTypo.label.copyWith(
                                  color: AppTheme.amberDark,
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                step[3] as IconData,
                                size: 20,
                                color: AppTheme.secondaryGreen,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.md),
                          Text(
                            step[1] as String,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: AppTheme.s8),
                          Text(step[2] as String, style: AppTypo.bodyMuted),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

