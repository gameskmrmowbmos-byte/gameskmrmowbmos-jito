import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final _date = DateFormat('dd MMM yyyy');
  static final _dateTime = DateFormat('dd MMM yyyy, hh:mm a');
  static String date(DateTime? value) =>
      value == null ? '—' : _date.format(value);
  static String dateTime(DateTime? value) =>
      value == null ? '—' : _dateTime.format(value);
  static String label(String value) => value
      .split('_')
      .map((part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
