import '../../../core/pixel/pixel_art.dart';

/// Hand-crafted pixel sprites for the Home command deck and calendar.
/// Keys map to [PixelPalette.byKey]; `.` is transparent.
abstract final class HomePixelArt {
  /// 16x16 pixel calendar icon with sun-gold header and green date pip.
  static const calendar = PixelArt('homeCalendar', [
    '...00......00...',
    '..0hh0....0hh0..',
    '.00000000000000.',
    '0hhhhhhhhhhhhhh0',
    '0gggggggggggggg0',
    '0000000000000000',
    '0666666666666660',
    '0622622622622660',
    '0622622622622660',
    '0666666666666660',
    '06226aa6226hh660',
    '06226aa6226hh660',
    '0666666666666660',
    '0622622622666660',
    '0555555555555550',
    '.00000000000000.',
  ]);

  /// 8x8 pixel flame/sun stamp checkmark pip for claimed streak days.
  static const stampCheck = PixelArt('homeStampCheck', [
    '..0000..',
    '.0gggg0.',
    '0ghhhhg0',
    '0gh66hg0',
    '0ghh6hg0',
    '0g6hhhg0',
    '.0gggg0.',
    '..0000..',
  ]);

  /// 16x16 pixel rubber stamp icon for Passport Stamps purse slot.
  static const purseStamp = PixelArt('homePurseStamp', [
    '....00000000....',
    '...0xxeeeeen0...',
    '...0xeeeeeen0...',
    '...0eeeeeee0....',
    '....0eeeen0.....',
    '....0eeeen0.....',
    '..000hiiih000...',
    '.0xxeeeeeeenn0..',
    '.0xAAAAAAAAAn0..',
    '.0zzzzzzzzzzz0..',
    '..00000000000...',
    '0000000000000000',
    '0pppwwwwwwwwppp0',
    '0pppsssrrrssppp0',
    '0000000000000000',
    '................',
  ]);

  /// 16x16 pixel happy smiley badge for Scout Reputation purse slot.
  static const purseSmiley = PixelArt('homePurseSmiley', [
    '.....ffffff.....',
    '...ffhhhhhhff...',
    '..fhhiiihhhhhf..',
    '.fhhiihhhhhhhhf.',
    '.fhhhhhhhhhhhhf.',
    'fhhhhllhhllhhhhf',
    'fhhhlhhllhhlhhhf',
    'fhhuuhhhhhhuuhhf',
    'fhhhhhhhhhhhhhhf',
    'fhhhhlhhhhhlhhhf',
    '.fhhhllllllhhhf.',
    '.fhhhhhhhhhhhhf.',
    '..fhhhhhhhhhhf..',
    '...ffhhhhhhff...',
    '.....ffffff.....',
    '................',
  ]);
}
