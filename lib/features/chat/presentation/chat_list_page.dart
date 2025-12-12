import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voyage/features/chat/domain/chat_message.dart';
import 'package:voyage/features/chat/application/chat_state.dart';
import 'package:voyage/core/theme/app_colors.dart';
import 'package:voyage/core/theme/app_tokens.dart';
import 'package:voyage/features/friends/application/friend_state.dart';

class ChatListPage extends ConsumerStatefulWidget {
  const ChatListPage({super.key});

  @override
  ConsumerState<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends ConsumerState<ChatListPage> {
  final TextEditingController _searchController =
      TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final messages = ref.watch(chatMessagesProvider);
    final chatNotifier =
        ref.read(chatMessagesProvider.notifier);
    final friends = ref.watch(friendListProvider);

    final Map<String, ChatMessage> lastByChatId = {};
    for (final m in messages) {
      final existing = lastByChatId[m.chatId];
      if (existing == null || m.createdAt.isAfter(existing.createdAt)) {
        lastByChatId[m.chatId] = m;
      }
    }

    final entries = lastByChatId.entries.toList()
      ..sort(
        (a, b) => b.value.createdAt.compareTo(a.value.createdAt),
      );

    final query =
        _searchController.text.trim().toLowerCase();

    final filteredEntries = query.isEmpty
        ? entries
        : entries.where((entry) {
            final chatId = entry.key;
            final friendMatch =
                friends.where((f) => f.id == chatId);
            final titleText =
                friendMatch.isNotEmpty ? friendMatch.first.name : chatId;
            return titleText.toLowerCase().contains(query);
          }).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('채팅'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic_none_outlined),
            tooltip: '무전 홈',
            onPressed: () {
              context.push('/ptt');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '친구/대화 검색',
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: '검색 지우기',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: filteredEntries.isEmpty
                ? Center(
                    child: Text(
                      query.isEmpty
                          ? '아직 대화가 없습니다'
                          : '검색 결과가 없습니다',
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(
                      bottom: AppSpacing.lg,
                    ),
                    itemCount: filteredEntries.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, index) {
                      final entry = filteredEntries[index];
                      final chatId = entry.key;
                      final lastMessage = entry.value;
                      final unreadCount =
                          chatNotifier.unreadCountForChat(chatId);

                      String? friendName;
                      final match =
                          friends.where((f) => f.id == chatId);
                      if (match.isNotEmpty) {
                        friendName = match.first.name;
                      }

                      final titleText = friendName ?? chatId;
                      final time = lastMessage.createdAt;
                      final hh = time.hour
                          .toString()
                          .padLeft(2, '0');
                      final mm = time.minute
                          .toString()
                          .padLeft(2, '0');
                      final timeLabel = '$hh:$mm';
                      final isVoice =
                          lastMessage.type == ChatMessageType.voice;
                      final subtitleText = isVoice
                          ? '음성 메시지'
                          : (lastMessage.text ?? '');

                      final initial = titleText.isNotEmpty
                          ? titleText.characters.first
                          : '?';

                      final bool isUnread = unreadCount > 0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: Card(
                          child: InkWell(
                            borderRadius:
                                BorderRadius.circular(AppRadii.lg),
                            onTap: () {
                              context.push('/chat/$chatId');
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient:
                                          AppColors.brandGradient,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      initial,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color:
                                                AppColors.textPrimary,
                                            fontWeight:
                                                FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                titleText,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.copyWith(
                                                      fontWeight:
                                                          isUnread
                                                              ? FontWeight
                                                                  .w700
                                                              : FontWeight
                                                                  .w600,
                                                    ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isVoice) ...[
                                              const SizedBox(
                                                width: AppSpacing.xs,
                                              ),
                                              const Icon(
                                                Icons.graphic_eq,
                                                size: 14,
                                                color:
                                                    AppColors.textSecondary,
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: AppSpacing.xxs),
                                        Text(
                                          subtitleText,
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        timeLabel,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall,
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      if (isUnread)
                                        Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.sm,
                                            vertical: AppSpacing.xxs,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius:
                                                BorderRadius.circular(
                                              AppRadii.pill,
                                            ),
                                          ),
                                          child: Text(
                                            unreadCount.toString(),
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: AppColors
                                                      .textPrimary,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
