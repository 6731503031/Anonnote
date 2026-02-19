import 'package:flutter/widgets.dart';

/// Minimal, local in-app translations for AnonNote.
/// Keeps things simple (no intl package) and covers the small set of UI strings
/// used by the MVP. Add more keys as needed.
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'appTitle': 'AnonNote',
      'settings': 'Settings',
      'light': 'Light',
      'dark': 'Dark',
      'system': 'System',
      'untitledNote': 'Untitled Note',
      'add': 'Add',
      'delete': 'Delete',
      'createNote': 'Create Note',
      'heroSubtitle': 'Write Anonymous Notes Online',
      'createNoteCTA': 'Create Note',
      'titleHint': 'Title',
      'tagsHint': 'Tags (comma separated)',
      'save': 'Save',
      'notes': 'Notes',
      'noNotes': 'No notes yet',
      'searchHint': 'Search notes or tags',
      'filterByTag': 'Filter by tag',
      'errorInit': 'Initialization failed',
    },
    'th': {
      'appTitle': 'แอนอนโน้ต',
      'settings': 'การตั้งค่า',
      'light': 'สว่าง',
      'dark': 'มืด',
      'system': 'ตามระบบ',
      'untitledNote': 'บันทึกไม่มีชื่อ',
      'add': 'เพิ่ม',
      'delete': 'ลบ',
      'createNote': 'สร้างบันทึก',
      'heroSubtitle': 'เขียนบันทึกลับโดยไม่ระบุชื่อออนไลน์',
      'createNoteCTA': 'สร้างบันทึก',
      'titleHint': 'หัวข้อ',
      'tagsHint': 'แท็ก (คั่นด้วยเครื่องหมายจุลภาค)',
      'save': 'บันทึก',
      'notes': 'บันทึก',
      'noNotes': 'ยังไม่มีบันทึก',
      'searchHint': 'ค้นหาบันทึกหรือแท็ก',
      'filterByTag': 'กรองตามแท็ก',
      'errorInit': 'การเริ่มต้นล้มเหลว',
    },
  };

  String get appTitle => _translate('appTitle');
  String get createNote => _translate('createNote');
  String get titleHint => _translate('titleHint');
  String get tagsHint => _translate('tagsHint');
  String get save => _translate('save');
  String get notes => _translate('notes');
  String get noNotes => _translate('noNotes');
  String get heroSubtitle => _translate('heroSubtitle');
  String get createNoteCTA => _translate('createNoteCTA');
  String get searchHint => _translate('searchHint');
  String get filterByTag => _translate('filterByTag');
  String get settings => _translate('settings');
  String get light => _translate('light');
  String get dark => _translate('dark');
  String get system => _translate('system');
  String get untitledNote => _translate('untitledNote');
  String get add => _translate('add');
  String get delete => _translate('delete');
  String get errorInit => _translate('errorInit');

  String _translate(String key) {
    final languageCode = locale.languageCode;
    return _localizedValues[languageCode]?[key] ??
        _localizedValues['en']![key]!;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'th'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
