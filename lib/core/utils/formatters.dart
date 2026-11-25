String formatBytes(num? bytes, {int decimals = 1}) {
  if (bytes == null || bytes <= 0) return '—';
  const units = ['Б', 'КБ', 'МБ', 'ГБ', 'ТБ'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = value >= 100 || unit == 0 ? 0 : decimals;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}

String formatDuration(num? seconds) {
  if (seconds == null || seconds <= 0) return '—';
  final total = seconds.round();
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final secs = total % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
  return '$minutes:${secs.toString().padLeft(2, '0')}';
}

String formatEta(num? seconds) {
  if (seconds == null || seconds <= 0) return '—';
  final total = seconds.round();
  if (total < 60) return '$total сек';
  final minutes = total ~/ 60;
  final secs = total % 60;
  if (minutes < 60) {
    return '$minutes мин ${secs.toString().padLeft(2, '0')} сек';
  }
  final hours = minutes ~/ 60;
  return '$hours ч ${(minutes % 60).toString().padLeft(2, '0')} мин';
}

String formatDate(DateTime date) {
  const months = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];
  final local = date.toLocal();
  return '${local.day} ${months[local.month - 1]}, '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String formatCount(int count, String one, String few, String many) {
  final mod100 = count % 100;
  final mod10 = count % 10;
  if (mod100 >= 11 && mod100 <= 14) return '$count $many';
  if (mod10 == 1) return '$count $one';
  if (mod10 >= 2 && mod10 <= 4) return '$count $few';
  return '$count $many';
}

String pluralFiles(int count) => formatCount(count, 'файл', 'файла', 'файлов');
