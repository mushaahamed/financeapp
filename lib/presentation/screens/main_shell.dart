import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import 'dashboard/dashboard_screen.dart';
import 'expenses/expenses_screen.dart';
import 'investments/investments_screen.dart';

final _tabIndexProvider = StateProvider<int>((ref) => 0);

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static const _screens = [
    DashboardScreen(),
    ExpensesScreen(),
    InvestmentsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = ref.watch(_tabIndexProvider);
    return Scaffold(
      body: IndexedStack(index: idx, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: kDivider)),
        ),
        child: BottomNavigationBar(
          currentIndex: idx,
          onTap: (i) => ref.read(_tabIndexProvider.notifier).state = i,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long_rounded),
              label: 'Expenses',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.show_chart_outlined),
              activeIcon: Icon(Icons.show_chart_rounded),
              label: 'Investments',
            ),
          ],
        ),
      ),
    );
  }
}
