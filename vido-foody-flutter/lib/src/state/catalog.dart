/// Mock catalog for the demo. Replace with API calls in production.
class Product {
  final String id, name, emoji, category;
  final double price;
  final bool hasOptions;
  const Product({
    required this.id, required this.name, required this.emoji,
    required this.category, required this.price, this.hasOptions = false,
  });
}

class Category {
  final String id, name, icon;
  const Category({required this.id, required this.name, required this.icon});
}

const kCategories = <Category>[
  Category(id: 'drink',   name: 'Drinks',  icon: '🧋'),
  Category(id: 'coffee',  name: 'Coffee',  icon: '☕'),
  Category(id: 'food',    name: 'Food',    icon: '🍔'),
  Category(id: 'dessert', name: 'Dessert', icon: '🍰'),
];

const kProducts = <Product>[
  Product(id: 'p1',  category: 'drink',   name: 'Bubble Milk Tea',       emoji: '🧋', price: 4.50, hasOptions: true),
  Product(id: 'p2',  category: 'drink',   name: 'Strawberry Sting',      emoji: '🥤', price: 1.80, hasOptions: true),
  Product(id: 'p3',  category: 'drink',   name: 'Fresh Orange Juice',    emoji: '🍊', price: 3.20, hasOptions: true),
  Product(id: 'p4',  category: 'drink',   name: 'Lemon Soda',            emoji: '🍋', price: 2.50, hasOptions: true),
  Product(id: 'p5',  category: 'coffee',  name: 'Iced Milk Coffee',      emoji: '☕', price: 3.50, hasOptions: true),
  Product(id: 'p6',  category: 'coffee',  name: 'Iced White Coffee',     emoji: '🥛', price: 3.80, hasOptions: true),
  Product(id: 'p7',  category: 'coffee',  name: 'Espresso',              emoji: '☕', price: 2.80),
  Product(id: 'p8',  category: 'coffee',  name: 'Cappuccino',            emoji: '☕', price: 4.20),
  Product(id: 'p9',  category: 'food',    name: 'Grilled Pork Banh Mi',  emoji: '🥖', price: 4.00),
  Product(id: 'p10', category: 'food',    name: 'Rare Beef Pho',         emoji: '🍜', price: 7.50),
  Product(id: 'p11', category: 'food',    name: 'Chicken Burger',        emoji: '🍔', price: 6.20),
  Product(id: 'p12', category: 'food',    name: 'Pizza Margherita',      emoji: '🍕', price: 8.50),
  Product(id: 'p13', category: 'dessert', name: 'Three-Color Soup',      emoji: '🍧', price: 3.00),
  Product(id: 'p14', category: 'dessert', name: 'Caramel Flan',          emoji: '🍮', price: 2.50),
  Product(id: 'p15', category: 'dessert', name: 'Coconut Ice Cream',     emoji: '🍨', price: 3.50),
];

const double kTaxRate = 0.08;
const String kCurrencySymbol = '\$';
