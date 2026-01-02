import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/chat_service.dart';
import '../services/database_helper.dart';

class HealthChatScreen extends StatefulWidget {
  const HealthChatScreen({super.key});

  @override
  State<HealthChatScreen> createState() => _HealthChatScreenState();
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? error;
  final bool isSending;

  _ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.error,
    this.isSending = false,
  }) : timestamp = timestamp ?? DateTime.now();

  _ChatMessage copyWith({
    String? text,
    bool? isUser,
    DateTime? timestamp,
    String? error,
    bool? isSending,
  }) {
    return _ChatMessage(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      error: error ?? this.error,
      isSending: isSending ?? this.isSending,
    );
  }
}

class _HealthChatScreenState extends State<HealthChatScreen> {
  final ChatService _chatService = ChatService();
  final DatabaseHelper _db = DatabaseHelper();
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChatHistory() async {
    try {
      final history = await _db.getChatHistory();
      if (history.isEmpty) return;

      setState(() {
        _messages.clear();
        for (var msg in history) {
          _messages.add(_ChatMessage(
            text: msg['content'] as String,
            isUser: msg['role'] == 'user',
            timestamp: DateTime.parse(msg['timestamp'] as String),
          ));
        }
      });

      // Restore conversation history in chat service
      final chatHistory = history.map((msg) => ChatMessage(
            role: msg['role'] as String,
            content: msg['content'] as String,
            timestamp: DateTime.parse(msg['timestamp'] as String),
          )).toList();
      _chatService.setHistory(chatHistory);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      print("Error loading chat history: $e");
    }
  }

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isLoading) return;

    final userMessage = _ChatMessage(text: text, isUser: true);
    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
      _isTyping = true;
    });
    _inputCtrl.clear();
    _scrollToBottom();

    // Save user message to database
    await _db.saveChatMessage(role: 'user', content: text);

    try {
      final reply = await _chatService.sendMessage(text);
      if (!mounted) return;

      final botMessage = _ChatMessage(text: reply, isUser: false);
      setState(() {
        _isLoading = false;
        _isTyping = false;
        // User message already added, just add bot response
        _messages.add(botMessage);
      });

      // Save bot response to database
      await _db.saveChatMessage(role: 'assistant', content: reply);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isTyping = false;
        // User message already added, add error message
        _messages.add(_ChatMessage(
          text: "Failed to send message: ${e.toString()}",
          isUser: false,
          error: e.toString(),
        ));
      });
      _scrollToBottom();
    }
  }

  Future<void> _retryMessage(int userMessageIndex) async {
    if (userMessageIndex < 0 || userMessageIndex >= _messages.length) return;
    final userMessage = _messages[userMessageIndex];
    if (!userMessage.isUser) return;

    // Remove error message if it exists
    if (userMessageIndex + 1 < _messages.length && _messages[userMessageIndex + 1].error != null) {
      setState(() {
        _messages.removeAt(userMessageIndex + 1);
      });
    }

    // Resend the message
    setState(() {
      _isLoading = true;
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final reply = await _chatService.sendMessage(userMessage.text);
      if (!mounted) return;

      final botMessage = _ChatMessage(text: reply, isUser: false);
      setState(() {
        _isLoading = false;
        _isTyping = false;
        _messages.add(botMessage);
      });

      // Save bot response to database
      await _db.saveChatMessage(role: 'assistant', content: reply);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isTyping = false;
        _messages.add(_ChatMessage(
          text: "Failed to send message: ${e.toString()}",
          isUser: false,
          error: e.toString(),
        ));
      });
      _scrollToBottom();
    }
  }

  Future<void> _clearChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear Chat History"),
        content: const Text("Are you sure you want to clear all chat messages? This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Clear"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _db.clearChatHistory();
      _chatService.clearHistory();
      setState(() {
        _messages.clear();
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _copyMessage(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Message copied to clipboard"),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareMessage(String text) async {
    // Note: Requires share_plus package for full functionality
    // For now, just copy to clipboard
    await _copyMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Health Chatbot"),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: "Clear chat",
              onPressed: _clearChat,
            ),
        ],
      ),
      body: Column(
        children: [
          _disclaimerBanner(),
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isTyping) {
                        return _buildTypingIndicator();
                      }
                      return _buildMessageBubble(_messages[index], index);
                    },
                  ),
          ),
          _inputArea(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            "Start a conversation",
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            "Ask me anything about health and wellness",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg, int index) {
    final isError = msg.error != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!msg.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.teal.shade100,
              child: Icon(Icons.medical_services, size: 18, color: Colors.teal.shade700),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: isError && index > 0 && _messages[index - 1].isUser
                      ? () => _retryMessage(index - 1)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isError
                          ? Colors.red.shade50
                          : msg.isUser
                              ? Colors.blue.shade600
                              : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: isError ? Border.all(color: Colors.red.shade300) : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.text,
                          style: TextStyle(
                            color: isError
                                ? Colors.red.shade900
                                : msg.isUser
                                    ? Colors.white
                                    : Colors.black87,
                            fontSize: 15,
                          ),
                        ),
                        if (isError) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh, size: 14, color: Colors.red.shade700),
                              const SizedBox(width: 4),
                              Text(
                                "Tap to retry",
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTimestamp(msg.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    if (!msg.isUser && !isError) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.copy, size: 16, color: Colors.grey.shade600),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _copyMessage(msg.text),
                        tooltip: "Copy message",
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (msg.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue.shade100,
              child: Icon(Icons.person, size: 18, color: Colors.blue.shade700),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.teal.shade100,
            child: Icon(Icons.medical_services, size: 18, color: Colors.teal.shade700),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDot(0),
                const SizedBox(width: 4),
                _buildTypingDot(1),
                const SizedBox(width: 4),
                _buildTypingDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        final delay = index * 0.2;
        final animatedValue = ((value + delay) % 1.0);
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey.shade400.withOpacity(0.3 + animatedValue * 0.7),
            shape: BoxShape.circle,
          ),
        );
      },
      onEnd: () {
        if (_isTyping && mounted) {
          setState(() {});
        }
      },
    );
  }

  Widget _disclaimerBanner() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.health_and_safety, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "For health questions only. This is not medical advice—contact emergency services for urgent issues.",
              style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputArea() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                maxLines: 4,
                minLines: 1,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  hintText: "Ask a health question...",
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: _isLoading ? Colors.grey.shade300 : Colors.blue.shade600,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _isLoading ? null : _sendMessage,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white),
                tooltip: "Send message",
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return "Just now";
    } else if (difference.inHours < 1) {
      return "${difference.inMinutes}m ago";
    } else if (difference.inDays < 1) {
      return "${difference.inHours}h ago";
    } else if (difference.inDays < 7) {
      return "${difference.inDays}d ago";
    } else {
      return DateFormat('MMM d, h:mm a').format(timestamp);
    }
  }
}
