import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A small set of booking ids with an expiry, shared across isolates.
///
/// SharedPreferences is the store because the readers and writers genuinely
/// live in different isolates: the overlay card runs in the overlay engine,
/// the request list runs in the app, and neither can see the other's memory.
/// Everything here is written as `<id>|<millisecondsSinceEpoch>` so entries
/// can age out rather than accumulating forever.
class _StampedIdStore {
  const _StampedIdStore(this.key, this.retention);

  final String key;
  final Duration retention;

  /// Reads the live (non-expired) ids.
  Future<Set<String>> read() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      // Required: the value may have been written by another isolate, and
      // without this the snapshot loaded at startup is what gets read.
      await prefs.reload();
      return _live(prefs).ids;
    } catch (e) {
      debugPrint('[$key] unavailable for reading: $e');
      return <String>{};
    }
  }

  /// Adds [ids], keeping the store pruned. Returns the ids that were NOT
  /// already present — i.e. the ones this call actually claimed.
  Future<Set<String>> add(Set<String> ids) async {
    final Set<String> wanted = ids
        .map((String id) => id.trim())
        .where((String id) => id.isNotEmpty)
        .toSet();
    if (wanted.isEmpty) return <String>{};

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final _Live live = _live(prefs);
      final Set<String> granted = wanted.difference(live.ids);
      if (granted.isEmpty) return granted;

      final int now = DateTime.now().millisecondsSinceEpoch;
      final List<String> kept = List<String>.from(live.entries);
      for (final String id in granted) {
        kept.add('$id|$now');
      }
      await prefs.setStringList(key, kept);
      return granted;
    } catch (e) {
      // No shared store — most likely the plugin not registered on this
      // isolate. Granting everything is the right failure for both users of
      // this class: a ride that rings twice, or one that is offered again
      // after a decline, is an annoyance; a ride that never appears is a lost
      // fare.
      debugPrint('[$key] unavailable for writing: $e');
      return ids;
    }
  }

  _Live _live(SharedPreferences prefs) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final List<String> entries = <String>[];
    final Set<String> ids = <String>{};

    for (final String entry in prefs.getStringList(key) ?? const <String>[]) {
      final int separator = entry.lastIndexOf('|');
      if (separator <= 0) continue;
      final int stamp = int.tryParse(entry.substring(separator + 1)) ?? 0;
      if (now - stamp > retention.inMilliseconds) continue;
      entries.add(entry);
      ids.add(entry.substring(0, separator));
    }
    return _Live(entries, ids);
  }
}

class _Live {
  const _Live(this.entries, this.ids);
  final List<String> entries;
  final Set<String> ids;
}

/// Remembers which ride offers have already been announced out loud, so no
/// single offer can ever sound twice.
///
/// Shared state, and it has to be: the alert tone is played by two completely
/// independent players living in two different isolates — the overlay card's
/// (IncomingRideOverlay, for offers that arrive while the app is closed) and
/// the app's own (HomeController, off the 3s nearby-bookings poll). Neither can
/// see the other's state, and the normal path crosses both: a ride is offered
/// while the app is closed, the overlay announces it, the driver opens the app
/// to answer — and the poll, meeting that booking for the first time in its own
/// memory, announced it all over again.
class RideAlertMemory {
  RideAlertMemory._();

  /// Comfortably longer than any single offer's life — an offer times out in
  /// 20s — and short enough that the same booking id reaching the same driver
  /// much later is a genuinely new alert rather than one silently suppressed.
  static const _StampedIdStore _store =
      _StampedIdStore('overlay_rung_bookings', Duration(minutes: 10));

  /// Claims the right to announce [bookingId], returning false if something
  /// already has.
  ///
  /// Claim-and-check in one call deliberately: two callers asking "has this
  /// rung?" and then both ringing is the exact race this exists to prevent.
  static Future<bool> claim(String bookingId) async {
    final String id = bookingId.trim();
    if (id.isEmpty) return true;
    return (await _store.add(<String>{id})).contains(id);
  }

  /// Claims a whole batch at once, returning only the ids that were actually
  /// free to claim. Used by the in-app poll, which can meet several new
  /// requests in a single tick.
  static Future<Set<String>> claimAll(Set<String> bookingIds) =>
      _store.add(bookingIds);
}

/// Remembers which ride offers the driver has turned down, so a decline
/// actually sticks.
///
/// There is no decline endpoint — declining has always been a client-side act
/// (see HomeController.rejectTrip) — so nothing tells the backend, and the
/// nearby-bookings poll happily hands the same booking straight back on its
/// next tick. From the driver's seat that is the app ignoring them: they
/// dismiss a card and it reappears seconds later.
///
/// Kept here rather than in HomeController because a decline can happen in the
/// overlay's isolate while the app is not running at all, and it has to be
/// visible to the app's own list when it next looks.
///
/// This does not replace a real decline endpoint. It makes the driver's
/// decision hold on their own device until one exists.
class RideDeclineMemory {
  RideDeclineMemory._();

  /// Long enough that a declined ride does not come straight back, short
  /// enough that it is not a permanent ban: a booking still unclaimed several
  /// minutes later is a different proposition to the driver than the one they
  /// waved away, and they may well want it the second time.
  static const _StampedIdStore _store =
      _StampedIdStore('declined_bookings', Duration(minutes: 5));

  static Future<void> remember(String? bookingId) async {
    final String id = (bookingId ?? '').trim();
    if (id.isEmpty) return;
    await _store.add(<String>{id});
    debugPrint('[RideDeclineMemory] booking $id declined — suppressing it');
  }

  /// The bookings that should not be offered to this driver right now.
  static Future<Set<String>> declined() => _store.read();
}
