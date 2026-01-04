import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: json['role'] as String,
        content: json['content'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class ChatService {
  // ⚠️ SECURITY NOTE: In production, store API key securely (e.g., Firebase Remote Config, environment variables, or secure storage)
  // The API key is loaded from .env file or can be set via --dart-define=OPENAI_API_KEY=your_key_here
  static String get _apiKey {
    // First try to get from .env file
    final envKey = dotenv.env['OPENAI_API_KEY'];
    if (envKey != null && envKey.isNotEmpty) {
      return envKey;
    }
    // Fallback to dart-define (for CI/CD or command line)
    return const String.fromEnvironment(
      'OPENAI_API_KEY',
      defaultValue: '', // API key must be provided via .env file or --dart-define
    );
  }
  static const String _endpoint = 'https://api.openai.com/v1/chat/completions';
  static const String _model = 'gpt-4o-mini';
  static const int _maxTokens = 500; // Increased for better responses
  static const int _maxHistoryMessages = 10; // Keep last 10 messages for context

  static const String _refusal =
      "I can only assist with health-related questions, safety, and wellbeing. Please ask a medical or wellness question.";

  // Conversation history for context
  final List<ChatMessage> _conversationHistory = [];

  /// Send a message with conversation context
  Future<String> sendMessage(String prompt, {List<ChatMessage>? history}) async {
    final apiKey = _apiKey;
    if (apiKey.isEmpty) {
      throw Exception("OpenAI API key is missing. Please create a .env file with OPENAI_API_KEY=your_key_here or use --dart-define=OPENAI_API_KEY=your_key_here");
    }
    if (prompt.trim().isEmpty) return _refusal;

    // Build conversation history (system + last N messages + current)
    final List<Map<String, String>> messages = [
      {
        "role": "system",
        "content":
            "You are a compassionate, evidence-informed health assistant. Only answer health, medical, wellness, or clinical workflow questions. If the user asks about anything non-health (finance, code, sports, politics, general chit-chat), politely redirect: '$_refusal'. Provide clear, safe guidance with appropriate disclaimers that this is not medical advice and emergencies should contact local emergency services. Be concise but thorough, and maintain a warm, supportive tone.",
      },
    ];

    // Add conversation history (last N messages)
    final historyToUse = history ?? _conversationHistory;
    final recentHistory = historyToUse.length > _maxHistoryMessages
        ? historyToUse.sublist(historyToUse.length - _maxHistoryMessages)
        : historyToUse;

    for (var msg in recentHistory) {
      messages.add({
        "role": msg.role,
        "content": msg.content,
      });
    }

    // Add current user message
    messages.add({"role": "user", "content": prompt});

    final payload = {
      "model": _model,
      "temperature": 0.5, // Slightly increased for more natural responses
      "max_tokens": _maxTokens,
      "messages": messages,
    };

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode(payload),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception("Request timeout. Please check your internet connection."),
      );

      if (response.statusCode == 401) {
        throw Exception("Invalid API key. Please check your configuration.");
      } else if (response.statusCode == 429) {
        throw Exception("Rate limit exceeded. Please try again in a moment.");
      } else if (response.statusCode != 200) {
        final errorBody = jsonDecode(response.body);
        final errorMsg = errorBody['error']?['message'] ?? 'Unknown error';
        throw Exception("Chat request failed: $errorMsg (${response.statusCode})");
      }

      final data = jsonDecode(response.body);
      final content = data["choices"]?[0]?["message"]?["content"];
      if (content == null || content.toString().isEmpty) {
        return _refusal;
      }

      final responseText = content.toString().trim();

      // Update conversation history
      _conversationHistory.add(ChatMessage(role: 'user', content: prompt));
      _conversationHistory.add(ChatMessage(role: 'assistant', content: responseText));

      // Keep history manageable
      if (_conversationHistory.length > _maxHistoryMessages * 2) {
        _conversationHistory.removeRange(0, _conversationHistory.length - _maxHistoryMessages * 2);
      }

      return responseText;
    } on http.ClientException {
      throw Exception("Network error. Please check your internet connection.");
    } catch (e) {
      if (e.toString().contains("timeout") || e.toString().contains("Network")) {
        rethrow;
      }
      throw Exception("Failed to get response: ${e.toString()}");
    }
  }

  /// Clear conversation history
  void clearHistory() {
    _conversationHistory.clear();
  }

  /// Get current conversation history
  List<ChatMessage> getHistory() => List.unmodifiable(_conversationHistory);

  /// Set conversation history (useful for restoring from storage)
  void setHistory(List<ChatMessage> history) {
    _conversationHistory.clear();
    _conversationHistory.addAll(history);
  }
}
