import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../constants/app_assets.dart';
import '../constants/colors.dart';
import '../constants/spacing.dart';
import '../widgets/app_image.dart';
import '../services/toast_service.dart';

/// Données d'une slide promotionnelle.
class PromoSlide {
  const PromoSlide({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.cta,
  });

  final String image;
  final String title;
  final String subtitle;
  final String cta;
}

/// Carrousel promotionnel avec auto-play, indicateur et effet profondeur.
class PromoCarousel extends StatefulWidget {
  const PromoCarousel({super.key});

  static const slides = <PromoSlide>[
    PromoSlide(
      image: AppAssets.promo1,
      title: '3,5 Go + 120U',
      subtitle: 'Valables 48h — Que du bonheur !',
      cta: 'Activer',
    ),
    PromoSlide(
      image: AppAssets.promo2,
      title: 'Forfait Internet',
      subtitle: 'Surf en illimité à prix réduit',
      cta: 'Découvrir',
    ),
    PromoSlide(
      image: AppAssets.promo3,
      title: 'Cashback Airtel Money',
      subtitle: '5% sur vos paiements QR ce mois',
      cta: 'En profiter',
    ),
    PromoSlide(
      image: AppAssets.promo4,
      title: 'Airtel Money RENFORT',
      subtitle: 'Micro-crédit instantané',
      cta: 'Demander',
    ),
    PromoSlide(
      image: AppAssets.promo5,
      title: 'Parrainez et gagnez',
      subtitle: '500 CDF par filleul inscrit',
      cta: 'Parrainer',
    ),
  ];

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  final _controller = PageController(viewportFraction: 0.92);
  Timer? _autoPlay;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _autoPlay = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_current + 1) % PromoCarousel.slides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoPlay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            'Promotions',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: 168,
          child: PageView.builder(
            controller: _controller,
            itemCount: PromoCarousel.slides.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, index) {
              final slide = PromoCarousel.slides[index];
              final isActive = index == _current;
              return AnimatedScale(
                scale: isActive ? 1 : 0.94,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                child: _PromoSlideCard(
                  slide: slide,
                  onCta: () => ToastService.info(
                    context,
                    slide.title,
                    message: 'Offre promotionnelle — bientôt disponible',
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: SmoothPageIndicator(
            controller: _controller,
            count: PromoCarousel.slides.length,
            effect: ExpandingDotsEffect(
              dotHeight: 6,
              dotWidth: 6,
              expansionFactor: 3,
              spacing: 6,
              activeDotColor: AppColors.primaryRed,
              dotColor: AppColors.divider,
            ),
          ),
        ),
      ],
    );
  }
}

class _PromoSlideCard extends StatelessWidget {
  const _PromoSlideCard({required this.slide, required this.onCta});

  final PromoSlide slide;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AppImage(
              asset: slide.image,
              fit: BoxFit.cover,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.65),
                    Colors.black.withValues(alpha: 0.15),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    slide.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1, end: 0),
                  const SizedBox(height: 4),
                  Text(
                    slide.subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12.5,
                    ),
                  ).animate().fadeIn(delay: 180.ms).slideX(begin: -0.08, end: 0),
                  const SizedBox(height: 10),
                  Material(
                    color: AppColors.primaryRed,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: onCta,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          slide.cta,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 260.ms).scale(
                        begin: const Offset(0.9, 0.9),
                        end: const Offset(1, 1),
                        curve: Curves.elasticOut,
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
