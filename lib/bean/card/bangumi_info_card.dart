import 'package:flutter/material.dart';
import 'package:animori/bean/widget/animori_design.dart';
import 'package:animori/bean/widget/collect_button.dart';
import 'package:animori/modules/bangumi/bangumi_item.dart';
import 'package:animori/bean/card/network_img_layer.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:skeletonizer/skeletonizer.dart';

// 视频卡片 - 水平布局
class BangumiInfoCardV extends StatefulWidget {
  const BangumiInfoCardV({
    super.key,
    required this.bangumiItem,
    required this.isLoading,
    required this.showRating,
  });

  final BangumiItem bangumiItem;
  final bool isLoading;
  final bool showRating;

  @override
  State<BangumiInfoCardV> createState() => _BangumiInfoCardVState();
}

class _BangumiInfoCardVState extends State<BangumiInfoCardV> {
  int touchedIndex = -1;

  Widget get voteBarChart {
    return Flexible(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('  评分透视:'),
          SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 2,
            child: BarChart(
              duration: Duration(milliseconds: 80),
              BarChartData(
                // alignment: BarChartAlignment.spaceEvenly,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
                barTouchData: BarTouchData(
                  touchCallback: (FlTouchEvent event, barTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          barTouchResponse == null ||
                          barTouchResponse.spot == null) {
                        touchedIndex = -1;
                        return;
                      }
                      touchedIndex =
                          barTouchResponse.spot!.touchedBarGroupIndex;
                    });
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                        Theme.of(context).colorScheme.inverseSurface,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      var percentage =
                          widget.bangumiItem.votesCount[groupIndex] /
                          widget.bangumiItem.votes *
                          100;
                      return BarTooltipItem(
                        '${percentage.toStringAsFixed(2)}% (${widget.bangumiItem.votesCount[groupIndex]}人)',
                        TextStyle(
                          color: Theme.of(context).colorScheme.onInverseSurface,
                        ),
                      );
                    },
                  ),
                ),
                barGroups: List<BarChartGroupData>.generate(
                  10,
                  (i) => BarChartGroupData(
                    x: i + 1,
                    barRods: [
                      BarChartRodData(
                        toY: widget.bangumiItem.votesCount[i].toDouble(),
                        color: touchedIndex == i
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).disabledColor,
                        width: 20,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(5),
                        ),
                      ),
                    ],
                    // showingTooltipIndicators: [0],
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        meta: meta,
                        space: 10,
                        child: Text(value.toInt().toString()),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(),
                  leftTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.bangumiItem;
    final theme = Theme.of(context);
    return SizedBox(
      height: 260,
      child: AnimoriPanel(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            SizedBox(
              width: 132,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Hero(
                  tag: item.id,
                  flightShuttleBuilder:
                      NetworkImgLayer.heroFlightShuttleBuilder,
                  child: NetworkImgLayer(
                    src: item.images['large'] ?? '',
                    width: 132,
                    height: 224,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Skeletonizer(
                enabled: widget.isLoading,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ANIMORI / DETAILS',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Text(
                        item.nameCn.isEmpty ? item.name : item.nameCn,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (widget.showRating)
                      Text(
                        '★ ${item.ratingScore.toStringAsFixed(1)}   ·   #${item.rank}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      item.airDate.isEmpty ? '放送信息待更新' : '${item.airDate} 开始放送',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    CollectButton.extend(bangumiItem: item),
                  ],
                ),
              ),
            ),
            if (widget.showRating &&
                MediaQuery.sizeOf(context).width >= 900 &&
                !widget.isLoading &&
                item.votes > 0 &&
                item.votesCount.length == 10) ...[
              const SizedBox(width: 24),
              voteBarChart,
            ],
          ],
        ),
      ),
    );
  }
}
