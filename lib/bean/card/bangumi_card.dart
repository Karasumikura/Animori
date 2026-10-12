import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:animori/bean/card/network_img_layer.dart';
import 'package:animori/bean/dialog/dialog_helper.dart';
import 'package:animori/modules/bangumi/bangumi_item.dart';

class BangumiCardV extends StatelessWidget {
  const BangumiCardV({
    super.key,
    required this.bangumiItem,
    this.canTap = true,
    this.enableHero = true,
  });
  final BangumiItem bangumiItem;
  final bool canTap;
  final bool enableHero;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final image = LayoutBuilder(
      builder: (context, constraints) => NetworkImgLayer(
        src: bangumiItem.images['large'] ?? '',
        width: constraints.maxWidth,
        height: constraints.maxHeight,
      ),
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          if (!canTap) {
            AnimoriDialog.showToast(message: '编辑模式');
            return;
          }
          context.pushNamed('/info/', arguments: bangumiItem);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    enableHero
                        ? Hero(
                            tag: bangumiItem.id,
                            flightShuttleBuilder:
                                NetworkImgLayer.heroFlightShuttleBuilder,
                            child: image,
                          )
                        : image,
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0x88000000)],
                          stops: [0.65, 1],
                        ),
                      ),
                    ),
                    if (bangumiItem.ratingScore > 0)
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.48),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFFFD88A),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                bangumiItem.ratingScore.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(3, 10, 3, 3),
              child: Text(
                bangumiItem.nameCn.isEmpty
                    ? bangumiItem.name
                    : bangumiItem.nameCn,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                bangumiItem.airDate.isEmpty ? '探索这部作品' : bangumiItem.airDate,
                maxLines: 1,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BangumiContent extends StatelessWidget {
  const BangumiContent({super.key, required this.bangumiItem});
  final BangumiItem bangumiItem;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        bangumiItem.nameCn.isEmpty ? bangumiItem.name : bangumiItem.nameCn,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}
