import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'package:shared_preferences.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class Idee {
  final String problem;
  String? loesung;
  int upVotes;
  int downVotes;

  Idee({
    required this.problem,
    this.loesung,
    this.upVotes = 0,
    this.downVotes = 0,
  });

  Map<String, dynamic> toJson() => {
    'problem': problem,
    'loesung': loesung,
    'upVotes': upVotes,
    'downVotes': downVotes,
  };

  factory Idee.fromJson(Map<String, dynamic> json) => Idee(
    problem: json['problem'],
    loesung: json['loesung'],
    upVotes: json['upVotes'],
    downVotes: json['downVotes'],
  );

  int get score => upVotes - downVotes;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bamberg Ideen',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const IdeenListe(),
    );
  }
}

class IdeenListe extends StatefulWidget {
  const IdeenListe({super.key});

  @override
  State<IdeenListe> createState() => _IdeenListeState();
}

class _IdeenListeState extends State<IdeenListe> {
  List<Idee> ideen = [];
  bool isLoading = true;
  final SharedPreferences _prefs = await SharedPreferences.getInstance();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse(
          'https://bamberg.bydata.de/datasets/ideen-aus-der-buergerschaft'));
      if (response.statusCode == 200) {
        final csvData = const CsvToListConverter()
            .convert(response.body, fieldDelimiter: ',');
        
        List<Idee> neueIdeen = [];
        for (var row in csvData.skip(1)) { // Skip header row
          if (row.length >= 4) {
            final idee = Idee(
              problem: row[2].toString(), // Spalte C
              loesung: row[3].toString(), // Spalte D
            );
            _loadVotes(idee);
            neueIdeen.add(idee);
          }
        }
        
        setState(() {
          ideen = neueIdeen;
          ideen.sort((a, b) => b.score.compareTo(a.score));
          isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Laden der Daten: $e')),
      );
      setState(() => isLoading = false);
    }
  }

  void _loadVotes(Idee idee) {
    final votes = _prefs.getString('votes_${idee.problem}');
    if (votes != null) {
      final votesMap = json.decode(votes);
      idee.upVotes = votesMap['upVotes'];
      idee.downVotes = votesMap['downVotes'];
    }
  }

  Future<void> _saveVotes(Idee idee) async {
    await _prefs.setString('votes_${idee.problem}',
        json.encode({'upVotes': idee.upVotes, 'downVotes': idee.downVotes}));
  }

  void _addLoesung(Idee idee) async {
    final TextEditingController controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Neue Lösung hinzufügen'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Ihre Lösungsidee...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  idee.loesung = controller.text;
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bamberg Ideen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: ideen.length,
              itemBuilder: (context, index) {
                final idee = ideen[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          idee.problem,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        if (idee.loesung != null) ...[
                          ElevatedButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Lösung'),
                                  content: Text(idee.loesung!),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Schließen'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: const Text('Lösung anzeigen'),
                          ),
                        ] else
                          ElevatedButton(
                            onPressed: () => _addLoesung(idee),
                            child: const Text('Lösung vorschlagen'),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.thumb_up),
                              onPressed: () {
                                setState(() {
                                  idee.upVotes++;
                                  _saveVotes(idee);
                                  ideen.sort((a, b) => b.score.compareTo(a.score));
                                });
                              },
                            ),
                            Text('${idee.upVotes}'),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(Icons.thumb_down),
                              onPressed: () {
                                setState(() {
                                  idee.downVotes++;
                                  _saveVotes(idee);
                                  ideen.sort((a, b) => b.score.compareTo(a.score));
                                });
                              },
                            ),
                            Text('${idee.downVotes}'),
                          ],
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
