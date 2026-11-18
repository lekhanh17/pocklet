import '../models/budget.dart';
import '../models/calendar.dart';
import '../models/category.dart';
import '../models/expense.dart';

/// Lop trung gian giua giao dien va nguon du lieu.
/// Hien tai dung MockExpenseRepository; khi API xong chi can viet
/// ApiExpenseRepository implements ExpenseRepository va doi mot dong
/// trong lib/providers/app_providers.dart.
abstract class ExpenseRepository {
  /// GET /api/categories
  Future<List<ExpenseCategory>> getCategories();

  /// GET /api/expenses?from=yyyy-MM-dd&to=yyyy-MM-dd
  /// Tinh ca hai dau, ket qua moi nhat truoc.
  Future<List<Expense>> getExpenses({
    required DateTime from,
    required DateTime to,
  });

  /// GET /api/calendar?month=yyyy-MM
  Future<CalendarMonth> getCalendar(DateTime month);

  /// GET /api/budgets?month=yyyy-MM
  Future<BudgetOverview> getBudgets(DateTime month);
}
