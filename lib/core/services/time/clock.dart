/// Single clock abstraction for business flows that need current time.
abstract interface class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

class BusinessDateService {
  final Clock _clock;

  const BusinessDateService({Clock clock = const SystemClock()})
    : _clock = clock;

  DateTime currentBusinessDate() {
    final now = _clock.now();
    return DateTime(now.year, now.month, now.day);
  }
}
