import { onRequest } from 'firebase-functions/v2/https';
import { initializeApp } from 'firebase-admin/app';
import { getDatabase } from 'firebase-admin/database';
import fetch from 'node-fetch';
import { parse } from 'csv-parse/sync';

initializeApp();

export const importCsvToDatabase = onRequest({ region: 'europe-west1' }, async (request, response) => {
  try {
    // CSV von der URL herunterladen
    const csvUrl = 'https://opendata.smartcitybamberg.de/Ideen_Buergerschaft.CSV';
    const csvResponse = await fetch(csvUrl);
    const csvData = await csvResponse.text();

    // CSV parsen
    const records = parse(csvData, {
      delimiter: ';',
      skip_empty_lines: true,
      from_line: 2 // Überspringe die Kopfzeile
    });

    // Referenz zur Realtime Database
    const db = getDatabase();
    const ideenRef = db.ref('ideen');

    // Prüfe ob bereits Daten vorhanden sind
    const snapshot = await ideenRef.get();
    if (snapshot.exists()) {
      response.status(400).send('Datenbank enthält bereits Daten. Import wird übersprungen.');
      return;
    }

    // Importiere die Daten
    let importCount = 0;
    for (const record of records) {
      if (record.length >= 3 && record[2].trim()) {
        await ideenRef.push().set({
          problem: record[2].trim(),
          upVotes: 0,
          downVotes: 0
        });
        importCount++;
      }
    }

    response.status(200).send(`Import erfolgreich abgeschlossen. ${importCount} Ideen importiert.`);
  } catch (error: any) {
    console.error('Fehler beim Import:', error);
    response.status(500).send(`Fehler beim Import: ${error.message}`);
  }
}); 