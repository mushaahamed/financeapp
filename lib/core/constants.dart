import 'package:flutter/material.dart';

const kPrimary = Color(0xFF2563EB);
const kPrimaryLight = Color(0xFFEFF6FF);
const kGain = Color(0xFF10B981);
const kLoss = Color(0xFFEF4444);
const kBackground = Color(0xFFF8FAFC);
const kCard = Colors.white;
const kTextPrimary = Color(0xFF0F172A);
const kTextSecondary = Color(0xFF64748B);
const kDivider = Color(0xFFE2E8F0);

const kPad = 16.0;
const kRadius = 12.0;
const kRadiusLg = 16.0;

const kGeminiDefaultModel = 'gemini-2.5-flash';
const kDefaultCurrency = 'INR';
const kDefaultCurrencySymbol = '₹';

const kDbName = 'paisa.db';
const kSecureKeyGeminiApiKey = 'gemini_api_key';

// ── All supported investment types ────────────────────────────────────────────

const kAssetTypes = [
  // Market-linked
  'mutual_fund',
  'stocks',
  'us_stocks',
  'gold_etf',
  'silver_etf',
  'reit',
  'crypto',
  // Fixed / government
  'fixed_deposit',
  'recurring_deposit',
  'ppf',
  'epf',
  'nps',
  'nsc',
  'sgb',
  'bonds',
  'post_office',
  // Physical
  'physical_gold',
  'physical_silver',
  'real_estate',
  // Other
  'ulip',
  'other',
];

const kAssetTypeLabels = {
  'mutual_fund': 'Mutual Fund',
  'stocks': 'Indian Stocks',
  'us_stocks': 'US Stocks',
  'gold_etf': 'Gold ETF',
  'silver_etf': 'Silver ETF',
  'reit': 'REIT',
  'crypto': 'Crypto',
  'fixed_deposit': 'Fixed Deposit (FD)',
  'recurring_deposit': 'Recurring Deposit (RD)',
  'ppf': 'PPF',
  'epf': 'EPF / PF',
  'nps': 'NPS',
  'nsc': 'NSC',
  'sgb': 'Sovereign Gold Bond',
  'bonds': 'Bonds / Debentures',
  'post_office': 'Post Office Scheme',
  'physical_gold': 'Physical Gold',
  'physical_silver': 'Physical Silver',
  'real_estate': 'Real Estate',
  'ulip': 'ULIP',
  'other': 'Other',
};

// Grouped for the UI type picker
const kAssetTypeGroups = {
  'Market-linked': [
    'mutual_fund',
    'stocks',
    'us_stocks',
    'gold_etf',
    'silver_etf',
    'reit',
    'crypto',
  ],
  'Fixed Returns': [
    'fixed_deposit',
    'recurring_deposit',
    'ppf',
    'epf',
    'nps',
    'nsc',
    'sgb',
    'bonds',
    'post_office',
  ],
  'Physical / Real': [
    'physical_gold',
    'physical_silver',
    'real_estate',
  ],
  'Other': [
    'ulip',
    'other',
  ],
};

const kExpenseCategories = [
  'Food & Dining',
  'Shopping',
  'Friends',
  'Transport',
  'Health',
  'Entertainment',
  'Bills',
  'Other',
];
