/// Shared networking utility functions.

/// Converts a 32-bit integer to a 4-byte big-endian list.
List<int> int32ToBytes(int value) {
  return [
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ];
}
