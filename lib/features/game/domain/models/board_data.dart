
enum BoardSpaceType {
  property,
  railroad,
  utility,
  tax,
  corner,
  chance,
  communityChest,
}

class BoardSpaceData {
  final int index;
  final String name;
  final BoardSpaceType type;
  final int? price;
  final String? colorHex; // For properties
  final int? rentIndex; // Group properties
  final int? baseRent; // Base rent amount for this property

  const BoardSpaceData({
    required this.index,
    required this.name,
    required this.type,
    this.price,
    this.colorHex,
    this.rentIndex,
    this.baseRent,
  });

  /// Whether this space can be purchased by a player.
  bool get isBuyable =>
      type == BoardSpaceType.property ||
      type == BoardSpaceType.railroad ||
      type == BoardSpaceType.utility;
}

// 8x8 Grid Board - 28 spaces around the perimeter
// Symmetrical: 7 spaces per side (including 1 corner per side)
// Indices:
// 0: GO (Bottom-Left)
// 1-6: Bottom Row (indices 1-6)
// 7: Jail (Bottom-Right)
// 8-13: Right Column
// 14: Free Parking (Top-Right)
// 15-20: Top Row
// 21: Go To Jail (Top-Left)
// 22-27: Left Column
const List<BoardSpaceData> monopolyBoard = [
  // Bottom Row (Left to Right): 0-7
  BoardSpaceData(index: 0, name: "GO", type: BoardSpaceType.corner),
  BoardSpaceData(index: 1, name: "MG Road", type: BoardSpaceType.property, price: 60, colorHex: "#8B4513", baseRent: 4),
  BoardSpaceData(index: 2, name: "Brigade Rd", type: BoardSpaceType.property, price: 60, colorHex: "#8B4513", baseRent: 4),
  BoardSpaceData(index: 3, name: "Income Tax", type: BoardSpaceType.tax, price: 200),
  BoardSpaceData(index: 4, name: "Indiranagar", type: BoardSpaceType.property, price: 100, colorHex: "#87CEEB", baseRent: 8),
  BoardSpaceData(index: 5, name: "Koramangala", type: BoardSpaceType.property, price: 120, colorHex: "#87CEEB", baseRent: 10),
  BoardSpaceData(index: 6, name: "Metro Rail", type: BoardSpaceType.railroad, price: 200, baseRent: 25),
  
  // Bottom-Right Corner
  BoardSpaceData(index: 7, name: "Jail", type: BoardSpaceType.corner),
  
  // Right Column (Bottom to Top): 8-13
  BoardSpaceData(index: 8, name: "Jayanagar", type: BoardSpaceType.property, price: 140, colorHex: "#FF00FF", baseRent: 12),
  BoardSpaceData(index: 9, name: "JP Nagar", type: BoardSpaceType.property, price: 140, colorHex: "#FF00FF", baseRent: 12),
  BoardSpaceData(index: 10, name: "BESCOM", type: BoardSpaceType.utility, price: 150, baseRent: 20),
  BoardSpaceData(index: 11, name: "BTM Layout", type: BoardSpaceType.property, price: 160, colorHex: "#FF00FF", baseRent: 14),
  BoardSpaceData(index: 12, name: "Community", type: BoardSpaceType.communityChest),
  BoardSpaceData(index: 13, name: "HSR Layout", type: BoardSpaceType.property, price: 180, colorHex: "#FFA500", baseRent: 16),
  
  // Top-Right Corner
  BoardSpaceData(index: 14, name: "Free Parking", type: BoardSpaceType.corner),
  
  // Top Row (Right to Left): 15-20
  BoardSpaceData(index: 15, name: "Whitefield", type: BoardSpaceType.property, price: 200, colorHex: "#FF0000", baseRent: 18),
  BoardSpaceData(index: 16, name: "ITPL", type: BoardSpaceType.property, price: 220, colorHex: "#FF0000", baseRent: 20),
  BoardSpaceData(index: 17, name: "Chance", type: BoardSpaceType.chance),
  BoardSpaceData(index: 18, name: "Electronic City", type: BoardSpaceType.property, price: 240, colorHex: "#FF0000", baseRent: 22),
  BoardSpaceData(index: 19, name: "Namma Metro", type: BoardSpaceType.railroad, price: 200, baseRent: 25),
  BoardSpaceData(index: 20, name: "Malleshwaram", type: BoardSpaceType.property, price: 260, colorHex: "#FFFF00", baseRent: 24),
  
  // Top-Left Corner
  BoardSpaceData(index: 21, name: "Go To Jail", type: BoardSpaceType.corner),
  
  // Left Column (Top to Bottom): 22-27
  BoardSpaceData(index: 22, name: "Rajajinagar", type: BoardSpaceType.property, price: 280, colorHex: "#FFFF00", baseRent: 26),
  BoardSpaceData(index: 23, name: "Sadashivanagar", type: BoardSpaceType.property, price: 300, colorHex: "#008000", baseRent: 28),
  BoardSpaceData(index: 24, name: "BWSSB", type: BoardSpaceType.utility, price: 150, baseRent: 20),
  BoardSpaceData(index: 25, name: "Palace Ground", type: BoardSpaceType.property, price: 320, colorHex: "#008000", baseRent: 30),
  BoardSpaceData(index: 26, name: "Luxury Tax", type: BoardSpaceType.tax, price: 100),
  BoardSpaceData(index: 27, name: "UB City", type: BoardSpaceType.property, price: 400, colorHex: "#0000FF", baseRent: 40),
];

// Total board spaces
const int totalBoardSpaces = 28;

enum CardType { chance, communityChest }

class GameCard {
  final String text;
  final String actionId;
  final int? value; // For money or position
  
  const GameCard({required this.text, required this.actionId, this.value});
}

const List<GameCard> chanceCards = [
  GameCard(text: "Advance to GO (Collect ₹200)", actionId: "advance_to", value: 0),
  GameCard(text: "Advance to Whitefield", actionId: "advance_to", value: 15),
  GameCard(text: "Bank pays you dividend of ₹50", actionId: "money", value: 50),
  GameCard(text: "Go to Jail", actionId: "go_to_jail"),
  GameCard(text: "Speeding fine ₹15", actionId: "money", value: -15),
  GameCard(text: "You won a lottery! Collect ₹100", actionId: "money", value: 100),
  GameCard(text: "Get Out of Jail Free!", actionId: "get_out_of_jail_free"),
];

const List<GameCard> communityChestCards = [
  GameCard(text: "Advance to GO (Collect ₹200)", actionId: "advance_to", value: 0),
  GameCard(text: "Bank error in your favor. Collect ₹200", actionId: "money", value: 200),
  GameCard(text: "Doctor's fees. Pay ₹50", actionId: "money", value: -50),
  GameCard(text: "Go to Jail", actionId: "go_to_jail"),
  GameCard(text: "From sale of stock you get ₹50", actionId: "money", value: 50),
  GameCard(text: "Income tax refund. Collect ₹20", actionId: "money", value: 20),
  GameCard(text: "Get Out of Jail Free!", actionId: "get_out_of_jail_free"),
];

/// #10: Shuffled card deck — cards are drawn sequentially, reshuffled when exhausted.
class CardDeck {
  final List<GameCard> _cards;
  late List<GameCard> _shuffled;
  int _currentIndex = 0;

  CardDeck(this._cards) {
    _reshuffle();
  }

  void _reshuffle() {
    _shuffled = List.from(_cards)..shuffle();
    _currentIndex = 0;
  }

  GameCard draw() {
    if (_currentIndex >= _shuffled.length) {
      _reshuffle();
    }
    return _shuffled[_currentIndex++];
  }
}

