import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/messaging_models.dart';
import '../services/messaging_service.dart';

// ecran de discussion patient <-> psy.
// pas de websocket cote backend, le "temps reel" c'est juste un polling
// toutes les 6 secondes — ca suffit pour une messagerie de cabinet
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherDisplayName,
  });

  final int conversationId;
  final String otherDisplayName;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messagingService = MessagingService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  Timer? _pollTimer;
  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  int? _myAuthUserId;

  @override
  void initState() {
    super.initState();
    _myAuthUserId = context.read<AuthProvider>().session?.userId;
    _loadMessages(initial: true);
    _pollTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _loadMessages(initial: false),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({required bool initial}) async {
    try {
      final messages = await _messagingService.getMessages(widget.conversationId);
      if (!mounted) return;

      final hadNewMessages = messages.length != _messages.length;

      setState(() {
        _messages = messages;
        _loading = false;
        _error = null;
      });

      // marque lu dès l'ouverture, et a chaque nouveau message recu tant
      // que l'ecran reste ouvert
      if (initial || hadNewMessages) {
        unawaited(_messagingService.markConversationRead(widget.conversationId));
      }

      if (hadNewMessages) {
        _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (initial) _error = 'Impossible de charger la conversation.';
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final content = _textController.text.trim();
    if (content.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final sent = await _messagingService.sendMessage(widget.conversationId, content);
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, sent];
        _textController.clear();
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Le message n'a pas pu être envoyé.")),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.otherDisplayName),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildBody()),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, color: AppColors.muted, size: 36),
              const SizedBox(height: 8),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _loadMessages(initial: true),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }
    if (_messages.isEmpty) {
      return const Center(
        child: Text(
          'Aucun message pour le moment. Dites bonjour !',
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final message = _messages[i];
        final isMine = message.senderAuthUserId == _myAuthUserId;
        return _MessageBubble(message: message, isMine: isMine);
      },
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.tealMid)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Écrire un message…',
                filled: true,
                fillColor: AppColors.tealLight,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sending ? null : _send,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.teal,
              foregroundColor: AppColors.white,
            ),
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.white),
                  )
                : const Icon(Icons.send_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final time = '${message.sentAt.hour.toString().padLeft(2, '0')}:'
        '${message.sentAt.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMine ? AppColors.teal : AppColors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMine ? 14 : 2),
            bottomRight: Radius.circular(isMine ? 2 : 14),
          ),
          border: isMine ? null : Border.all(color: AppColors.tealMid),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.content,
              style: TextStyle(
                  color: isMine ? AppColors.white : AppColors.text),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                fontSize: 10,
                color: isMine
                    ? AppColors.white.withValues(alpha: 0.75)
                    : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
