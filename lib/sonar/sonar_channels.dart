import 'package:flutter/material.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/sonar/sonar.dart';
import 'package:hiddify/sonar/sonar_channel_guard.dart';
import 'package:hiddify/sonar/sonar_style.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Окно выбора канала: лучший сам, или любой руками, с живым пингом.
Future<void> showSonarChannels(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  barrierColor: const Color(Sonar.night0).withValues(alpha: .6),
  builder: (_) => const SonarChannelSheet(),
);

/// Канал по имени из подписки: что это и когда выбирать.
({String name, String hint, IconData icon}) sonarChannelInfo(OutboundInfo o) {
  final raw = o.tagDisplay.isNotEmpty ? o.tagDisplay : o.tag;
  final name = raw.replaceFirst(RegExp(r'^Sonar\s*·\s*'), '');
  final lower = raw.toLowerCase();
  if (o.isGroup || ['auto', 'lowest', 'urltest', 'balance'].any(lower.contains)) {
    return (name: 'Лучший канал', hint: 'Sonar сам держит живой канал', icon: Icons.auto_awesome_rounded);
  }
  if (name.contains('443') && name.contains('Запасной')) {
    return (name: name, hint: 'для кафе, отелей и офисов', icon: Icons.public_rounded);
  }
  if (name.contains('Запасной')) return (name: name, hint: 'если основной режут', icon: Icons.alt_route_rounded);
  if (name.contains('Игры')) {
    return (name: name, hint: 'UDP: игры и голос в Discord', icon: Icons.sports_esports_rounded);
  }
  if (name.contains('Основной')) {
    return (name: name, hint: 'для всего, проходит и в кафе', icon: Icons.bolt_rounded);
  }
  return (name: name, hint: '', icon: Icons.graphic_eq_rounded);
}

class SonarChannelSheet extends HookConsumerWidget {
  const SonarChannelSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(proxiesOverviewNotifierProvider);
    final g = group.valueOrNull;
    // Группы ядра (round-robin и «быстрейший») не показываем: «Лучший канал» здесь
    // это автовыбор Sonar, он держит один живой канал и не рвёт звонки
    final items = g == null ? <OutboundInfo>[] : sonarChannels(g);
    final guard = ref.watch(sonarChannelGuardProvider);
    final now = items.where((o) => o.tag == guard.current).firstOrNull;

    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(Sonar.night2), Color(Sonar.night1)],
        ),
        border: Border(top: BorderSide(color: Color(0x33DDE2E8))),
      ),
      padding: EdgeInsets.fromLTRB(18, 10, 18, 18 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: const Color(0x55DDE2E8), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text('Канал', style: SonarText.title.copyWith(fontSize: 24)),
          const SizedBox(height: 4),
          const Text(
            'Обычно ничего выбирать не нужно: Sonar держит один живой канал и сам переходит '
            'на запасной, только если этот перестал отвечать. Звонки при этом не рвутся.',
            style: SonarText.hint,
          ),
          const SizedBox(height: 16),
          if (g == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: sonarGlass(),
              child: const Text(
                'Подключитесь, и здесь появятся каналы с пингом: выбирать их можно, когда Sonar включён.',
                style: SonarText.body,
              ),
            )
          else ...[
            _ChannelTile(
              info: OutboundInfo(tag: 'auto', tagDisplay: 'auto', isGroup: true, urlTestDelay: now?.urlTestDelay ?? 0),
              hint: now == null ? null : 'Сейчас: ${sonarChannelInfo(now).name}',
              selected: guard.auto,
              onTap: () async {
                await ref.read(sonarChannelGuardProvider.notifier).choose('');
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: 8),
            for (final o in items) ...[
              _ChannelTile(
                info: o,
                selected: !guard.auto && o.tag == g.selected,
                onTap: () async {
                  await ref.read(sonarChannelGuardProvider.notifier).choose(o.tag);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 4),
            Center(
              child: TextButton.icon(
                onPressed: () => ref.read(proxiesOverviewNotifierProvider.notifier).urlTest(g.tag),
                icon: const Icon(Icons.speed_rounded, size: 18),
                label: const Text('Проверить пинг', style: TextStyle(fontFamily: 'Jost', fontSize: 15)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({required this.info, required this.selected, required this.onTap, this.hint});

  final OutboundInfo info;
  final bool selected;
  final VoidCallback onTap;

  /// вместо подсказки по имени канала
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final c = sonarChannelInfo(info);
    final hint = this.hint ?? c.hint;
    final ms = info.urlTestDelay;
    final valid = ms > 0 && ms < 65000;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: selected ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: sonarGlass(active: selected, glow: const Color(0xFF5EEAD4)),
          child: Row(
            children: [
              Icon(c.icon, size: 22, color: selected ? const Color(0xFF5EEAD4) : const Color(Sonar.feather)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, style: SonarText.item),
                    if (hint.isNotEmpty) Text(hint, style: SonarText.hint),
                  ],
                ),
              ),
              Text(
                valid ? '$ms мс' : (ms == 0 ? '…' : 'нет ответа'),
                style: SonarText.value.copyWith(
                  fontSize: 14,
                  color: valid ? sonarPingColor(ms) : const Color(Sonar.feather),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: const Icon(Icons.check_circle_rounded, size: 20, color: Color(0xFF5EEAD4)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
