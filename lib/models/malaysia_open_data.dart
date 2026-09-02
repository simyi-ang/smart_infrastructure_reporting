class PublicTransportRidership {
  final DateTime date;

  final int rapidBusKl;
  final int rapidBusKuantan;
  final int rapidBusPenang;

  final int lrtAmpang;
  final int lrtKelanaJaya;
  final int monorail;
  final int mrtKajang;
  final int mrtPutrajaya;
  final int lrtShahAlam;

  final int ets;
  final int intercity;
  final int komuter;
  final int komuterUtara;
  final int shuttleTebrau;

  const PublicTransportRidership({
    required this.date,
    required this.rapidBusKl,
    required this.rapidBusKuantan,
    required this.rapidBusPenang,
    required this.lrtAmpang,
    required this.lrtKelanaJaya,
    required this.monorail,
    required this.mrtKajang,
    required this.mrtPutrajaya,
    required this.lrtShahAlam,
    required this.ets,
    required this.intercity,
    required this.komuter,
    required this.komuterUtara,
    required this.shuttleTebrau,
  });

  factory PublicTransportRidership.fromMap(
      Map<String, dynamic> map,
      ) {
    return PublicTransportRidership(
      date:
      DateTime.tryParse(
        map['date']?.toString() ?? '',
      ) ??
          DateTime.now(),
      rapidBusKl:
      _toInt(map['bus_rkl']),
      rapidBusKuantan:
      _toInt(map['bus_rkn']),
      rapidBusPenang:
      _toInt(map['bus_rpn']),
      lrtAmpang:
      _toInt(map['rail_lrt_ampang']),
      lrtKelanaJaya:
      _toInt(map['rail_lrt_kj']),
      monorail:
      _toInt(map['rail_monorail']),
      mrtKajang:
      _toInt(map['rail_mrt_kajang']),
      mrtPutrajaya:
      _toInt(map['rail_mrt_pjy']),
      lrtShahAlam:
      _toInt(map['rail_lrt_shah_alam']),
      ets:
      _toInt(map['rail_ets']),
      intercity:
      _toInt(map['rail_intercity']),
      komuter:
      _toInt(map['rail_komuter']),
      komuterUtara:
      _toInt(map['rail_komuter_utara']),
      shuttleTebrau:
      _toInt(map['rail_tebrau']),
    );
  }

  static int _toInt(
      dynamic value,
      ) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value.toString(),
    ) ??
        0;
  }

  int get busTotal =>
      rapidBusKl +
          rapidBusKuantan +
          rapidBusPenang;

  int get railTotal =>
      lrtAmpang +
          lrtKelanaJaya +
          monorail +
          mrtKajang +
          mrtPutrajaya +
          lrtShahAlam +
          ets +
          intercity +
          komuter +
          komuterUtara +
          shuttleTebrau;

  int get totalTrips =>
      busTotal + railTotal;

  Map<String, int> get serviceTrips => {
    'Rapid Bus (KL)':
    rapidBusKl,
    'Rapid Bus (Kuantan)':
    rapidBusKuantan,
    'Rapid Bus (Penang)':
    rapidBusPenang,
    'LRT Ampang Line':
    lrtAmpang,
    'LRT Kelana Jaya Line':
    lrtKelanaJaya,
    'Monorail Line':
    monorail,
    'MRT Kajang Line':
    mrtKajang,
    'MRT Putrajaya Line':
    mrtPutrajaya,
    'LRT Shah Alam Line':
    lrtShahAlam,
    'KTMB ETS':
    ets,
    'KTM Intercity':
    intercity,
    'KTM Komuter':
    komuter,
    'KTM Komuter Utara':
    komuterUtara,
    'KTM Shuttle Tebrau':
    shuttleTebrau,
  };

  List<MapEntry<String, int>>
  get topServices {
    final entries =
    serviceTrips.entries
        .where(
          (entry) =>
      entry.value > 0,
    )
        .toList();

    entries.sort(
          (a, b) =>
          b.value.compareTo(
            a.value,
          ),
    );

    return entries.take(5).toList();
  }
}

class MalaysiaOpenDataSummary {
  final PublicTransportRidership latest;
  final List<PublicTransportRidership> recent;

  const MalaysiaOpenDataSummary({
    required this.latest,
    required this.recent,
  });

  int get previousTotal {
    if (recent.length < 2) {
      return 0;
    }

    return recent[1].totalTrips;
  }

  double? get dailyChangePercentage {
    final previous =
        previousTotal;

    if (previous <= 0) {
      return null;
    }

    return ((latest.totalTrips - previous) /
        previous) *
        100;
  }
}
