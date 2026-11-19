import 'package:flutter_riverpod/flutter_riverpod.dart';

/// v0.3.10 ("Exiting out of shop does not exit out of the sub pages"): the
/// Shop category on screen (null = the Shop hub). It lives here, not in the
/// screen, so the bottom bar can send Shop back to its hub when the Shop tab
/// is tapped and the back button can leave a category before leaving Shop.
/// 0 Cosmetics, 1 Partner Vouchers, 2 Coming soon, 3 My Inventory.
final shopCategoryProvider = StateProvider<int?>((ref) => null);

/// The shell branch that holds `/shop`.
const shopShellBranch = 3;
