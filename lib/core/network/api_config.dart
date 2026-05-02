class ApiConfig {
  static const String _zrokUrl = "https://jj2fhklv294b.shares.zrok.io";
  static const String baseUrl = "$_zrokUrl/api";

  // Domain gốc để xử lý hình ảnh
  static const String domainUrl = _zrokUrl;

  // Thiết lập Timeout (Tăng lên 40s vì qua tunnel zrok đôi khi bị delay)
  // Việc này giúp App không bị treo cứng khi mạng chập chờn
  static const Duration connectTimeout = Duration(seconds: 40);
  static const Duration receiveTimeout = Duration(seconds: 40);
}