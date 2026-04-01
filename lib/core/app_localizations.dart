import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const _localizedValues = {
    'en': {
      // General
      'app_title': 'DadyTube',
      'search_hint': 'Search for fun!',
      'pick_a_world': 'Pick a World',
      'popular_now': 'Popular Right Now',
      'watch_more': 'Watch More Fun',
      'view_all': 'View All',
      'safe_for_kids': 'SAFE\nFOR KIDS',
      'save': 'Save',
      'share': 'Share',
      'download': 'Download',
      'settings': 'Settings',
      'channels': 'Channels',
      'guide': 'Guide',
      'play': 'PLAY',
      'search': 'SEARCH',
      'reset': 'Reset',
      'exploring': 'Exploring',
      'try_again': 'Try Again',
      'back': 'Back',

      // Worlds
      'animals': 'Animals',
      'music': 'Music',
      'toys': 'Toys',
      'learning': 'Learning',
      'travel_mode': 'Travel Mode',

      // Watch Screen
      'downloading_travel': 'Downloading to Travel Mode...',
      'added_to_travel': 'Video added to Travel Mode!',
      'download_failed': 'Download failed',
      'download_confirm': 'Download this video?',
      'download_msg': 'It will be available offline in Travel Mode.',
      'yes_download': 'Yes, Download',
      'cancel': 'Cancel',
      'error_loading_video': 'Oops! This video is taking a nap.',

      // Bedtime / Usage
      'bedtime_title': 'Shhh... Bedtime!',
      'bedtime_msg':
          'The toys are all asleep now. It\'s time for you to dream too!',
      'daily_limit': 'Daily Playtime Limit',
      'add_playtime': 'Add Playtime',
      'minutes': 'minutes',
      'grant_extra_time': 'Grant extra time?',
      'plus_mins': '+{min} min',

      // Parental Gate
      'parental_gate_title': 'Parents Only',
      'parental_gate_msg': 'Please ask a parent to help you with this.',
      'enter_pin': 'Enter PIN',

      // Channels / Settings
      'add_channel': 'Add Channel',
      'remove_channel': 'Remove Channel',
      'channel_url': 'YouTube Channel URL',
      'your_channels': 'Your Channels',
      'no_channels': 'No channels yet!',
      'loading_videos': 'Loading fresh videos...',
      'ask_parent_msg': 'Ask a parent to add some fun channels in Settings!',
      'add_channels_msg': 'Add some channels in Settings to see videos!',
      'empty_bag':
          'Your travel bag is empty! Download videos to watch them on the go.',
      'no_videos': 'No videos found in this world yet!',
      'default_author': 'Default Post Author',
      'video_quality': 'Video Quality',
      'full_screen_playback': 'Auto Full-Screen',
      'show_suggestions': 'Show Suggestions',
      'auto': 'Auto',
      'p360': '360p',
      'p720': '720p',
      'p1080': '1080p',
      'video_experience': 'Video Experience',
      'video_finished': 'Well Done!',
      'ready_for_break': 'Ready for a little break?',
      'go_home': 'Go Home',
      'safety_settings': 'Safety Settings',
      'smart_features': 'Smart Features',
      'auto_cache_title': 'Auto-Cache New Videos',
      'auto_cache_desc': 'Always download the latest 3 videos for offline fun.',
      'offline_mode_active': 'Offline Mode Active',
      'offline_mode_desc': 'Showing only videos available in your bag.',
      'experience': 'Experience',
      'safety': 'Safety',
      'language': 'Language',
      'english': 'English',
      'arabic': 'Arabic (Iraq)',
      'eye_protection': 'Blue Light Filter',
      'rest_reminders': 'Rest Reminders',
      'rest_msg':
          'Time to give your eyes a little break! Look at something far away for 20 seconds.',
      'blink_break': 'Blink Break!',
      'blink_break_title': 'Time for Eye Yoga!',
      'activity_1_title': 'Look at the Mountains!',
      'activity_1_desc': 'Look at something far away for a moment.',
      'activity_2_title': 'Lemon Squeeze!',
      'activity_2_desc': 'Squeeze your eyes shut tight, then open!',
      'activity_3_title': 'Reach for Stars!',
      'activity_3_desc': 'Stretch your arms way up high!',
      'back_to_fun': 'Back to Fun in',
      'seconds': 'seconds',
      'breathe_in': 'Breathe in...',
      'get_ready_adventure': 'Let\'s get ready for the next adventure!',
      'magic_stars': 'Magic Stars',
      'achievements': 'My Stars!',
      'monthly_collection': 'Monthly Collection',
      'monthly_goal': 'Monthly Goal',
      'stars_earned_desc':
          'Earn stars by saving your playtime or watching learning videos!',
      'month_1': 'January',
      'month_2': 'February',
      'month_3': 'March',
      'month_4': 'April',
      'month_5': 'May',
      'month_6': 'June',
      'month_7': 'July',
      'month_8': 'August',
      'month_9': 'September',
      'month_10': 'October',
      'month_11': 'November',
      'month_12': 'December',
      'theme': 'Magic Theme',
      'theme_blush': 'Blush',
      'theme_sunset': 'Sunset',
      'theme_midnight': 'Midnight',
      'theme_deep_space': 'Deep Space',
      'distance_protection': 'Safe Distance Protection',
      'step_back_title': 'Step Back! 🐰',
      'step_back_desc':
          'Your face is a little too close to the screen. Please move back a tiny bit to protect your eyes!',
      'safety_pause': 'Move back to play',
      'splash_preparing': 'Preparing the Worlds...',
      'splash_finding': 'Finding {name}...',
      'splash_almost': 'Almost ready for fun!',
      'splash_ready': 'Ready to Play!',
      'guide_magic_stars_title': 'Magic Stars',
      'guide_magic_stars_desc':
          'Earn stars by completing educational videos or by saving playtime! For every 50 minutes of unused daily time, you get a special Magic Star.',
      'guide_distance_title': 'Safe Distance',
      'guide_distance_desc':
          'The "Step Back!" rabbit helps protect your eyes. If you hold the screen too close, the rabbit will appear and pause the video until you move back.',
      'guide_eye_yoga_title': 'Eye Yoga',
      'guide_eye_yoga_desc':
          'Every 15 minutes, we take a short break to do eye exercises (Look Far, Squeeze, Reach). This helps prevent tired eyes.',
      'guide_calm_mode_title': 'Calm Mode',
      'guide_calm_mode_desc':
          'After 7:00 PM, the app automatically shifts to warmer colors and soothing bedtime content.',
      'sit_up_title': 'Sit Up! 🐰',
      'safe_volume_mode': 'Safe Ears Mode',
      'safe_volume_desc': 'Protects hearing by capping maximum volume.',
      'posture_protection': 'Posture Protection',
      'posture_desc': 'Reminds you to sit up straight like a rabbit.',
      'max_volume_level': 'Max Volume Level',
      // Statistics
      'statistics': 'Statistics',
      'storage_usage': 'Storage Usage',
      'cached_videos': 'Auto-Cached Videos',
      'metadata_stored': 'Channel Metadata',
      'instant_play_links': 'Instant Play Links',
      'manual_downloads': 'Saved to Travel Bag',
      'clear_cache': 'Clear Auto-Cache',
    },
    'ar': {
      // General
      'app_title': 'دادي تيوب',
      'search_hint': 'ابحث عن المرح!',
      'pick_a_world': 'اختر عالماً',
      'popular_now': 'شائع الآن',
      'watch_more': 'شاهد المزيد من المرح',
      'view_all': 'عرض الكل',
      'safe_for_kids': 'آمن\nللأطفال',
      'save': 'حفظ',
      'share': 'مشاركة',
      'download': 'تحميل',
      'settings': 'الإعدادات',
      'channels': 'القنوات',
      'guide': 'دليل الاستخدام',
      'play': 'تشغيل',
      'search': 'بحث',
      'reset': 'إعادة تعيين',
      'exploring': 'استكشاف',
      'try_again': 'حاول مرة أخرى',
      'back': 'رجوع',

      // Worlds
      'animals': 'حيوانات',
      'music': 'موسيقى',
      'toys': 'ألعاب',
      'learning': 'تعليم',
      'travel_mode': 'وضع السفر',

      // Watch Screen
      'downloading_travel': 'جاري التحميل لوضع السفر...',
      'added_to_travel': 'تمت إضافة الفيديو لوضع السفر!',
      'download_failed': 'فشل التحميل',
      'download_confirm': 'تحميل هذا الفيديو؟',
      'download_msg': 'سيكون متاحاً بدون إنترنت في وضع السفر.',
      'yes_download': 'نعم، تحميل',
      'cancel': 'إلغاء',
      'error_loading_video': 'أوه! هذا الفيديو نائم حالياً.',

      // Bedtime / Usage
      'bedtime_title': 'ششش... حان وقت النوم!',
      'bedtime_msg': 'كل الألعاب نائمة الآن. حان الوقت لكي تحلم أنت أيضاً!',
      'daily_limit': 'وقت اللعب اليومي',
      'add_playtime': 'إضافة وقت لعب',
      'minutes': 'دقيقة',
      'grant_extra_time': 'منح وقت إضافي؟',
      'plus_mins': '+{min} دقيقة',

      // Parental Gate
      'parental_gate_title': 'للأهل فقط',
      'parental_gate_msg': 'يرجى طلب المساعدة من أحد والديك.',
      'enter_pin': 'أدخل الرمز',

      // Channels / Settings
      'add_channel': 'إضافة قناة',
      'remove_channel': 'إزالة القناة',
      'channel_url': 'رابط قناة اليوتيوب',
      'your_channels': 'قنواتك',
      'no_channels': 'لا توجد قنوات بعد!',
      'loading_videos': 'جاري تحميل فيديوهات جديدة...',
      'ask_parent_msg': 'اطلب من أحد والديك إضافة قنوات ممتعة من الإعدادات!',
      'add_channels_msg': 'أضف بعض القنوات من الإعدادات لمشاهدة الفديوهات!',
      'empty_bag': 'حقيبة سفرك فارغة! حمّل فيديوهات لمشاهدتها أثناء التنقل.',
      'no_videos': 'لم يتم العثور على فيديوهات في هذا العالم بعد!',
      'default_author': 'كاتب المنشورات الافتراضي',
      'video_quality': 'جودة الفيديو',
      'full_screen_playback': 'ملء الشاشة تلقائياً',
      'show_suggestions': 'عرض الاقتراحات',
      'auto': 'تلقائي',
      'p360': '٣٦٠ بكسل',
      'p720': '٧٢٠ بكسل',
      'p1080': '١٠٨٠ بكسل',
      'video_experience': 'تجربة الفيديو',
      'video_finished': 'أحسنت!',
      'ready_for_break': 'هل أنت مستعد لاستراحة قصيرة؟',
      'go_home': 'العودة للرئيسية',
      'safety_settings': 'إعدادات الأمان',
      'smart_features': 'الميزات الذكية',
      'auto_cache_title': 'تخزين تلقائي للفيديوهات الجديدة',
      'auto_cache_desc': 'تحميل أحدث ٣ فيديوهات تلقائياً للمرح بدون إنترنت.',
      'offline_mode_active': 'وضع عدم الاتصال نشط',
      'offline_mode_desc': 'عرض الفيديوهات المتاحة في حقيبتك فقط.',
      'experience': 'التجربة',
      'safety': 'الأمان',
      'language': 'اللغة',
      'english': 'الإنجليزية',
      'arabic': 'العربية (العراق)',
      'eye_protection': 'فلتر الضوء الأزرق',
      'rest_reminders': 'تذكير بالراحة',
      'rest_msg':
          'حان الوقت لإراحة عينيك قليلاً! انظر إلى شيء بعيد لمدة ٢٠ ثانية.',
      'blink_break': 'استراحة الرمش!',
      'blink_break_title': 'وقت يوغا العين!',
      'activity_1_title': 'انظر إلى الجبال!',
      'activity_1_desc': 'انظر إلى شيء بعيد للحظة.',
      'activity_2_title': 'عصر الليمون!',
      'activity_2_desc': 'أغمض عينيك بقوة، ثم افتحهما!',
      'activity_3_title': 'الوصول للنجوم!',
      'activity_3_desc': 'مد ذراعيك عالياً جداً!',
      'back_to_fun': 'العودة للمرح في',
      'seconds': 'ثانية',
      'breathe_in': 'تنفس بعمق...',
      'get_ready_adventure': 'لنستعد للمغامرة القادمة!',
      'magic_stars': 'النجوم السحرية',
      'achievements': 'نجومي!',
      'monthly_collection': 'مجموعة الشهر',
      'monthly_goal': 'هدف الشهر',
      'stars_earned_desc':
          'اكسب النجوم من خلال توفير وقت اللعب أو مشاهدة الفيديوهات التعليمية!',
      'month_1': 'كانون الثاني',
      'month_2': 'شباط',
      'month_3': 'آذار',
      'month_4': 'نيسان',
      'month_5': 'أيار',
      'month_6': 'حزيران',
      'month_7': 'تموز',
      'month_8': 'آب',
      'month_9': 'أيلول',
      'month_10': 'تشرين الأول',
      'month_11': 'تشرين الثاني',
      'month_12': 'كانون الأول',
      'theme': 'الثيم السحري',
      'theme_blush': 'الوردي',
      'theme_sunset': 'الغروب',
      'theme_midnight': 'منتصف الليل',
      'theme_deep_space': 'الفضاء العميق',
      'distance_protection': 'حماية المسافة الآمنة',
      'step_back_title': 'ابتعد قليلاً 🐰',
      'step_back_desc':
          'وجهك قريب جداً من الشاشة. يرجى الابتعاد قليلاً لحماية عينيك الجميلتين!',
      'safety_pause': 'ابتعد قليلاً للمتابعة',
      'splash_preparing': 'جاري تجهيز العوالم...',
      'splash_finding': 'جاري البحث عن {name}...',
      'splash_almost': 'أوشكنا على الانتهاء!',
      'splash_ready': 'جاهز للعب!',
      'guide_magic_stars_title': 'النجوم السحرية',
      'guide_magic_stars_desc':
          'اجمع النجوم من خلال مشاهدة الفيديوهات التعليمية أو توفير وقت اللعب! مقابل كل 50 دقيقة متبقية من وقتك اليومي، ستحصل على نجمة سحرية.',
      'guide_distance_title': 'المسافة الآمنة',
      'guide_distance_desc':
          'أرنوب "ابتعد قليلاً" يحمي عينيك. إذا كنت قريباً جداً من الشاشة، سيظهر الأرنوب ويوقف الفيديو حتى تبتعد لمسافة آمنة.',
      'guide_eye_yoga_title': 'يوغا العين',
      'guide_eye_yoga_desc':
          'كل 15 دقيقة، نأخذ استراحة قصيرة للقيام بتمارين العين (انظر بعيداً، اغمض بقوة، تمدد). هذا يحمي عينيك من التعب.',
      'guide_calm_mode_title': 'النمط الهادئ',
      'guide_calm_mode_desc':
          'بعد الساعة 7:00 مساءً، يتحول التطبيق تلقائياً إلى ألوان دافئة ومحتوى هادئ يساعد على الاسترخاء قبل النوم.',
      'sit_up_title': 'اجلس جيداً! 🐰',
      'safe_volume_mode': 'نمط الأذنين الآمنة',
      'safe_volume_desc': 'يحمي حاسة السمع من خلال تحديد مستوى الصوت الأقصى.',
      'posture_protection': 'حماية القوام',
      'posture_desc': 'يذكرك بالجلوس بشكل مستقيم مثل الأرنوب.',
      'max_volume_level': 'مستوى الصوت الأقصى',
      // Statistics
      'statistics': 'الإحصائيات',
      'storage_usage': 'استخدام التخزين',
      'cached_videos': 'الفيديوهات المخزنة تلقائياً',
      'metadata_stored': 'بيانات القنوات',
      'instant_play_links': 'روابط التشغيل الفوري',
      'manual_downloads': 'المحفوظات في حقيبة السفر',
      'clear_cache': 'مسح التخزين التلقائي',
    },
  };

  String translate(String key, {Map<String, String>? args}) {
    String value = _localizedValues[locale.languageCode]?[key] ?? key;
    if (args != null) {
      args.forEach((k, v) {
        value = value.replaceAll('{$k}', v);
      });
    }
    return value;
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
