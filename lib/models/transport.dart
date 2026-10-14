/// Trains, buses and the demo seat-booking trips.
library;

List<String> _strings(dynamic v) =>
    v is List ? v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() : const [];

String _s(dynamic v) => v == null ? '' : v.toString();

/// One train number through Joypurhat, in one direction.
class TrainRun {
  const TrainRun({
    required this.number,
    required this.to,
    required this.origin,
    this.arr = '',
    this.dep = '',
    this.offDay,
    this.offConflict = false,
  });

  final String number;
  final String to;
  final String origin;
  final String arr;
  final String dep;

  /// 0 Sunday ... 6 Saturday, counted at the starting station.
  final int? offDay;
  final bool offConflict;

  /// Departure from Joypurhat, or arrival when only that is known.
  String get time => dep.isNotEmpty ? dep : arr;

  factory TrainRun.fromJson(Map<String, dynamic> j) => TrainRun(
        number: _s(j['name']),
        to: _s(j['to']),
        origin: _s(j['origin']),
        arr: _s(j['arr']),
        dep: _s(j['dep']),
        offDay: (j['offDay'] as num?)?.toInt(),
        offConflict: j['offConflict'] == true,
      );
}

class FareClass {
  const FareClass(this.cls, this.fare);
  final String cls;
  final String fare;
}

class TrainFare {
  const TrainFare(this.to, this.classes);
  final String to;
  final List<FareClass> classes;
}

class Train {
  const Train({
    required this.name,
    required this.nameEn,
    required this.runs,
    required this.termini,
    this.offNote = '',
    this.fares = const [],
    this.confidence = '',
    this.sources = const [],
  });

  final String name;
  final String nameEn;
  final List<TrainRun> runs;
  final String termini;
  final String offNote;
  final List<TrainFare> fares;
  final String confidence;
  final List<String> sources;

  factory Train.fromJson(Map<String, dynamic> j) => Train(
        name: _s(j['name']),
        nameEn: _s(j['nameEn']),
        runs: (j['runs'] as List).map((r) => TrainRun.fromJson(r as Map<String, dynamic>)).toList(),
        termini: _s(j['termini']),
        offNote: _s(j['offNote']),
        fares: (j['fares'] as List? ?? const [])
            .map((f) => TrainFare(
                  _s(f['to']),
                  (f['classes'] as List).map((c) => FareClass(_s(c['cls']), _s(c['fare']))).toList(),
                ))
            .toList(),
        confidence: _s(j['confidence']),
        sources: _strings(j['sources']),
      );
}

class BusCounter {
  const BusCounter(this.place, this.phones);
  final String place;
  final List<String> phones;
}

class BusOperator {
  const BusOperator({
    required this.name,
    required this.nameEn,
    required this.route,
    required this.coaches,
    required this.counters,
    this.website = '',
    this.confidence = '',
    this.sources = const [],
  });

  final String name;
  final String nameEn;
  final String route;
  final List<(String, String)> coaches;
  final List<BusCounter> counters;

  /// The company's own ticket site, when it has one.
  final String website;
  final String confidence;
  final List<String> sources;

  bool hasCoach(String type) => coaches.any((c) => c.$1 == type);

  factory BusOperator.fromJson(Map<String, dynamic> j) => BusOperator(
        name: _s(j['name']),
        nameEn: _s(j['nameEn']),
        route: _s(j['route']),
        coaches: (j['coaches'] as List).map((c) => (_s(c['coach']), _s(c['fare']))).toList(),
        counters: (j['counters'] as List)
            .map((c) => BusCounter(_s(c['place']), _strings(c['phones'])))
            .toList(),
        website: _s(j['website']),
        confidence: _s(j['confidence']),
        sources: _strings(j['sources']),
      );
}

class TransportPlace {
  const TransportPlace({required this.name, required this.nameEn, required this.mapQuery, this.lat, this.lng});
  final String name;
  final String nameEn;
  final String mapQuery;
  final double? lat;
  final double? lng;

  factory TransportPlace.fromJson(Map<String, dynamic> j) => TransportPlace(
        name: _s(j['name']),
        nameEn: _s(j['nameEn']),
        mapQuery: _s(j['mapQuery']),
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
      );
}

class RailInfo {
  const RailInfo({
    required this.ticketUrl,
    required this.appName,
    required this.appPackage,
    required this.callCentre,
    required this.smsNumber,
    required this.smsFormat,
    required this.smsNote,
    required this.sources,
    this.ticketNote = '',
    this.appSupport = '',
  });

  final String ticketUrl;
  final String appName;
  final String appPackage;
  final String callCentre;
  final String smsNumber;
  final String smsFormat;
  final String smsNote;
  final List<String> sources;

  /// Warning about tickets sold at a mark-up on social media.
  final String ticketNote;

  /// Help line of the railway ticket app.
  final String appSupport;

  factory RailInfo.fromJson(Map<String, dynamic> j) => RailInfo(
        ticketUrl: _s(j['ticketUrl']),
        appName: _s(j['appName']),
        appPackage: _s(j['appPackage']),
        callCentre: _s(j['callCentre']),
        smsNumber: _s(j['smsNumber']),
        smsFormat: _s(j['smsFormat']),
        smsNote: _s(j['smsNote']),
        sources: _strings(j['sources']),
        ticketNote: _s(j['ticketNote']),
        appSupport: _s(j['appSupport']),
      );

  String smsBody(String trainNumber) => smsFormat.replaceAll('{number}', trainNumber);
}

/// A station on the line through Joypurhat, with how many minutes before
/// Joypurhat a southbound train passes it and its place on the drawn map
/// (percent of width and height).
class LineStation {
  const LineStation({required this.name, required this.min, required this.x, required this.y});
  final String name;
  final int min;
  final double x;
  final double y;

  factory LineStation.fromJson(Map<String, dynamic> j) => LineStation(
        name: _s(j['name']),
        min: (j['min'] as num).toInt(),
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
      );
}

/// A site that sells bus tickets online.
class TicketSite {
  const TicketSite({
    required this.name,
    required this.sub,
    required this.url,
    this.helpline = '',
    this.hours = '',
    this.sources = const [],
  });
  final String name;
  final String sub;
  final String url;
  final String helpline;
  final String hours;
  final List<String> sources;

  factory TicketSite.fromJson(Map<String, dynamic> j) => TicketSite(
        name: _s(j['name']),
        sub: _s(j['sub']),
        url: _s(j['url']),
        helpline: _s(j['helpline']),
        hours: _s(j['hours']),
        sources: _strings(j['sources']),
      );
}

class TripStop {
  const TripStop(this.name, this.time);
  final String name;
  final String time;
}

/// An invented bus trip for the seat-booking demo.
class DemoTrip {
  const DemoTrip({
    required this.id,
    required this.name,
    required this.coach,
    required this.tag,
    required this.time,
    required this.route,
    required this.address,
    required this.fare,
    required this.rows,
    required this.hold,
    required this.boards,
    required this.stops,
    required this.live,
    required this.mapQuery,
    required this.brtc,
  });

  final int id;
  final String name;
  final String coach;
  final String tag;
  final String time;
  final String route;
  final String address;

  /// 0 when the fare is paid at the counter.
  final int fare;
  final int rows;
  final String hold;
  final List<String> boards;
  final List<TripStop> stops;
  final Map<String, dynamic> live;
  final String mapQuery;
  final bool brtc;

  factory DemoTrip.fromJson(int id, Map<String, dynamic> j) => DemoTrip(
        id: id,
        name: _s(j['name']),
        coach: _s(j['coach']),
        tag: _s(j['tag']),
        time: _s(j['time']),
        route: _s(j['route']),
        address: _s(j['address']),
        fare: (j['fare'] as num?)?.toInt() ?? 0,
        rows: (j['rows'] as num?)?.toInt() ?? 10,
        hold: _s(j['hold']),
        boards: _strings(j['boards']),
        stops: (j['stops'] as List? ?? const []).map((s) => TripStop(_s(s['name']), _s(s['time']))).toList(),
        live: (j['live'] as Map<String, dynamic>?) ?? const {},
        mapQuery: _s(j['mapQuery']),
        brtc: j['brtc'] == true,
      );
}

class TransportData {
  const TransportData({
    required this.trains,
    required this.buses,
    required this.places,
    required this.rail,
    required this.demoTrips,
    required this.note,
    this.line = const [],
    this.busOnline = const [],
  });

  final List<Train> trains;
  final List<BusOperator> buses;
  final List<TransportPlace> places;
  final RailInfo rail;
  final List<DemoTrip> demoTrips;
  final String note;

  /// Stations from north (Parbatipur) to south (Santahar).
  final List<LineStation> line;
  final List<TicketSite> busOnline;

  TransportPlace? place(String nameEn) {
    for (final p in places) {
      if (p.nameEn == nameEn) return p;
    }
    return null;
  }

  factory TransportData.fromJson(Map<String, dynamic> j) {
    final demo = j['demoTrips'] as List? ?? const [];
    return TransportData(
      trains: (j['trains'] as List).map((t) => Train.fromJson(t as Map<String, dynamic>)).toList(),
      buses: (j['buses'] as List).map((b) => BusOperator.fromJson(b as Map<String, dynamic>)).toList(),
      places: (j['places'] as List).map((p) => TransportPlace.fromJson(p as Map<String, dynamic>)).toList(),
      rail: RailInfo.fromJson(j['rail'] as Map<String, dynamic>),
      demoTrips: [for (var i = 0; i < demo.length; i++) DemoTrip.fromJson(i, demo[i] as Map<String, dynamic>)],
      note: _s(j['note']),
      line: (j['line'] as List? ?? const []).map((s) => LineStation.fromJson(s as Map<String, dynamic>)).toList(),
      busOnline:
          (j['busOnline'] as List? ?? const []).map((s) => TicketSite.fromJson(s as Map<String, dynamic>)).toList(),
    );
  }
}
