import 'package:flutter/painting.dart';

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

  /// PUT /api/budgets: dat muc tieu chi (ngan sach tong) cua thang (FR-16).
  /// Doi han muc thi dat lai trang thai da canh bao (BR-04).
  Future<void> setMonthlyBudget(DateTime month, int limit);

  /// POST /api/expenses
  /// Tra ve khoan chi vua tao va canh bao ngan sach (neu co).
  Future<ExpenseSaveResult> addExpense(ExpenseDraft draft);

  /// POST /api/expenses/{id}/photos (multipart: file, isReceipt)
  /// filePath la anh DA NEN theo BR-05.
  Future<ExpensePhoto> uploadPhoto(
    int expenseId,
    String filePath, {
    bool isReceipt = false,
  });

  /// Nguon hien thi anh. Null thi giao dien ve khung soc thay the.
  /// Ban API: NetworkImage('$baseUrl/api/photos/$photoId',
  ///   headers: {'Authorization': 'Bearer $token'}).
  ImageProvider? photoImage(int photoId);
}