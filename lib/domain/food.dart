class FoodItem {
  const FoodItem({required this.id, required this.name, required this.price})
    : assert(price > 0);

  final String id;
  final String name;
  final int price;

  int get xp => price;
}

const FoodItem biscuit = FoodItem(id: 'biscuit', name: 'Pet Biscuit', price: 5);
const FoodItem chickenBites = FoodItem(
  id: 'chicken_bites',
  name: 'Chicken Bites',
  price: 12,
);
const FoodItem salmon = FoodItem(id: 'salmon', name: 'Salmon', price: 12);
const FoodItem softEgg = FoodItem(id: 'soft_egg', name: 'Soft Egg', price: 12);
const FoodItem drumstick = FoodItem(
  id: 'drumstick',
  name: 'Roast Drumstick',
  price: 30,
);
const FoodItem steak = FoodItem(id: 'steak', name: 'Steak', price: 30);
const FoodItem shrimp = FoodItem(id: 'shrimp', name: 'Shrimp', price: 30);

const List<FoodItem> foodCatalog = <FoodItem>[
  biscuit,
  chickenBites,
  salmon,
  softEgg,
  drumstick,
  steak,
  shrimp,
];

FoodItem? foodById(String id) {
  for (final item in foodCatalog) {
    if (item.id == id) return item;
  }
  return null;
}
