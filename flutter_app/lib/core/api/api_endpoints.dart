class ApiEndpoints {
  ApiEndpoints._();

  static const login = '/auth/login';
  static const registerSendOtp = '/auth/register/send-otp';
  static const registerVerifyOtp = '/auth/register/verify-otp';
  static const refresh = '/auth/refresh';
  static const logout = '/auth/logout';
  static const forgotPassword = '/auth/forgot-password';
  static const forgotPasswordVerifyOtp = '/auth/forgot-password/verify-otp';
  static const resetPassword = '/auth/reset-password';
  static const changePassword = '/auth/change-password';
  static const me = '/auth/me';
  static const subscriptionStatus = '/subscription/status';
  static const dashboard = '/dashboard/summary';
  static const markets = '/markets';
  static const entries = '/entries';
  static const results = '/results';
  static const users = '/users';
  static const settings = '/settings';
  static const auditLogs = '/audit-logs';
  static const receipts = '/receipts';
  static const receiptSearch = '/receipts/search';
  static const currentGameConfig = '/game-configs/current';
  static const prints = '/prints';
  static const printSearch = '/prints/search';
  static const shareRecords = '/share-records';
}
