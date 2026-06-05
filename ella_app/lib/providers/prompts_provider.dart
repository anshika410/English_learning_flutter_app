// Editable override of the simulator's DEFAULT_PROMPTS.
// The Edit Prompts tab writes here; ChatNotifier reads here when building
// conv/judge prompts. Reset to defaults restores `kDefaultPrompts`.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/prompts.dart';

final promptsOverrideProvider =
    StateProvider<AppPrompts>((ref) => kDefaultPrompts);
