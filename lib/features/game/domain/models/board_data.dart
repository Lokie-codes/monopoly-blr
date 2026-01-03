
class BoardSpaceData {
  final int index;
  final String name;
  final String type; // Property, Railroad, Utility, Tax, Corner, Chance, CommunityChest
  final int? price;
  final String? colorHex; // For properties
  final int? rentIndex; // Group properties

  const BoardSpaceData({
    required this.index,
    required this.name,
    required this.type,
    this.price,
    this.colorHex,
    this.rentIndex,
  });
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
  BoardSpaceData(index: 0, name: "GO", type: "Corner"),
  BoardSpaceData(index: 1, name: "MG Road", type: "Property", price: 60, colorHex: "#8B4513"),
  BoardSpaceData(index: 2, name: "Brigade Rd", type: "Property", price: 60, colorHex: "#8B4513"),
  BoardSpaceData(index: 3, name: "Chance", type: "Chance"),
  BoardSpaceData(index: 4, name: "Indiranagar", type: "Property", price: 100, colorHex: "#87CEEB"),
  BoardSpaceData(index: 5, name: "Koramangala", type: "Property", price: 120, colorHex: "#87CEEB"),
  BoardSpaceData(index: 6, name: "Metro Rail", type: "Railroad", price: 200),
  
  // Bottom-Right Corner
  BoardSpaceData(index: 7, name: "Jail", type: "Corner"),
  
  // Right Column (Bottom to Top): 8-13
  BoardSpaceData(index: 8, name: "Jayanagar", type: "Property", price: 140, colorHex: "#FF00FF"),
  BoardSpaceData(index: 9, name: "JP Nagar", type: "Property", price: 140, colorHex: "#FF00FF"),
  BoardSpaceData(index: 10, name: "BESCOM", type: "Utility", price: 150),
  BoardSpaceData(index: 11, name: "BTM Layout", type: "Property", price: 160, colorHex: "#FF00FF"),
  BoardSpaceData(index: 12, name: "Community", type: "CommunityChest"),
  BoardSpaceData(index: 13, name: "HSR Layout", type: "Property", price: 180, colorHex: "#FFA500"),
  
  // Top-Right Corner
  BoardSpaceData(index: 14, name: "Free Parking", type: "Corner"),
  
  // Top Row (Right to Left): 15-20
  BoardSpaceData(index: 15, name: "Whitefield", type: "Property", price: 200, colorHex: "#FF0000"),
  BoardSpaceData(index: 16, name: "ITPL", type: "Property", price: 220, colorHex: "#FF0000"),
  BoardSpaceData(index: 17, name: "Chance", type: "Chance"),
  BoardSpaceData(index: 18, name: "Electronic City", type: "Property", price: 240, colorHex: "#FF0000"),
  BoardSpaceData(index: 19, name: "Namma Metro", type: "Railroad", price: 200),
  BoardSpaceData(index: 20, name: "Malleshwaram", type: "Property", price: 260, colorHex: "#FFFF00"),
  
  // Top-Left Corner
  BoardSpaceData(index: 21, name: "Go To Jail", type: "Corner"),
  
  // Left Column (Top to Bottom): 22-27
  BoardSpaceData(index: 22, name: "Rajajinagar", type: "Property", price: 280, colorHex: "#FFFF00"),
  BoardSpaceData(index: 23, name: "Sadashivanagar", type: "Property", price: 300, colorHex: "#008000"),
  BoardSpaceData(index: 24, name: "BWSSB", type: "Utility", price: 150),
  BoardSpaceData(index: 25, name: "Palace Ground", type: "Property", price: 320, colorHex: "#008000"),
  BoardSpaceData(index: 26, name: "Community", type: "CommunityChest"),
  BoardSpaceData(index: 27, name: "UB City", type: "Property", price: 400, colorHex: "#0000FF"),
];

// Total board spaces
const int totalBoardSpaces = 28;

enum CardType { chance, communityChest }

class GameCard {
  final String text;
  // Actually, passing functions is hard for serialization. let's use an Enum or ID.
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
];

const List<GameCard> communityChestCards = [
  GameCard(text: "Advance to GO (Collect ₹200)", actionId: "advance_to", value: 0),
  GameCard(text: "Bank error in your favor. Collect ₹200", actionId: "money", value: 200),
  GameCard(text: "Doctor's fees. Pay ₹50", actionId: "money", value: -50),
  GameCard(text: "Go to Jail", actionId: "go_to_jail"),
  GameCard(text: "From sale of stock you get ₹50", actionId: "money", value: 50),
  GameCard(text: "Income tax refund. Collect ₹20", actionId: "money", value: 20),
];
