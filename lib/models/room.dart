enum Room {
  hall('Grand Hall'),
  lounge('Sky Lounge'),
  diningRoom('Banquet Hall'),
  kitchen('Chef Kitchen'),
  basement('Secret Basement'),
  rooftopPool('Rooftop Pool'),
  garden('Hidden Garden'),
  library('Silent Library'),
  study('Private Study');

  final String name;
  const Room(this.name);

  String get assetPath {
    switch (this) {
      case Room.hall:
        return 'assets/room/Hall.jpg';
      case Room.lounge:
        return 'assets/room/Lounge.jpg';
      case Room.diningRoom:
        return 'assets/room/Dining Room.jpg';
      case Room.kitchen:
        return 'assets/room/Kitchen.jpg';
      case Room.basement:
        return 'assets/room/Basement.jpg';
      case Room.rooftopPool:
        return 'assets/room/Pool.jpg';
      case Room.garden:
        return 'assets/room/Garden.jpg';
      case Room.library:
        return 'assets/room/Library.jpg';
      case Room.study:
        return 'assets/room/Study.jpg';
    }
  }

  static Room? fromName(String value) {
    try {
      return Room.values.firstWhere((r) => r.name == value);
    } catch (_) {
      return null;
    }
  }
  
  // Secret passages (from original Clue game)
  Room? get secretPassage {
    switch (this) {
      case Room.study:
        return Room.kitchen;
      case Room.kitchen:
        return Room.study;
      case Room.rooftopPool:
        return Room.lounge;
      case Room.lounge:
        return Room.rooftopPool;
      default:
        return null;
    }
  }
}



