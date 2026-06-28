import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../main.dart' show ThemeManager, AccentTheme;

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class WealthAIScreen extends StatefulWidget {
  const WealthAIScreen({super.key});

  @override
  State<WealthAIScreen> createState() => _WealthAIScreenState();
}

class _WealthAIScreenState extends State<WealthAIScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  final List<String> _suggestions = [
    'How do I budget effectively?',
    'What is compound interest?',
    'How much emergency fund do I need?',
    'Explain inflation like I am 5',
    'Tips to reduce monthly expenses',
  ];

  @override
  void initState() {
    super.initState();
    // Add welcome message
    _messages.add(
      ChatMessage(
        text: "Hello! I'm your Wealth AI Advisor. How can I help you build smart financial habits today?",
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    HapticFeedback.lightImpact();
    _messageController.clear();

    setState(() {
      _messages.add(
        ChatMessage(
          text: trimmed,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _isTyping = true;
    });
    _scrollToBottom();

    // Simulate AI response
    Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      
      final reply = _getAIResponse(trimmed);
      setState(() {
        _isTyping = false;
        _messages.add(
          ChatMessage(
            text: reply,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
      _scrollToBottom();
      HapticFeedback.vibrate();
    });
  }

  String _getAIResponse(String query) {
    final q = query.toLowerCase();
    if (q.contains('budget')) {
      return "Effective budgeting starts with the 50/30/20 rule:\n• 50% for Needs (rent, bills, groceries)\n• 30% for Wants (dining out, hobbies, shopping)\n• 20% for Savings & Debt Paydown.\nTry tracking every transaction in Money-Mate to stay on budget!";
    } else if (q.contains('compound') || q.contains('interest')) {
      return "Compound interest is interest earned on interest! As your savings grow, the interest you earn compiles on top of your previous interest. Use the Compound Savings Planner in the 'Goals' tab to visualize how regular contributions compound over years!";
    } else if (q.contains('emergency') || q.contains('fund')) {
      return "An emergency fund should cover 3 to 6 months of your essential living expenses. Keep it in a high-yield savings account so it is liquid, safe, and earning a bit of interest. Start small by saving ₹500/week!";
    } else if (q.contains('inflation')) {
      return "Inflation is the general rise in prices over time, which reduces your purchasing power. If inflation is 5%, a ₹100 grocery basket will cost ₹105 next year. To beat inflation, invest your long-term savings in diversified portfolios or index funds.";
    } else if (q.contains('reduce') || q.contains('expense') || q.contains('save money')) {
      return "Here are 3 quick tips to lower your monthly expenses:\n1. Audit your subscriptions: Cancel services you haven't used in the last 30 days.\n2. Apply the 48-Hour Rule: Wait 48 hours before any non-essential purchase to curb impulse buys.\n3. Automate savings: Move money to savings on payday before you have a chance to spend it.";
    } else {
      return "Interesting question! Building financial freedom is about consistency. I suggest establishing a clear budget, utilizing compound growth, and regularly reviewing your expenses in Money-Mate. What financial target are we working towards next?";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeManager = Provider.of<ThemeManager>(context);
    final primaryColor = themeManager.accentTheme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.6),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text('Wealth AI Advisor'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Clear chat',
            onPressed: () {
              HapticFeedback.mediumImpact();
              setState(() {
                _messages.clear();
                _messages.add(
                  ChatMessage(
                    text: "Chat cleared. Ask me any financial planning questions!",
                    isUser: false,
                    timestamp: DateTime.now(),
                  ),
                );
              });
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              primaryColor.withOpacity(0.08),
              const Color(0xFF020204),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Glowing Header Card
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F13).withOpacity(0.8),
                        border: Border.all(
                          color: primaryColor.withOpacity(0.2),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: primaryColor.withOpacity(0.12),
                            child: Icon(Icons.auto_awesome_rounded, color: primaryColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Smart AI Advisory',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Ask questions about budgets, interest compounding, and saving tips.',
                                  style: TextStyle(color: Colors.white60, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Message List
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    return _buildMessageBubble(msg, primaryColor);
                  },
                ),
              ),
              // Typing Indicator
              if (_isTyping)
                Padding(
                  padding: const EdgeInsets.only(left: 20.0, bottom: 8.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Text(
                          'Wealth AI is typing',
                          style: TextStyle(color: primaryColor.withOpacity(0.8), fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                        const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Suggestions Row
              if (_messages.length == 1 && !_isTyping)
                SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _suggestions.length,
                    itemBuilder: (context, index) {
                      final suggest = _suggestions[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ActionChip(
                          backgroundColor: Colors.white.withOpacity(0.06),
                          side: BorderSide(color: primaryColor.withOpacity(0.2)),
                          label: Text(
                            suggest,
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                          onPressed: () => _handleSendMessage(suggest),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 6),
              // Chat Input Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: TextField(
                            controller: _messageController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Type your message...',
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
                              filled: true,
                              fillColor: const Color(0xFF0F0F13).withOpacity(0.8),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(color: primaryColor.withOpacity(0.2)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(color: primaryColor.withOpacity(0.15)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(color: primaryColor),
                              ),
                            ),
                            onSubmitted: _handleSendMessage,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.black,
                      mini: true,
                      onPressed: () => _handleSendMessage(_messageController.text),
                      child: const Icon(Icons.send_rounded, size: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, Color accentColor) {
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? accentColor.withOpacity(0.15)
              : const Color(0xFF0F0F13).withOpacity(0.85),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: Border.all(
            color: isUser
                ? accentColor.withOpacity(0.35)
                : Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.white.withOpacity(0.95),
            fontSize: 13.5,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
