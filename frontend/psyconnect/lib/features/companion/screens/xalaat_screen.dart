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

// Écran de discussion avec Xalaat, le compagnon IA de préparation.
//
// IMPORTANT (confidentialité) : contrairement à ChatScreen (messagerie
// patient/psy), rien ici n'est persisté nulle part — pas de stockage local,
// pas d'historique côté serveur. _messages et _history vivent uniquement en
// mémoire et disparaissent à la fermeture de l'écran. Ne pas introduire de
// SharedPreferences / DB locale / fichier pour cet écran.
class XalaatScreen extends StatefulWidget {
  const XalaatScreen({super.key});

  @override
  State<XalaatScreen> createState() => _XalaatScreenState();
}

class _XalaatScreenState extends State<XalaatScreen> {
  final _companionService = CompanionService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  final List<_DisplayMessage> _messages = [
    _DisplayMessage(role: 'assistant', content: _greeting),
  ];
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
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        titleSpacing: 0,
        title: const Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.tealLight,
              child: Icon(Icons.spa_outlined, color: AppColors.teal, size: 18),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Xalaat', style: TextStyle(fontWeight: FontWeight.w700)),
                Text('Compagnon de préparation',
                    style: TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildDisclaimer(),
            Expanded(child: _buildMessageList()),
            if (_error != null) _buildErrorBanner(),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.tealLight,
      child: const Row(
        children: [
          Icon(Icons.lock_outline, size: 14, color: AppColors.tealDark),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              "Conversation confidentielle, jamais enregistrée. Xalaat ne "
              "remplace pas un psychologue.",
              style: TextStyle(fontSize: 11, color: AppColors.tealDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length + (_sending ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == _messages.length) {
          return const _TypingBubble();
        }
        return _MessageBubble(message: _messages[i]);
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
          const Icon(Icons.error_outline, size: 16, color: AppColors.rose),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_error!,
                style: const TextStyle(fontSize: 12, color: AppColors.rose)),
          ),
        ],
      ),
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
                hintText: 'Écrire à Xalaat…',
                filled: true,
                fillColor: AppColors.tealLight,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
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
  const _MessageBubble({required this.message});

  final _DisplayMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.flagged) {
      return _FlaggedBubble(content: message.content);
    }

    final isMine = message.role == 'user';

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isMine ? AppColors.teal : AppColors.white,
          border: isMine ? null : Border.all(color: AppColors.tealMid),
        ),
        child: Text(
          message.content,
          style: TextStyle(color: isMine ? AppColors.white : AppColors.text),
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.goldLight,
        border: Border.all(color: AppColors.gold),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.support_agent, color: AppColors.gold, size: 18),
              SizedBox(width: 8),
              Text('Aide immédiate',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Text(content,
              style: const TextStyle(color: AppColors.text, height: 1.4)),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.tealMid),
        ),
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
