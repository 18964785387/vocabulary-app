import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../services/api_service.dart';
import '../models/models.dart';

class WordBookScreen extends StatefulWidget {
  const WordBookScreen({super.key});

  @override
  State<WordBookScreen> createState() => _WordBookScreenState();
}

class _WordBookScreenState extends State<WordBookScreen> {
  List<Word> _words = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadWords();
  }
  
  Future<void> _loadWords() async {
    setState(() => _isLoading = true);
    try {
      final wordsData = await ApiService.getWordBook();
      setState(() {
        _words = wordsData.map((e) => Word.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }
  
  Future<void> _removeWord(Word word) async {
    try {
      await ApiService.removeFromWordBook(word.id);
      setState(() => _words.removeWhere((w) => w.id == word.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已移除 ${word.word}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('移除失败: $e')),
        );
      }
    }
  }
  
  Future<void> _search(String keyword) async {
    if (keyword.isEmpty) {
      _loadWords();
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      final wordsData = await ApiService.searchWords(keyword);
      setState(() {
        _words = wordsData.map((e) => Word.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('生词本'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadWords),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索单词',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
              onSubmitted: _search,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _words.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.book_outlined, size: 80, color: Theme.of(context).colorScheme.outline),
                            const SizedBox(height: 16),
                            Text('生词本是空的', style: Theme.of(context).textTheme.titleLarge),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadWords,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _words.length,
                          itemBuilder: (context, index) => _buildWordCard(_words[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildWordCard(Word word) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Slidable(
        endActionPane: ActionPane(
          motion: const BehindMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => _removeWord(word),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: '移除',
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Row(
            children: [
              Text(word.word, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              if (word.phonetic.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text('/${word.phonetic}/', style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 14)),
              ],
            ],
          ),
          subtitle: Text(word.meaning, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(word.levelName, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onPrimaryContainer)),
          ),
        ),
      ),
    );
  }
}
