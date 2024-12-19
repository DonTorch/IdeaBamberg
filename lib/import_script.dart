import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';

class IdeaImporter {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  Future<void> importIdeas() async {
    try {
      // CSV-Datei als Bytes laden
      ByteData data = await rootBundle.load('assets/Ideen_Buergerschaft.csv');
      List<int> bytes = data.buffer.asUint8List();
      
      // Bytes als Latin1 dekodieren
      String csvString = latin1.decode(bytes);
      
      // CSV parsen
      List<List<dynamic>> csvTable = const CsvToListConverter(
        fieldDelimiter: ';',
        textDelimiter: '"',
        eol: '\n',
      ).convert(csvString);

      // Header-Zeile entfernen
      csvTable.removeAt(0);

      // Ideen in die Firebase Realtime Database importieren
      for (var row in csvTable) {
        if (row.length >= 4) {
          String category = row[0].toString().trim();
          String title = _shortenTitle(row[1].toString().trim());
          String problem = row[2].toString().trim();
          String solution = row[3].toString().trim();

          if (title.isNotEmpty) {
            String ideaId = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
            
            await _database.child('ideas').child(ideaId).set({
              'category': category,
              'title': title,
              'problem': problem,
              'solution': solution,
              'upVotes': 0,
              'downVotes': 0,
              'upVoters': {},
              'downVoters': {},
              'timestamp': ServerValue.timestamp,
            });
          }
        }
      }
    } catch (e) {
      print('Fehler beim Importieren der Ideen: $e');
      rethrow;
    }
  }

  String _shortenTitle(String title) {
    // Titel auf maximal 50 Zeichen kürzen
    if (title.length > 50) {
      return title.substring(0, 47) + '...';
    }
    return title;
  }

  Future<String?> getUserVoteType(String userId, String ideaId) async {
    try {
      // Prüfen, ob der Benutzer bereits abgestimmt hat
      DataSnapshot upSnapshot = await _database
          .child('ideas')
          .child(ideaId)
          .child('upVoters')
          .child(userId)
          .get();

      if (upSnapshot.exists) return 'up';

      DataSnapshot downSnapshot = await _database
          .child('ideas')
          .child(ideaId)
          .child('downVoters')
          .child(userId)
          .get();

      if (downSnapshot.exists) return 'down';

      return null;
    } catch (e) {
      print('Fehler beim Prüfen des Voting-Status: $e');
      return null;
    }
  }

  Future<void> vote(String userId, String ideaId, bool? isUpvote) async {
    try {
      String? currentVote = await getUserVoteType(userId, ideaId);
      
      await _database.child('ideas').child(ideaId).runTransaction((Object? post) {
        if (post == null) return Transaction.abort();

        Map<String, dynamic> idea = Map<String, dynamic>.from(post as Map);
        
        // Bestehende Stimme entfernen
        if (currentVote == 'up') {
          idea['upVotes'] = (idea['upVotes'] ?? 0) - 1;
          (idea['upVoters'] as Map).remove(userId);
        } else if (currentVote == 'down') {
          idea['downVotes'] = (idea['downVotes'] ?? 0) - 1;
          (idea['downVoters'] as Map).remove(userId);
        }

        // Neue Stimme nur hinzufügen, wenn nicht die gleiche Stimme entfernt wurde
        if (isUpvote != null && 
            (currentVote == null || 
             (currentVote == 'up' && !isUpvote) || 
             (currentVote == 'down' && isUpvote))) {
          if (isUpvote) {
            idea['upVotes'] = (idea['upVotes'] ?? 0) + 1;
            if (idea['upVoters'] == null) idea['upVoters'] = {};
            (idea['upVoters'] as Map)[userId] = true;
          } else {
            idea['downVotes'] = (idea['downVotes'] ?? 0) + 1;
            if (idea['downVoters'] == null) idea['downVoters'] = {};
            (idea['downVoters'] as Map)[userId] = true;
          }
        }

        return Transaction.success(idea);
      });
    } catch (e) {
      print('Fehler beim Abstimmen: $e');
      rethrow;
    }
  }
} 