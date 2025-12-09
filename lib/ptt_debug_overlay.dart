import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/friend_state.dart';
import 'package:voyage/ptt_debug_log.dart';
import 'package:voyage/ptt_metrics.dart';
import 'package:voyage/ptt/ptt_mode_provider.dart';

class PttDebugOverlay extends ConsumerWidget {
  const PttDebugOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(pttModeProvider);
    final currentFriendId = ref.watch(currentPttFriendIdProvider);
    final friends = ref.watch(friendListProvider);
    final pttAllowMap = ref.watch(friendPttAllowProvider);
    final blockMap = ref.watch(friendBlockProvider);
    final metrics = ref.watch(pttMetricsProvider);
    final logs = ref.watch(pttDebugLogProvider);

    final friend = currentFriendId == null
        ? null
        : friends.where((f) => f.id == currentFriendId).isEmpty
            ? null
            : friends.firstWhere((f) => f.id == currentFriendId);

    final friendName = friend?.name ?? '(none)';
    final allow = currentFriendId != null &&
        (pttAllowMap[currentFriendId] ?? false);
    final blocked = currentFriendId != null &&
        (blockMap[currentFriendId] ?? false);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final surface = colorScheme.surface.withOpacity(0.9);
    final textStyle =
        theme.textTheme.bodySmall ?? const TextStyle(fontSize: 11);

    final entries = logs.reversed.take(20).toList();

    return Align(
      alignment: Alignment.bottomRight,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(8),
        width: 280,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
            ),
          ],
        ),
        child: DefaultTextStyle(
          style: textStyle,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PTT Debug',
                style: textStyle.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Mode: ${mode.name} | Friend: $friendName (${currentFriendId ?? '-'})',
              ),
              Text(
                'Allow: ${allow ? 'ON' : 'OFF'} | Block: ${blocked ? 'ON' : 'OFF'}',
              ),
              const SizedBox(height: 4),
              Text(
                'Total=${metrics.totalCount}  '
                'Success=${metrics.successCount}  '
                'Error=${metrics.errorCount}',
              ),
              Text(
                'TTP(ms): last=${metrics.lastTtpMillis}  '
                'p50=${metrics.p50TtpMillis}  '
                'p95=${metrics.p95TtpMillis}',
              ),
              const SizedBox(height: 4),
              const Divider(height: 1),
              const SizedBox(height: 4),
              SizedBox(
                height: 140,
                child: ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final e = entries[index];
                    final time = _formatTime(e.at);
                    return Text(
                      '$time ${e.tag} ${e.message}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
