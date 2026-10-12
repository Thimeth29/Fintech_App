// lib/services/sandbox/lesson_repository.dart
//
// Lesson and quiz content lives in assets/sandbox/lessons/<module>.json so
// it can be edited without touching code.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../core/sandbox/sandbox_config.dart';

class LessonCard {
  final String title;
  final String body;
  final String visual; // see LessonVisual
  const LessonCard({required this.title, required this.body, required this.visual});

  factory LessonCard.fromJson(Map<String, dynamic> j) => LessonCard(
        title: '${j['title'] ?? ''}',
        body: '${j['body'] ?? ''}',
        visual: '${j['visual'] ?? 'idea'}',
      );
}

class QuizQuestion {
  final String question;
  final List<String> options;
  final int answer;
  final String explanation;
  const QuizQuestion({required this.question, required this.options, required this.answer, required this.explanation});

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
        question: '${j['question'] ?? ''}',
        options: [for (final o in (j['options'] as List? ?? const [])) '$o'],
        answer: (j['answer'] as num?)?.toInt() ?? 0,
        explanation: '${j['explanation'] ?? ''}',
      );
}

class Lesson {
  final String id;
  final SandboxModule module;
  final String title;
  final String summary;
  final List<LessonCard> cards;
  final List<QuizQuestion> quiz;

  const Lesson({
    required this.id,
    required this.module,
    required this.title,
    required this.summary,
    required this.cards,
    required this.quiz,
  });

  factory Lesson.fromJson(SandboxModule module, Map<String, dynamic> j) => Lesson(
        id: '${j['id']}',
        module: module,
        title: '${j['title'] ?? ''}',
        summary: '${j['summary'] ?? ''}',
        cards: [for (final c in (j['cards'] as List? ?? const [])) LessonCard.fromJson(c as Map<String, dynamic>)],
        quiz: [for (final q in (j['quiz'] as List? ?? const [])) QuizQuestion.fromJson(q as Map<String, dynamic>)],
      );
}

class LessonRepository {
  final Map<SandboxModule, List<Lesson>> _cache = {};

  static String assetPath(SandboxModule m) => 'assets/sandbox/lessons/${m.id}.json';

  static List<Lesson> parse(SandboxModule m, String source) {
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    return [
      for (final l in (decoded['lessons'] as List? ?? const [])) Lesson.fromJson(m, l as Map<String, dynamic>),
    ];
  }

  Future<List<Lesson>> lessonsFor(SandboxModule m) async {
    final cached = _cache[m];
    if (cached != null) return cached;
    try {
      final lessons = parse(m, await rootBundle.loadString(assetPath(m)));
      _cache[m] = lessons;
      return lessons;
    } catch (_) {
      return const [];
    }
  }

  Future<Map<SandboxModule, List<Lesson>>> loadAll() async => {
        for (final m in SandboxModule.values) m: await lessonsFor(m),
      };
}
