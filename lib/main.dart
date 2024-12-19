import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'import_script.dart';
import 'dart:math' as math;

final logger = Logger('IdeaBamberg');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });
  
  try {
    logger.info('Starte Firebase-Initialisierung...');
    
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    logger.info('Firebase wurde erfolgreich initialisiert');
    
    if (!kIsWeb) {
      FirebaseDatabase.instance.setPersistenceEnabled(false);
    }
    FirebaseDatabase.instance.setLoggingEnabled(true);
    
    runApp(const MyApp());
  } catch (e, stackTrace) {
    logger.severe('Fehler bei der Firebase-Initialisierung: $e');
    logger.severe('Stacktrace: $stackTrace');
    runApp(const ErrorApp());
  }
}

class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Fehler'),
          backgroundColor: Colors.red,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Fehler beim Laden der App',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Bitte überprüfen Sie Ihre Internetverbindung und versuchen Sie es später erneut.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  main();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Idea {
  final String id;
  final String category;
  final String title;
  final String problem;
  final String solution;
  final int upVotes;
  final int downVotes;
  final Map<String, bool> upVoters;
  final Map<String, bool> downVoters;

  Idea({
    required this.id,
    required this.category,
    required this.title,
    required this.problem,
    required this.solution,
    required this.upVotes,
    required this.downVotes,
    required this.upVoters,
    required this.downVoters,
  });

  int get score => upVotes - downVotes;

  factory Idea.fromJson(String id, Map<dynamic, dynamic> json) {
    return Idea(
      id: id,
      category: json['category'] ?? '',
      title: json['title'] ?? '',
      problem: json['problem'] ?? '',
      solution: json['solution'] ?? '',
      upVotes: json['upVotes'] ?? 0,
      downVotes: json['downVotes'] ?? 0,
      upVoters: Map<String, bool>.from(json['upVoters'] ?? {}),
      downVoters: Map<String, bool>.from(json['downVoters'] ?? {}),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bamberg Ideen',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00838F), // Türkis als Hauptfarbe
          secondary: const Color(0xFFFF6B6B), // Koralle als Akzentfarbe
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: const CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: const IdeaList(),
    );
  }
}

class IdeaList extends StatefulWidget {
  const IdeaList({super.key});

  @override
  State<IdeaList> createState() => _IdeaListState();
}

class _IdeaListState extends State<IdeaList> with SingleTickerProviderStateMixin {
  List<Idea> ideas = [];
  bool isLoading = true;
  late final DatabaseReference _database;
  late final IdeaImporter _importer;
  StreamSubscription<DatabaseEvent>? _subscription;
  String? _userId;
  late AnimationController _animationController;
  late Animation<double> _animation;
  late final ScaffoldMessengerState? _scaffoldMessenger;

  @override
  void initState() {
    super.initState();
    _database = FirebaseDatabase.instance.ref().child('ideas');
    _importer = IdeaImporter();
    _initUserId();
    _loadData();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  Future<void> _initUserId() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id');
    if (_userId == null) {
      _userId = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString('user_id', _userId!);
    }
  }

  void _showError(String message) {
    if (mounted && _scaffoldMessenger != null) {
      _scaffoldMessenger!.showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _loadData() {
    setState(() => isLoading = true);
    try {
      _subscription?.cancel();
      _subscription = _database.onValue.listen(
        (event) {
          if (!mounted) return;
          
          setState(() {
            try {
              if (event.snapshot.value != null) {
                final Map<dynamic, dynamic> values = 
                    event.snapshot.value as Map<dynamic, dynamic>;
                
                ideas = values.entries.map((entry) {
                  return Idea.fromJson(entry.key, entry.value as Map<dynamic, dynamic>);
                }).toList();
                
                ideas.sort((a, b) => b.score.compareTo(a.score));
              } else {
                ideas = [];
              }
            } catch (e, stackTrace) {
              logger.severe('Fehler beim Verarbeiten der Daten: $e');
              logger.severe('Stacktrace: $stackTrace');
              ideas = [];
            } finally {
              isLoading = false;
            }
          });
        },
        onError: (error, stackTrace) {
          logger.severe('Fehler beim Laden der Daten: $error');
          logger.severe('Stacktrace: $stackTrace');
          if (mounted) {
            setState(() {
              ideas = [];
              isLoading = false;
            });
            _showError('Fehler beim Laden der Daten. Bitte versuchen Sie es später erneut.');
          }
        },
        cancelOnError: false,
      );
    } catch (e, stackTrace) {
      logger.severe('Fehler beim Einrichten des Datenlisteners: $e');
      logger.severe('Stacktrace: $stackTrace');
      if (mounted) {
        setState(() => isLoading = false);
        _showError('Fehler beim Laden der Daten. Bitte versuchen Sie es später erneut.');
      }
    }
  }

  Future<void> _vote(Idea idea, bool isUpvote) async {
    if (_userId == null) return;

    try {
      final hasVoted = isUpvote ? 
          idea.upVoters.containsKey(_userId) : 
          idea.downVoters.containsKey(_userId);
      
      final oppositeVoted = isUpvote ? 
          idea.downVoters.containsKey(_userId) : 
          idea.upVoters.containsKey(_userId);

      final updates = <String, dynamic>{};
      
      // Entferne bestehende Votes
      if (hasVoted) {
        updates['${isUpvote ? "upVoters" : "downVoters"}/$_userId'] = null;
        updates[isUpvote ? 'upVotes' : 'downVotes'] = ServerValue.increment(-1);
      } else {
        // Füge neuen Vote hinzu
        updates['${isUpvote ? "upVoters" : "downVoters"}/$_userId'] = true;
        updates[isUpvote ? 'upVotes' : 'downVotes'] = ServerValue.increment(1);
        
        // Entferne gegenüberliegenden Vote falls vorhanden
        if (oppositeVoted) {
          updates['${!isUpvote ? "upVoters" : "downVoters"}/$_userId'] = null;
          updates[!isUpvote ? 'upVotes' : 'downVotes'] = ServerValue.increment(-1);
        }
      }
      
      await _database.child(idea.id).update(updates);
    } catch (e) {
      logger.severe('Fehler beim Abstimmen: $e');
      _showError('Fehler beim Abstimmen');
    }
  }

  void _showFullText(BuildContext context, String title, String text) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(text),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Schließen'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addSolution(Idea idea) async {
    final TextEditingController solutionController = TextEditingController();
    
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Neue Lösung hinzufügen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Beschreiben Sie Ihre Lösungsidee:'),
            const SizedBox(height: 8),
            TextField(
              controller: solutionController,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Ihre Lösung...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    if (result == true && solutionController.text.isNotEmpty) {
      try {
        final newSolution = solutionController.text;
        final solutions = idea.solution.isEmpty 
            ? newSolution 
            : '${idea.solution}\n\nAlternative Lösung:\n$newSolution';
            
        await _database.child(idea.id).update({
          'solution': solutions,
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fehler beim Speichern der Lösung')),
          );
        }
      }
    }
  }

  Future<void> _createNewIdea() async {
    final titleController = TextEditingController();
    final categoryController = TextEditingController();
    final problemController = TextEditingController();
    final solutionController = TextEditingController();

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Neue Idee erstellen'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Titel',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Kategorie',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: problemController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Problem',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: solutionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Lösung (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Erstellen'),
          ),
        ],
      ),
    );

    if (result == true && 
        titleController.text.isNotEmpty && 
        categoryController.text.isNotEmpty && 
        problemController.text.isNotEmpty) {
      try {
        final ideaId = titleController.text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
        await _database.child(ideaId).set({
          'title': titleController.text,
          'category': categoryController.text,
          'problem': problemController.text,
          'solution': solutionController.text,
          'upVotes': 0,
          'downVotes': 0,
          'upVoters': {},
          'downVoters': {},
          'timestamp': ServerValue.timestamp,
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fehler beim Erstellen der Idee')),
          );
        }
      }
    }
  }

  Color _getScoreColor(BuildContext context, int score, double animationValue) {
    if (score > 0) {
      final intensity = math.min(0.9, 0.3 + (score * 0.1));
      return Color.lerp(
        const Color(0xFFE3F2FD),  // Helles Blau als Basis
        const Color(0xFF2196F3),  // Kräftiges Blau für positive Votes
        intensity * animationValue,
      )!;
    } else if (score < 0) {
      final intensity = math.min(0.9, 0.3 + (score.abs() * 0.1));
      return Color.lerp(
        const Color(0xFFFFEBEE),  // Helles Rosa als Basis
        const Color(0xFFE91E63),  // Kräftiges Pink für negative Votes
        intensity * animationValue,
      )!;
    }
    return const Color(0xFFF5F5F5);  // Sehr helles Grau als Neutral
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bamberg Ideen'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewIdea,
        icon: const Icon(Icons.add),
        label: const Text('Neue Idee'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: ideas.length,
              itemBuilder: (context, index) {
                final idea = ideas[index];
                final hasUpvoted = idea.upVoters.containsKey(_userId);
                final hasDownvoted = idea.downVoters.containsKey(_userId);
                
                return TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 500),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, value, child) {
                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: 200,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              _getScoreColor(context, idea.score, value),
                              _getScoreColor(context, idea.score, value).withOpacity(0.0),
                            ],
                            stops: const [0.0, 0.7],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Voting-Leiste
                        SizedBox(
                          width: 80,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                              ),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: hasUpvoted 
                                        ? const Color(0xFF2196F3).withOpacity(0.2)
                                        : Colors.transparent,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                    ),
                                  ),
                                  child: IconButton(
                                    iconSize: 32,
                                    icon: Icon(
                                      Icons.arrow_upward_rounded,
                                      color: hasUpvoted 
                                          ? const Color(0xFF2196F3)
                                          : Theme.of(context).colorScheme.outline,
                                    ),
                                    onPressed: () => _vote(idea, true),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text(
                                    '${idea.score}',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: idea.score > 0 
                                          ? const Color(0xFF2196F3)
                                          : idea.score < 0 
                                              ? const Color(0xFFE91E63)
                                              : Theme.of(context).colorScheme.outline,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: hasDownvoted 
                                        ? const Color(0xFFE91E63).withOpacity(0.2)
                                        : Colors.transparent,
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(16),
                                    ),
                                  ),
                                  child: IconButton(
                                    iconSize: 32,
                                    icon: Icon(
                                      Icons.arrow_downward_rounded,
                                      color: hasDownvoted
                                          ? const Color(0xFFE91E63)
                                          : Theme.of(context).colorScheme.outline,
                                    ),
                                    onPressed: () => _vote(idea, false),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Hauptinhalt
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Titel und Kategorie
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      idea.title,
                                      style: Theme.of(context).textTheme.titleLarge,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                    Text(
                                      idea.category,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Problem und Lösung
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (idea.problem.isNotEmpty) ...[
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      'Problem',
                                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                        color: Theme.of(context).colorScheme.error,
                                                      ),
                                                    ),
                                                    const Spacer(),
                                                    if (idea.problem.length > 200)
                                                      TextButton(
                                                        onPressed: () => _showFullText(context, 'Problem', idea.problem),
                                                        child: const Text('Mehr'),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  idea.problem.length > 200
                                                      ? '${idea.problem.substring(0, 200)}...'
                                                      : idea.problem,
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 8,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                        ],
                                        if (idea.solution.isNotEmpty) ...[
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      'Lösung',
                                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                        color: Theme.of(context).colorScheme.primary,
                                                      ),
                                                    ),
                                                    const Spacer(),
                                                    if (idea.solution.length > 200)
                                                      TextButton(
                                                        onPressed: () => _showFullText(context, 'Lösung', idea.solution),
                                                        child: const Text('Mehr'),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  idea.solution.length > 200
                                                      ? '${idea.solution.substring(0, 200)}...'
                                                      : idea.solution,
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 8,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            onPressed: () => _addSolution(idea),
                                            icon: const Icon(Icons.add),
                                            label: const Text('Lösung vorschlagen'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
