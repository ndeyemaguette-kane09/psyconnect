import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../models/companion_models.dart';
import '../services/companion_service.dart';

// Message affiché à l'écran. "flagged" ne sert qu'à l'affichage (mise en
// avant visuelle), ça ne change rien à l'appel API suivant.
class _DisplayMessage {
  _DisplayMessage({
    required this.role,
    required this.content,
    this.flagged = false,
  });

  final String role; // 'user' ou 'assistant'
  final String content;
  final bool flagged;
}

const _greeting =
    "Bonjour, je suis Xalaat (« pensée, réflexion » en wolof). Je "
    "suis là pour t'aider à te préparer avant ta première consultation : "
    "mettre des mots sur ce que tu ressens, répondre à tes questions sur le "
    "déroulement d'une thérapie, ou juste discuter si tu en as besoin. Je ne "
    "suis pas un professionnel de santé et je ne remplace pas un "
    "psychologue.";

class XalaatScreen extends StatefulWidget {
  const XalaatScreen({super.key});

  @override
  State<XalaatScreen> createState() => _XalaatScreenState();
}

class _XalaatScreenState extends State<XalaatScreen> {
  final _companionService = CompanionService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  final List<_DisplayMessage> _messages = [];
  final List<CompanionTurn> _history = [
    const CompanionTurn(role: 'assistant', content: _greeting),
  ];

  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
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

    // l'historique envoyé est celui d'AVANT ce message (le backend reçoit
    // "message" séparément et le rajoute lui-même côté prompt)
    final historyBeforeSend = List<CompanionTurn>.from(_history);

    setState(() {
      _messages.add(_DisplayMessage(role: 'user', content: content));
      _history.add(CompanionTurn(role: 'user', content: content));
      _textController.clear();
      _sending = true;
      _error = null;
    });
    _scrollToBottom();

    try {
      final response = await _companionService.chat(
        message: content,
        history: historyBeforeSend,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(_DisplayMessage(
          role: 'assistant',
          content: response.reply,
          flagged: response.flagged,
        ));
        _history.add(CompanionTurn(role: 'assistant', content: response.reply));
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException
            ? e.message
            : "Xalaat n'a pas pu répondre, réessaie dans un instant.";
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        titleSpacing: 0,
        title: const Row(
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: AppColors.tealLight,
              child: Icon(Icons.chat_bubble_outline_rounded,
                  color: AppColors.teal, size: 20),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Xalaat',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                Text('« pensée » en wolof',
                    style: TextStyle(fontSize: 13, color: AppColors.muted)),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildMessageList()),
            if (_error != null) _buildErrorBanner(),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      itemCount: _messages.length + 1 + (_sending ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == 0) {
          return const _ConfidentialNote();
        }
        if (i == _messages.length + 1) {
          return const _TypingBubble();
        }
        return _MessageBubble(message: _messages[i - 1]);
      },
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.errorBg,
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_error!,
                style: const TextStyle(fontSize: 14, color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      color: AppColors.background,
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
                hintText: 'Écrire à Xalaat',
                filled: true,
                fillColor: AppColors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide: const BorderSide(color: AppColors.teal),
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
              fixedSize: const Size(50, 50),
            ),
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.white),
                  )
                : const Icon(Icons.send_rounded, size: 21),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _DisplayMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.flagged) {
      return _FlaggedBubble(content: message.content);
    }

    final isMine = message.role == 'user';

    if (!isMine) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18, right: 12),
        child: Text(
          message.content,
          style: const TextStyle(
            fontSize: 16.5,
            height: 1.55,
            color: AppColors.text,
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18, left: 40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: AppColors.tealLight,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(6),
          ),
        ),
        child: Text(
          message.content,
          style: const TextStyle(
            fontSize: 16,
            height: 1.4,
            color: AppColors.tealDeep,
          ),
        ),
      ),
    );
  }
}

// réponse du garde-fou de sécurité (RiskDetectionService côté backend) :
// mise en avant visuellement, bien distincte d'une réponse normale du
// modèle, pour que les numéros d'urgence sautent aux yeux.
class _FlaggedBubble extends StatelessWidget {
  const _FlaggedBubble({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final lines = content
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final children = <Widget>[];
    var helplines = <String>[];
    void flushHelplines() {
      if (helplines.isEmpty) return;
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          children: [for (final l in helplines) _HelplineRow(line: l)],
        ),
      ));
      helplines = <String>[];
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isClosing = i == lines.length - 1 && !line.startsWith('- ');
      if (line.startsWith('- ')) {
        helplines.add(line.substring(2));
        continue;
      }
      flushHelplines();
      children.add(Padding(
        padding: EdgeInsets.only(top: isClosing ? 4 : 0, bottom: 10),
        child: Text(
          line,
          style: isClosing
              ? const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFA9CDBE),
                  height: 1.4,
                )
              : const TextStyle(
                  fontSize: 16,
                  color: Color(0xFFEDE8DF),
                  height: 1.5,
                ),
        ),
      ));
    }
    flushHelplines();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4, bottom: 18),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      decoration: BoxDecoration(
        color: AppColors.text,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, size: 16, color: Color(0xFFD9D2C5)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Message de l'équipe PsyConnect, pas de l'IA",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFD9D2C5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Tu n’as pas à porter ça seul·e.',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _HelplineRow extends StatelessWidget {
  const _HelplineRow({required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    var text = line.trim();
    if (text.endsWith(';') || text.endsWith('.')) {
      text = text.substring(0, text.length - 1).trim();
    }
    final sep = text.indexOf(' : ');
    var label = sep == -1 ? text : text.substring(0, sep).trim();
    final rest = sep == -1 ? '' : text.substring(sep + 3).trim();
    final comma = rest.indexOf(',');
    final number = comma == -1 ? rest : rest.substring(0, comma).trim();
    final detail = comma == -1 ? '' : rest.substring(comma + 1).trim();
    if (label.isNotEmpty) {
      label = label[0].toUpperCase() + label.substring(1);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.emergency,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.phone_outlined,
                color: Colors.white, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  number.isEmpty ? label : '$label · $number',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.muted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidentialNote extends StatelessWidget {
  const _ConfidentialNote();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 22),
      child: Text(
        "Rien n'est enregistré. Xalaat ne remplace pas un psychologue.",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13.5,
          color: AppColors.muted,
          height: 1.45,
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text(
            'Xalaat réfléchit…',
            style: TextStyle(fontSize: 14.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
