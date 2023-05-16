import 'package:contacts_plus_plus/client_holder.dart';
import 'package:contacts_plus_plus/clients/messaging_client.dart';
import 'package:contacts_plus_plus/models/friend.dart';
import 'package:contacts_plus_plus/models/message.dart';
import 'package:contacts_plus_plus/widgets/friends/friend_online_status_indicator.dart';
import 'package:contacts_plus_plus/widgets/messages/messages_session_header.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'message_bubble.dart';

class MessagesList extends StatefulWidget {
  const MessagesList({required this.friend, super.key});

  final Friend friend;

  @override
  State<StatefulWidget> createState() => _MessagesListState();
}

class _MessagesListState extends State<MessagesList> with SingleTickerProviderStateMixin {
  final TextEditingController _messageTextController = TextEditingController();
  final ScrollController _sessionListScrollController = ScrollController();
  final ScrollController _messageScrollController = ScrollController();

  bool _isSendable = false;
  bool _showSessionListScrollChevron = false;
  bool _showBottomBarShadow = false;

  double get _shevronOpacity => _showSessionListScrollChevron ? 1.0 : 0.0;


  @override
  void dispose() {
    _messageTextController.dispose();
    _sessionListScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _sessionListScrollController.addListener(() {
      if (_sessionListScrollController.position.maxScrollExtent > 0 && !_showSessionListScrollChevron) {
        setState(() {
          _showSessionListScrollChevron = true;
        });
      }
      if (_sessionListScrollController.position.atEdge && _sessionListScrollController.position.pixels > 0
          && _showSessionListScrollChevron) {
        setState(() {
          _showSessionListScrollChevron = false;
        });
      }
    });
    _messageScrollController.addListener(() {
      if (!_messageScrollController.hasClients) return;
      if (_messageScrollController.position.atEdge && _messageScrollController.position.pixels == 0 &&
          _showBottomBarShadow) {
        setState(() {
          _showBottomBarShadow = false;
        });
      } else if (!_showBottomBarShadow) {
        setState(() {
          _showBottomBarShadow = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final apiClient = ClientHolder
        .of(context)
        .apiClient;
    var sessions = widget.friend.userStatus.activeSessions;
    final appBarColor = Theme
        .of(context)
        .colorScheme
        .surfaceVariant;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FriendOnlineStatusIndicator(userStatus: widget.friend.userStatus),
            const SizedBox(width: 8,),
            Text(widget.friend.username),
            if (widget.friend.isHeadless) Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Icon(Icons.dns, size: 18, color: Theme
                  .of(context)
                  .colorScheme
                  .onSecondaryContainer
                  .withAlpha(150),),
            ),
          ],
        ),
        scrolledUnderElevation: 0.0,
        backgroundColor: appBarColor,
      ),
      body: Column(
        children: [
          if (sessions.isNotEmpty) Container(
            constraints: const BoxConstraints(maxHeight: 64),
            decoration: BoxDecoration(
                color: appBarColor,
                border: const Border(top: BorderSide(width: 1, color: Colors.black26),)
            ),
            child: Stack(
              children: [
                ListView.builder(
                  controller: _sessionListScrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: sessions.length,
                  itemBuilder: (context, index) => SessionTile(session: sessions[index]),
                ),
                AnimatedOpacity(
                  opacity: _shevronOpacity,
                  curve: Curves.easeOut,
                  duration: const Duration(milliseconds: 200),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.only(left: 16, right: 4, top: 1, bottom: 1),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            appBarColor.withOpacity(0),
                            appBarColor,
                            appBarColor,
                          ],
                        ),
                      ),
                      height: double.infinity,
                      child: const Icon(Icons.chevron_right),
                    ),
                  ),
                )
              ],
            ),
          ),
          Expanded(
            child: Consumer<MessagingClient>(
              builder: (context, mClient, _) {
                final cache = mClient.getUserMessageCache(widget.friend.id);
                if (cache == null) {
                  return const Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      LinearProgressIndicator()
                    ],
                  );
                }
                if (cache.messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.message_outlined),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            "There are no messages here\nWhy not say hello?",
                            textAlign: TextAlign.center,
                            style: Theme
                                .of(context)
                                .textTheme
                                .titleMedium,
                          ),
                        )
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  controller: _messageScrollController,
                  reverse: true,
                  itemCount: cache.messages.length,
                  itemBuilder: (context, index) {
                    final entry = cache.messages[index];
                    if (index == cache.messages.length - 1) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: MessageBubble(message: entry,),
                      );
                    }
                    return MessageBubble(message: entry,);
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: AnimatedContainer(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              blurRadius: _showBottomBarShadow ? 8 : 0,
              color: Theme.of(context).shadowColor,
              offset: const Offset(0, 4),
            ),
          ],
          color: Theme.of(context).colorScheme.background,
        ),
        padding: MediaQuery
            .of(context)
            .viewInsets + const EdgeInsets.symmetric(horizontal: 4),
        duration: const Duration(milliseconds: 250),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  autocorrect: true,
                  controller: _messageTextController,
                  maxLines: 4,
                  minLines: 1,
                  onChanged: (text) {
                    if (text.isNotEmpty && !_isSendable) {
                      setState(() {
                        _isSendable = true;
                      });
                    } else if (text.isEmpty && _isSendable) {
                      setState(() {
                        _isSendable = false;
                      });
                    }
                  },
                  decoration: InputDecoration(
                      isDense: true,
                      hintText: "Send a message to ${widget.friend
                          .username}...",
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24)
                      )
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 4.0),
              child: Consumer<MessagingClient>(
                  builder: (context, mClient, _) {
                    return IconButton(
                      splashRadius: 24,
                      onPressed: _isSendable ? () async {
                        setState(() {
                          _isSendable = false;
                        });
                        final message = Message(
                          id: Message.generateId(),
                          recipientId: widget.friend.id,
                          senderId: apiClient.userId,
                          type: MessageType.text,
                          content: _messageTextController.text,
                          sendTime: DateTime.now().toUtc(),
                        );
                        try {
                          mClient.sendMessage(message);
                          _messageTextController.clear();
                          setState(() {});
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Failed to send message\n$e",
                                maxLines: null,
                              ),
                            ),
                          );
                          setState(() {
                            _isSendable = true;
                          });
                        }
                      } : null,
                      iconSize: 28,
                      icon: const Icon(Icons.send),
                    );
                  },
              ),
            )
          ],
        ),
      ),
    );
  }
}
