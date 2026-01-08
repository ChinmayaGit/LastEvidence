enum Room {
  hall('Hall'),
  lounge('Lounge'),
  diningRoom('Dining Room'),
  kitchen('Kitchen'),
  ballroom('Ballroom'),
  conservatory('Conservatory'),
  billiardRoom('Billiard Room'),
  library('Library'),
  study('Study');

  final String name;
  const Room(this.name);
  
  // Secret passages (from original Clue game)
  Room? get secretPassage {
    switch (this) {
      case Room.study:
        return Room.kitchen;
      case Room.kitchen:
        return Room.study;
      case Room.conservatory:
        return Room.lounge;
      case Room.lounge:
        return Room.conservatory;
      default:
        return null;
    }
  }
}



