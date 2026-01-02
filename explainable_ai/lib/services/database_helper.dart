import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class DatabaseHelper {
  static Database? _database;
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'explainable_ai.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        // Predictions table for offline history
        await db.execute('''
          CREATE TABLE predictions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            model_type TEXT NOT NULL,
            input_data TEXT NOT NULL,
            result TEXT NOT NULL,
            risk_score REAL,
            risk_level TEXT,
            timestamp TEXT NOT NULL,
            synced INTEGER DEFAULT 0
          )
        ''');
        
        // User profile cache for offline access
        await db.execute('''
          CREATE TABLE user_profile(
            id INTEGER PRIMARY KEY,
            uid TEXT UNIQUE,
            name TEXT,
            email TEXT,
            role TEXT,
            age INTEGER,
            gender TEXT,
            blood_group TEXT,
            updated_at TEXT
          )
        ''');
        
        // Chat messages table for conversation history
        await db.execute('''
          CREATE TABLE chat_messages(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            synced INTEGER DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE predictions ADD COLUMN risk_score REAL');
          await db.execute('ALTER TABLE predictions ADD COLUMN risk_level TEXT');
          await db.execute('ALTER TABLE predictions ADD COLUMN synced INTEGER DEFAULT 0');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS chat_messages(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              role TEXT NOT NULL,
              content TEXT NOT NULL,
              timestamp TEXT NOT NULL,
              synced INTEGER DEFAULT 0
            )
          ''');
        }
      },
    );
  }

  // --- PREDICTIONS ---
  
  Future<int> savePrediction(
    String modelType,
    Map<String, dynamic> inputData,
    Map<String, dynamic> result,
  ) async {
    final db = await database;
    
    double? riskScore;
    String? riskLevel;
    
    if (result.containsKey('risk')) {
      riskScore = (result['risk'] as num).toDouble();
      riskLevel = riskScore > 0.7 ? "High" : (riskScore > 0.4 ? "Medium" : "Low");
    }
    
    return await db.insert('predictions', {
      'model_type': modelType,
      'input_data': json.encode(inputData),
      'result': json.encode(result),
      'risk_score': riskScore,
      'risk_level': riskLevel,
      'timestamp': DateTime.now().toIso8601String(),
      'synced': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getPredictionHistory(String? modelType) async {
    final db = await database;
    
    if (modelType == null || modelType.isEmpty) {
      return await db.query(
        'predictions',
        orderBy: 'timestamp DESC',
      );
    }
    
    return await db.query(
      'predictions',
      where: 'model_type = ?',
      whereArgs: [modelType],
      orderBy: 'timestamp DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllPredictions() async {
    final db = await database;
    return await db.query('predictions', orderBy: 'timestamp DESC');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedPredictions() async {
    final db = await database;
    return await db.query(
      'predictions',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'timestamp ASC',
    );
  }

  Future<void> markAsSynced(int id) async {
    final db = await database;
    await db.update(
      'predictions',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getPredictionCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM predictions');
    return result.first['count'] as int;
  }

  Future<Map<String, int>> getPredictionStats() async {
    final db = await database;
    final heart = await db.rawQuery("SELECT COUNT(*) as count FROM predictions WHERE model_type = 'heart'");
    final diabetes = await db.rawQuery("SELECT COUNT(*) as count FROM predictions WHERE model_type = 'diabetes'");
    final pneumonia = await db.rawQuery("SELECT COUNT(*) as count FROM predictions WHERE model_type = 'pneumonia'");
    
    return {
      'heart': heart.first['count'] as int,
      'diabetes': diabetes.first['count'] as int,
      'pneumonia': pneumonia.first['count'] as int,
    };
  }

  // --- USER PROFILE CACHE ---
  
  Future<void> cacheUserProfile(Map<String, dynamic> profile) async {
    final db = await database;
    await db.insert(
      'user_profile',
      {
        'uid': profile['uid'],
        'name': profile['name'],
        'email': profile['email'],
        'role': profile['role'],
        'age': profile['age'],
        'gender': profile['gender'],
        'blood_group': profile['bloodGroup'],
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getCachedProfile(String uid) async {
    final db = await database;
    final results = await db.query(
      'user_profile',
      where: 'uid = ?',
      whereArgs: [uid],
    );
    
    if (results.isEmpty) return null;
    return results.first;
  }

  // --- CLEANUP ---
  
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('predictions');
    await db.delete('user_profile');
  }

  Future<void> deleteOldPredictions({int daysOld = 90}) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
    await db.delete(
      'predictions',
      where: 'timestamp < ? AND synced = 1',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  // --- CHAT MESSAGES ---
  
  Future<int> saveChatMessage({
    required String role,
    required String content,
    DateTime? timestamp,
  }) async {
    final db = await database;
    return await db.insert('chat_messages', {
      'role': role,
      'content': content,
      'timestamp': (timestamp ?? DateTime.now()).toIso8601String(),
      'synced': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getChatHistory({int? limit}) async {
    final db = await database;
    return await db.query(
      'chat_messages',
      orderBy: 'timestamp ASC',
      limit: limit,
    );
  }

  Future<void> clearChatHistory() async {
    final db = await database;
    await db.delete('chat_messages');
  }

  Future<int> getChatMessageCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM chat_messages');
    return result.first['count'] as int;
  }
}
