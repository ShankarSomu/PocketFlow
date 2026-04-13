import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import '../db/database.dart';
import '../models/transaction.dart' as model;
import '../models/budget.dart';
import '../models/savings_goal.dart';

class ApiServer {
  static HttpServer? _server;
  static const int port = 8080;

  static bool get isRunning => _server != null;

  static Future<void> start() async {
    if (_server != null) return;
    final router = Router()
      ..get('/health', _health)
      ..get('/summary', _summary)
      ..get('/transactions', _getTransactions)
      ..post('/transactions', _addTransaction)
      ..get('/budgets', _getBudgets)
      ..post('/budgets', _upsertBudget)
      ..get('/savings', _getGoals)
      ..post('/savings', _addGoal)
      ..post('/savings/<name>/contribute', _contribute);

    final handler = Pipeline()
        .addMiddleware(_cors())
        .addMiddleware(logRequests())
        .addHandler(router.call);

    _server = await io.serve(handler, InternetAddress.anyIPv4, port);
  }

  static Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  // ── Middleware ──────────────────────────────────────────────────────────────

  static Middleware _cors() => (handler) => (request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }
        final response = await handler(request);
        return response.change(headers: _corsHeaders);
      };

  static const _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Content-Type': 'application/json',
  };

  // ── Handlers ────────────────────────────────────────────────────────────────

  static Response _health(Request _) =>
      Response.ok(jsonEncode({'status': 'ok', 'app': 'PocketFlow'}),
          headers: _corsHeaders);

  static Future<Response> _summary(Request _) async {
    final now = DateTime.now();
    final income = await AppDatabase.monthlyTotal('income', now.month, now.year);
    final expenses = await AppDatabase.monthlyTotal('expense', now.month, now.year);
    final cats = await AppDatabase.monthlyExpenseByCategory(now.month, now.year);
    final goals = await AppDatabase.getGoals();
    return Response.ok(
      jsonEncode({
        'month': '${now.year}-${now.month.toString().padLeft(2, '0')}',
        'income': income,
        'expenses': expenses,
        'net': income - expenses,
        'spending_by_category': cats,
        'savings_goals': goals.map((g) => {
              'name': g.name,
              'target': g.target,
              'saved': g.saved,
              'progress_pct': (g.progress * 100).toStringAsFixed(1),
            }).toList(),
      }),
      headers: _corsHeaders,
    );
  }

  static Future<Response> _getTransactions(Request req) async {
    final params = req.url.queryParameters;
    final txns = await AppDatabase.getTransactions(
      type: params['type'],
      from: params['from'] != null ? DateTime.tryParse(params['from']!) : null,
      to: params['to'] != null ? DateTime.tryParse(params['to']!) : null,
      keyword: params['keyword'],
    );
    return Response.ok(
      jsonEncode(txns.map((t) => t.toMap()).toList()),
      headers: _corsHeaders,
    );
  }

  static Future<Response> _addTransaction(Request req) async {
    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final type = body['type'] as String?;
    final amount = (body['amount'] as num?)?.toDouble();
    final category = body['category'] as String?;
    if (type == null || amount == null || category == null) {
      return Response(400,
          body: jsonEncode({'error': 'type, amount, category required'}),
          headers: _corsHeaders);
    }
    final id = await AppDatabase.insertTransaction(model.Transaction(
      type: type,
      amount: amount,
      category: category,
      note: body['note'] as String?,
      date: body['date'] != null ? DateTime.parse(body['date']) : DateTime.now(),
    ));
    return Response.ok(jsonEncode({'id': id}), headers: _corsHeaders);
  }

  static Future<Response> _getBudgets(Request req) async {
    final now = DateTime.now();
    final month = int.tryParse(req.url.queryParameters['month'] ?? '') ?? now.month;
    final year = int.tryParse(req.url.queryParameters['year'] ?? '') ?? now.year;
    final budgets = await AppDatabase.getBudgets(month, year);
    final spent = await AppDatabase.monthlyExpenseByCategory(month, year);
    return Response.ok(
      jsonEncode(budgets.map((b) => {
            ...b.toMap(),
            'spent': spent[b.category] ?? 0,
            'remaining': b.limit - (spent[b.category] ?? 0),
          }).toList()),
      headers: _corsHeaders,
    );
  }

  static Future<Response> _upsertBudget(Request req) async {
    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final category = body['category'] as String?;
    final limit = (body['limit'] as num?)?.toDouble();
    if (category == null || limit == null) {
      return Response(400,
          body: jsonEncode({'error': 'category and limit required'}),
          headers: _corsHeaders);
    }
    final now = DateTime.now();
    await AppDatabase.upsertBudget(Budget(
      category: category,
      limit: limit,
      month: int.tryParse(body['month']?.toString() ?? '') ?? now.month,
      year: int.tryParse(body['year']?.toString() ?? '') ?? now.year,
    ));
    return Response.ok(jsonEncode({'status': 'ok'}), headers: _corsHeaders);
  }

  static Future<Response> _getGoals(Request _) async {
    final goals = await AppDatabase.getGoals();
    return Response.ok(
      jsonEncode(goals.map((g) => {
            ...g.toMap(),
            'progress_pct': (g.progress * 100).toStringAsFixed(1),
          }).toList()),
      headers: _corsHeaders,
    );
  }

  static Future<Response> _addGoal(Request req) async {
    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final name = body['name'] as String?;
    final target = (body['target'] as num?)?.toDouble();
    if (name == null || target == null) {
      return Response(400,
          body: jsonEncode({'error': 'name and target required'}),
          headers: _corsHeaders);
    }
    final id = await AppDatabase.insertGoal(
        SavingsGoal(name: name, target: target, saved: 0));
    return Response.ok(jsonEncode({'id': id}), headers: _corsHeaders);
  }

  static Future<Response> _contribute(Request req, String name) async {
    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final amount = (body['amount'] as num?)?.toDouble();
    if (amount == null) {
      return Response(400,
          body: jsonEncode({'error': 'amount required'}), headers: _corsHeaders);
    }
    final goals = await AppDatabase.getGoals();
    final goal = goals.where((g) => g.name == name).firstOrNull;
    if (goal == null) {
      return Response(404,
          body: jsonEncode({'error': 'goal not found'}), headers: _corsHeaders);
    }
    await AppDatabase.updateGoalSaved(goal.id!, goal.saved + amount);
    return Response.ok(jsonEncode({'status': 'ok'}), headers: _corsHeaders);
  }
}
