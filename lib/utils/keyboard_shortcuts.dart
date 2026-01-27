import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keyboard shortcuts for power users
/// Provides quick navigation and actions
class KeyboardShortcuts {
  /// Common keyboard shortcuts for the app
  static Map<ShortcutActivator, Intent> get shortcuts => {
    // Navigation
    LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyN): const CreateRecipeIntent(),
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN): const CreateRecipeIntent(),
    
    LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyF): const FocusSearchIntent(),
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF): const FocusSearchIntent(),
    
    LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS): const SaveIntent(),
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS): const SaveIntent(),
    
    LogicalKeySet(LogicalKeyboardKey.escape): const ClearSearchIntent(),
    
    // Special
    LogicalKeySet(LogicalKeyboardKey.f1): const ShowHelpIntent(),
  };

  /// Actions for the shortcuts
  static Map<Type, Action<Intent>> get actions => {
    CreateRecipeIntent: CreateRecipeAction(),
    FocusSearchIntent: FocusSearchAction(),
    SaveIntent: SaveAction(),
    ClearSearchIntent: ClearSearchAction(),
    ShowHelpIntent: ShowHelpAction(),
  };
}

// Intent classes
class CreateRecipeIntent extends Intent {
  const CreateRecipeIntent();
}

class FocusSearchIntent extends Intent {
  const FocusSearchIntent();
}

class SaveIntent extends Intent {
  const SaveIntent();
}

class ClearSearchIntent extends Intent {
  const ClearSearchIntent();
}

class ShowHelpIntent extends Intent {
  const ShowHelpIntent();
}

// Action classes
class CreateRecipeAction extends Action<CreateRecipeIntent> {
  @override
  Object? invoke(CreateRecipeIntent intent) {
    // Will be handled by context-specific implementation
    return null;
  }
}

class FocusSearchAction extends Action<FocusSearchIntent> {
  @override
  Object? invoke(FocusSearchIntent intent) {
    // Will be handled by context-specific implementation
    return null;
  }
}

class SaveAction extends Action<SaveIntent> {
  @override
  Object? invoke(SaveIntent intent) {
    // Will be handled by context-specific implementation
    return null;
  }
}

class ClearSearchAction extends Action<ClearSearchIntent> {
  @override
  Object? invoke(ClearSearchIntent intent) {
    // Will be handled by context-specific implementation
    return null;
  }
}

class ShowHelpAction extends Action<ShowHelpIntent> {
  @override
  Object? invoke(ShowHelpIntent intent) {
    // Will be handled by context-specific implementation
    return null;
  }
}
