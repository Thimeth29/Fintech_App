import 'package:flutter/material.dart';
import '../models/persona_model.dart';

class AppViewModel extends ChangeNotifier {
  final Map<String, PersonaModel> _personas = {
    'adult': PersonaModel(
      id: 'adult',
      name: 'Kumari Perera',
      role: 'Adult · Family budgeting',
      init: 'KP',
      color: '#0F3B34',
      balance: '128,450',
      change: '+4.2%',
      saved: '18,200',
      spent: '41,900',
      predict: 'Predicted spend for August: <b>LKR 43,000</b> — Average level, close to July.',
      cats: [
        CategoryModel(name: 'Household', percentage: 34, amount: '14,600/kg'),
        CategoryModel(name: 'School & family', percentage: 22, amount: '9,300'),
        CategoryModel(name: 'Transport', percentage: 18, amount: '7,600'),
        CategoryModel(name: 'Health', percentage: 14, amount: '5,900'),
        CategoryModel(name: 'Other', percentage: 12, amount: '5,000'),
      ],
      txns: [
        TransactionModel(name: "Keells Super", category: "Household", amount: "-3,450", emoji: "🛒"),
        TransactionModel(name: "CEB Bill", category: "Utilities", amount: "-6,200", emoji: "⚡"),
        TransactionModel(name: "Daughter's tuition", category: "Education", amount: "-4,000", emoji: "📚"),
        TransactionModel(name: "Salary", category: "Income", amount: "+95,000", emoji: "💰"),
      ],
      advice: AdviceModel(
        message: 'Move LKR 5,000 into your Fixed Deposit sandbox this month — your buffer can absorb it.',
        factors: [
          FactorModel(name: 'Emergency fund already at 3 months', value: 34, direction: 'pos'),
          FactorModel(name: 'Household spend trending flat', value: 26, direction: 'pos'),
          FactorModel(name: 'School term fees due in Sept', value: -21, direction: 'neg'),
          FactorModel(name: 'Gold price volatility this week', value: -9, direction: 'neg'),
        ],
      ),
      invest: [
        InvestmentModel(name: 'Fixed Deposit (12mo)', sub: 'NSB · Low risk', change: '6.8% p.a.', direction: 'up'),
        InvestmentModel(name: 'Gold (Sovereign)', sub: '1g unit', change: '+1.1% today', direction: 'up'),
        InvestmentModel(name: 'Treasury Bond', sub: 'CBSL · 5yr', change: '11.2% yield', direction: 'up'),
      ],
      quiz: 'Post-test score 78% · +24% since pre-test',
    ),
    'teen': PersonaModel(
      id: 'teen',
      name: 'Sanjana Silva',
      role: 'Teenager · 17, learning basics',
      init: 'SS',
      color: '#7C9885',
      balance: '6,300',
      change: '+11%',
      saved: '2,100',
      spent: '1,850',
      predict: 'At this pace you\'ll save <b>LKR 2,600</b> by month end — enough for your bus pass fund.',
      cats: [
        CategoryModel(name: 'Snacks & transport', percentage: 40, amount: '1,200'),
        CategoryModel(name: 'Games/data', percentage: 30, amount: '900'),
        CategoryModel(name: 'Savings goal', percentage: 20, amount: '600'),
        CategoryModel(name: 'Other', percentage: 10, amount: '300'),
      ],
      txns: [
        TransactionModel(name: 'Pocket money', category: 'Income', amount: '+3,000', emoji: '💵'),
        TransactionModel(name: 'Bus top-up', category: 'Transport', amount: '-400', emoji: '🚌'),
        TransactionModel(name: 'Mobile data', category: 'Data', amount: '-350', emoji: '📱'),
        TransactionModel(name: 'Savings jar', category: 'Transfer', amount: '-600', emoji: '🏦'),
      ],
      advice: AdviceModel(
        message: 'Try the Sandbox before real investing — practice a Gold trade risk-free this week.',
        factors: [
          FactorModel(name: 'No real-money risk in sandbox', value: 40, direction: 'pos'),
          FactorModel(name: 'Consistent weekly saving habit', value: 30, direction: 'pos'),
          FactorModel(name: 'Limited income volatility understood', value: 15, direction: 'pos'),
          FactorModel(name: 'New to markets — start small', value: -12, direction: 'neg'),
        ],
      ),
      invest: [
        InvestmentModel(name: 'Sandbox: Gold', sub: 'Practice mode', change: '+0.8% (mock)', direction: 'up'),
        InvestmentModel(name: 'Sandbox: Stocks', sub: 'CSE demo', change: '-0.3% (mock)', direction: 'down'),
        InvestmentModel(name: 'Community fund', sub: 'Seettu circle', change: 'Round 3 of 10', direction: 'up'),
      ],
      quiz: 'Post-test score 85% · +31% since pre-test',
    ),
    'employee': PersonaModel(
      id: 'employee',
      name: 'Nadeesha Fernando',
      role: 'Employee · Salaried, 28',
      init: 'NF',
      color: '#C98A2C',
      balance: '312,900',
      change: '+2.6%',
      saved: '64,000',
      spent: '88,300',
      predict: 'Predicted spend for August: <b>LKR 91,500</b> — Critical level, above your usual.',
      cats: [
        CategoryModel(name: 'Rent', percentage: 38, amount: '48,000'),
        CategoryModel(name: 'Transport & fuel', percentage: 20, amount: '25,200'),
        CategoryModel(name: 'EPF top-up', percentage: 16, amount: '20,100'),
        CategoryModel(name: 'Leisure', percentage: 14, amount: '12,600'),
        CategoryModel(name: 'Other', percentage: 12, amount: '9,800'),
      ],
      txns: [
        TransactionModel(name: 'Rent transfer', category: 'Housing', amount: '-48,000', emoji: '🏠'),
        TransactionModel(name: 'Fuel', category: 'Transport', amount: '-8,200', emoji: '⛽'),
        TransactionModel(name: 'EPF voluntary', category: 'Savings', amount: '-20,100', emoji: '🏦'),
        TransactionModel(name: 'Salary', category: 'Income', amount: '+185,000', emoji: '💰'),
      ],
      advice: AdviceModel(
        message: 'Shift LKR 15,000 from Leisure into your Unit Trust sandbox — this month runs above budget.',
        factors: [
          FactorModel(name: 'August spend trending 8% above average', value: 31, direction: 'neg'),
          FactorModel(name: 'Stable EPF contribution history', value: 28, direction: 'pos'),
          FactorModel(name: 'Forex rate favorable for savings', value: 19, direction: 'pos'),
          FactorModel(name: 'Leisure spend discretionary', value: 22, direction: 'pos'),
        ],
      ),
      invest: [
        InvestmentModel(name: 'Unit Trust', sub: 'Balanced fund', change: '9.4% YTD', direction: 'up'),
        InvestmentModel(name: 'Forex (USD)', sub: 'Sandbox demo', change: '+0.6% today', direction: 'up'),
        InvestmentModel(name: 'CSE Stock — JKH', sub: 'Blue chip', change: '-0.9% today', direction: 'down'),
      ],
      quiz: 'Post-test score 81% · +19% since pre-test',
    ),
    'business': PersonaModel(
      id: 'business',
      name: 'Roshan Jayasuriya',
      role: 'Business owner · 41',
      init: 'RJ',
      color: '#B85C38',
      balance: '1,842,600',
      change: '-1.8%',
      saved: '210,000',
      spent: '640,300',
      predict: 'Predicted cash flow for August: <b>LKR 660,000</b> outflow — watch supplier payments week 3.',
      cats: [
        CategoryModel(name: 'Inventory', percentage: 42, amount: '269,000'),
        CategoryModel(name: 'Staff wages', percentage: 26, amount: '166,500'),
        CategoryModel(name: 'Rent & utilities', percentage: 14, amount: '89,600'),
        CategoryModel(name: 'Marketing', percentage: 10, amount: '64,000'),
        CategoryModel(name: 'Other', percentage: 8, amount: '51,200'),
      ],
      txns: [
        TransactionModel(name: 'Supplier — textiles', category: 'Inventory', amount: '-142,000', emoji: '📦'),
        TransactionModel(name: 'Staff payroll', category: 'Wages', amount: '-166,500', emoji: '👥'),
        TransactionModel(name: 'Sales — retail', category: 'Income', amount: '+420,000', emoji: '🧾'),
        TransactionModel(name: 'Ad campaign', category: 'Marketing', amount: '-22,000', emoji: '📣'),
      ],
      advice: AdviceModel(
        message: 'Hold treasury bond allocation steady — your cash buffer covers the week 3 supplier dip.',
        factors: [
          FactorModel(name: '3-month cash buffer sufficient', value: 36, direction: 'pos'),
          FactorModel(name: 'Seasonal inventory build-up expected', value: 24, direction: 'neg'),
          FactorModel(name: 'Treasury bond yield stable', value: 22, direction: 'pos'),
          FactorModel(name: 'Marketing spend ROI trending up', value: 18, direction: 'pos'),
        ],
      ),
      invest: [
        InvestmentModel(name: 'Treasury Bond', sub: 'CBSL · 91-day', change: '10.8% yield', direction: 'up'),
        InvestmentModel(name: 'Fixed Deposit', sub: 'Business account', change: '7.1% p.a.', direction: 'up'),
        InvestmentModel(name: 'Community investing', sub: 'Trader circle', change: 'Round 6 of 12', direction: 'up'),
      ],
      quiz: 'Post-test score 73% · +16% since pre-test',
    ),
  };

  String _currentPersonaId = 'adult';
  String _currentScreen = 'login';
  String _selectedLanguage = 'en'; // 'en', 'si', 'ta'

  Map<String, PersonaModel> get personas => _personas;
  String get currentPersonaId => _currentPersonaId;
  String get currentScreen => _currentScreen;
  String get selectedLanguage => _selectedLanguage;

  PersonaModel get currentPersona => _personas[_currentPersonaId]!;

  void setPersona(String personaId) {
    if (_personas.containsKey(personaId)) {
      _currentPersonaId = personaId;
      notifyListeners();
    }
  }

  void setScreen(String screen) {
    _currentScreen = screen;
    notifyListeners();
  }

  void setLanguage(String lang) {
    _selectedLanguage = lang;
    notifyListeners();
  }
}
