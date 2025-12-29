import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class DatabaseHelper {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'predictions.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE predictions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            model_type TEXT,
            input_data TEXT,
            result TEXT,
            timestamp TEXT
          )
        ''');
      },
    );
  }

  Future<void> savePrediction(
    String modelType,
    Map<String, dynamic> inputData,
    Map<String, dynamic> result,
  ) async {
    final db = await database;
    await db.insert('predictions', {
      'model_type': modelType,
      'input_data': json.encode(inputData),
      'result': json.encode(result),
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPredictionHistory(String modelType) async {
    final db = await database;
    return await db.query(
      'predictions',
      where: 'model_type = ?',
      whereArgs: [modelType],
      orderBy: 'timestamp DESC',
    );
  }
}