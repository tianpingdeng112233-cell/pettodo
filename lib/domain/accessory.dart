enum AccessoryAnchor {
  head,
  neck;

  static AccessoryAnchor? fromName(String value) {
    for (final anchor in values) {
      if (anchor.name == value) return anchor;
    }
    return null;
  }
}

class AccessoryItem {
  const AccessoryItem({
    required this.id,
    required this.name,
    required this.anchor,
    required this.price,
  });

  final String id;
  final String name;
  final AccessoryAnchor anchor;
  final int price;
}

const AccessoryItem woolHat = AccessoryItem(
  id: 'wool_hat',
  name: 'Wool Hat',
  anchor: AccessoryAnchor.head,
  price: 20,
);
const AccessoryItem strawHat = AccessoryItem(
  id: 'straw_hat',
  name: 'Straw Hat',
  anchor: AccessoryAnchor.head,
  price: 25,
);
const AccessoryItem partyHat = AccessoryItem(
  id: 'party_hat',
  name: 'Party Hat',
  anchor: AccessoryAnchor.head,
  price: 30,
);
const AccessoryItem redScarf = AccessoryItem(
  id: 'red_scarf',
  name: 'Red Scarf',
  anchor: AccessoryAnchor.neck,
  price: 15,
);
const AccessoryItem plaidScarf = AccessoryItem(
  id: 'plaid_scarf',
  name: 'Plaid Scarf',
  anchor: AccessoryAnchor.neck,
  price: 25,
);
const AccessoryItem bellCollar = AccessoryItem(
  id: 'bell_collar',
  name: 'Bell Collar',
  anchor: AccessoryAnchor.neck,
  price: 20,
);

const List<AccessoryItem> accessoryCatalog = <AccessoryItem>[
  woolHat,
  strawHat,
  partyHat,
  redScarf,
  plaidScarf,
  bellCollar,
];

AccessoryItem? accessoryById(String id) {
  for (final item in accessoryCatalog) {
    if (item.id == id) return item;
  }
  return null;
}
