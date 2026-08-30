enum FurnitureSlot {
  window,
  wallArt,
  wallClock,
  bed,
  rug,
  bookshelf,
  floorLamp,
  plant,
  toy,
  rockingChair;

  static FurnitureSlot? fromName(String value) {
    for (final slot in values) {
      if (slot.name == value) return slot;
    }
    return null;
  }
}

enum FurnitureSource { threshold, price }

class FurnitureItem {
  const FurnitureItem.threshold({
    required this.id,
    required this.name,
    required this.slot,
    required this.threshold,
    required this.legacyDecorId,
  }) : source = FurnitureSource.threshold,
       assert(threshold != null),
       price = null;

  const FurnitureItem.price({
    required this.id,
    required this.name,
    required this.slot,
    required this.price,
  }) : source = FurnitureSource.price,
       threshold = null,
       legacyDecorId = null,
       assert(price != null);

  final String id;
  final String name;
  final FurnitureSlot slot;
  final FurnitureSource source;
  final int? threshold;
  final int? price;
  final String? legacyDecorId;
}

const FurnitureItem rug = FurnitureItem.threshold(
  id: 'rug',
  name: 'Little Rug',
  slot: FurnitureSlot.rug,
  threshold: 5,
  legacyDecorId: 'soft_ball',
);
const FurnitureItem plant = FurnitureItem.threshold(
  id: 'plant',
  name: 'Potted Plant',
  slot: FurnitureSlot.plant,
  threshold: 15,
  legacyDecorId: 'flower',
);
const FurnitureItem bed = FurnitureItem.threshold(
  id: 'bed',
  name: 'Pet Bed',
  slot: FurnitureSlot.bed,
  threshold: 30,
  legacyDecorId: 'home',
);
const FurnitureItem bookshelf = FurnitureItem.threshold(
  id: 'bookshelf',
  name: 'Bookshelf',
  slot: FurnitureSlot.bookshelf,
  threshold: 50,
  legacyDecorId: 'blanket',
);
const FurnitureItem floorLamp = FurnitureItem.threshold(
  id: 'floor_lamp',
  name: 'Floor Lamp',
  slot: FurnitureSlot.floorLamp,
  threshold: 80,
  legacyDecorId: 'lamp',
);
const FurnitureItem curtainWindow = FurnitureItem.threshold(
  id: 'curtain_window',
  name: 'Dreamy Curtain Window',
  slot: FurnitureSlot.window,
  threshold: 120,
  legacyDecorId: 'window',
);

const FurnitureItem wallArt = FurnitureItem.price(
  id: 'wall_art',
  name: 'Wall Art',
  slot: FurnitureSlot.wallArt,
  price: 25,
);
const FurnitureItem rockingChair = FurnitureItem.price(
  id: 'rocking_chair',
  name: 'Cushioned Rocking Chair',
  slot: FurnitureSlot.rockingChair,
  price: 40,
);
const FurnitureItem toyBasket = FurnitureItem.price(
  id: 'toy_basket',
  name: 'Toy Basket',
  slot: FurnitureSlot.toy,
  price: 30,
);
const FurnitureItem wallClock = FurnitureItem.price(
  id: 'wall_clock',
  name: 'Wall Clock',
  slot: FurnitureSlot.wallClock,
  price: 20,
);
const FurnitureItem storageCabinet = FurnitureItem.price(
  id: 'storage_cabinet',
  name: 'Storage Cabinet',
  slot: FurnitureSlot.bookshelf,
  price: 35,
);
const FurnitureItem starStringLights = FurnitureItem.price(
  id: 'star_string_lights',
  name: 'Star String Lights',
  slot: FurnitureSlot.window,
  price: 25,
);

const List<FurnitureItem> furnitureCatalog = <FurnitureItem>[
  rug,
  plant,
  bed,
  bookshelf,
  floorLamp,
  curtainWindow,
  wallArt,
  rockingChair,
  toyBasket,
  wallClock,
  storageCabinet,
  starStringLights,
];

final List<FurnitureItem> milestoneFurniture = List<FurnitureItem>.unmodifiable(
  furnitureCatalog.where((item) => item.source == FurnitureSource.threshold),
);

final List<FurnitureItem> storeFurniture = List<FurnitureItem>.unmodifiable(
  furnitureCatalog.where((item) => item.source == FurnitureSource.price),
);

FurnitureItem? furnitureById(String id) {
  for (final item in furnitureCatalog) {
    if (item.id == id) return item;
  }
  return null;
}
