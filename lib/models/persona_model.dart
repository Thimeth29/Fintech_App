class CategoryModel {
  final String name;
  final int percentage;
  final String amount;

  CategoryModel({
    required this.name,
    required this.percentage,
    required this.amount,
  });
}

class TransactionModel {
  final String name;
  final String category;
  final String amount;
  final String emoji;

  TransactionModel({
    required this.name,
    required this.category,
    required this.amount,
    required this.emoji,
  });
}

class FactorModel {
  final String name;
  final int value;
  final String direction; // 'pos' or 'neg'

  FactorModel({
    required this.name,
    required this.value,
    required this.direction,
  });
}

class AdviceModel {
  final String message;
  final List<FactorModel> factors;

  AdviceModel({
    required this.message,
    required this.factors,
  });
}

class InvestmentModel {
  final String name;
  final String sub;
  final String change;
  final String direction; // 'up' or 'down'

  InvestmentModel({
    required this.name,
    required this.sub,
    required this.change,
    required this.direction,
  });
}

class PersonaModel {
  final String id;
  final String name;
  final String role;
  final String init;
  final String color; // hex string (e.g. '#0F3B34')
  final String balance;
  final String change;
  final String saved;
  final String spent;
  final String predict;
  final List<CategoryModel> cats;
  final List<TransactionModel> txns;
  final AdviceModel advice;
  final List<InvestmentModel> invest;
  final String quiz;

  PersonaModel({
    required this.id,
    required this.name,
    required this.role,
    required this.init,
    required this.color,
    required this.balance,
    required this.change,
    required this.saved,
    required this.spent,
    required this.predict,
    required this.cats,
    required this.txns,
    required this.advice,
    required this.invest,
    required this.quiz,
  });
}
