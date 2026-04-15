# دليل المطور

مرحبًا بك في دليل مطوري DadyTube. يوفر هذا المستند نظرة عامة على البنية المعمارية ومعايير الترميز واستراتيجيات الاختبار المطلوبة للمساهمة في المشروع.

## البنية المعمارية ومجموعة التقنيات

تم بناء DadyTube باستخدام **Flutter** و **Dart**. يتبع المشروع نمطًا معماريًا صارمًا يفصل واجهة المستخدم عن إدارة الحالة ومنطق الأعمال.

### التقنيات الرئيسية
* **الإطار (Framework):** Flutter (Android و iOS). يستهدف Dart SDK `3.11.0`.
* **إدارة الحالة:** Provider (`lib/providers/`).
* **منطق الأعمال:** Services (`lib/services/`).
* **التخزين:** `SharedPreferences` للثبات المحلي.
* **الفيديو/الشبكات:** `youtube_player_flutter`، `video_player`، و `youtube_explode_dart`.
* **الذكاء الاصطناعي/تعلم الآلة (AI/ML):** Google ML Kit لاكتشاف الوجه على الجهاز.

## بنية الدليل
* `lib/providers/` - يحتوي على فئات إدارة الحالة التي توسع `ChangeNotifier`.
* `lib/services/` - يحتوي على فئات منطق أعمال Singleton (مثل `VideoCacheService`، `DistanceProtectionService`).
* `lib/ui/` أو `lib/widgets/` - يحتوي على مكونات واجهة مستخدم "صندوق الرمل الرقمي" (مثل `TactileWidget`).

## معايير الترميز والأداء

### قواعد "صندوق الرمل الرقمي"
يجب أن يشعر كل عنصر من عناصر واجهة المستخدم في DadyTube بالنعومة واللمس:
1. **لا توجد خطوط قاسية:** لا تستخدم `Border.all` أبدًا. استخدم `BoxShadow` لخلق العمق.
2. **زوايا ناعمة:** يجب أن يكون `BorderRadius` عمومًا أكبر من `32.0`.
3. **اللمسية:** يجب أن تتوسع عناصر النقر إلى `0.95` عند النقر.
4. **الألوان:** استخدم لوحات ألوان نغمية وناعمة (مثل `#FFF5F7` للخلفيات).

### تحسين الأداء
* **التخزين المؤقت (Caching):** يجب تخزين الحسابات الثقيلة (مثل فرز مصفوفات الفيديو الكبيرة) مؤقتًا في Providers لتجنب تنفيذ `O(N log N)` في كل دورة بناء.
* **SharedPreferences:** قم بتخزين المثيل كعضو خاص (مثل `_prefs`) بعد الاسترداد الأول لمنع المكالمات غير المتزامنة المتكررة وعوائد حلقة الأحداث.
* **القوائم:** لا تستخدم `ListView.builder` مع `shrinkWrap: true` داخل `SingleChildScrollView`. استخدم دائمًا `CustomScrollView` مع `SliverList` للقوائم الكبيرة للحفاظ على 60 إطارًا في الثانية.
* **التسجيل (Logging):** استخدم `debugPrint` من `package:flutter/foundation.dart` بدلاً من `print()` القياسي.

### الأمان
* **التعقيم (Sanitization):** قم دائمًا بتعقيم المدخلات الخارجية، وخاصة معرفات فيديو YouTube، باستخدام نهج قائمة السماح (مثل `id.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '')`) قبل استخدامها لإنشاء مسارات ملفات محلية لمنع الثغرات الأمنية في اجتياز المسار.
* **مسارات الصور:** تجنب مسارات ملفات النظام المطلقة للأصول المحلية؛ استخدم دائمًا `Image.asset` مع المسارات النسبية المحددة في `pubspec.yaml` (مثل `- assets/images/`).

## استراتيجيات الاختبار

يستخدم DadyTube `mocktail` لمحاكاة التبعيات. قم بتشغيل الاختبارات باستخدام `flutter test`.

### حقن التبعية (Dependency Injection)
عند بناء Services أو Providers، استخدم المعلمات الاختيارية في المُنشئ للسماح بحقن النماذج (Mocks) أثناء الاختبار دون كسر التوافق مع الإصدارات السابقة.
```dart
class MyService {
  final ApiClient _apiClient;
  MyService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();
}
```

### تفاصيل المحاكاة (Mocking Specifics)
* **قنوات النظام الأساسي (Platform Channels):** لمحاكاة قنوات النظام الأساسي أصليًا (`EventChannel` أو `MethodChannel`)، استخدم `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler` مع `MockStreamHandler.inline`.
* **الطرق الخاصة (Private Methods):** استخدم `@visibleForTesting` لكشف المنطق الداخلي (مثل معالجة الصور) في خدمات Singleton حتى يمكن اختبارها بشكل مستقل دون إنشاء دورة حياة الخدمة الكاملة.
* **Build Runner:** بعد إضافة `@GenerateMocks`، تذكر تشغيل:
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```

## العمل بصفة "Bolt"
إذا كنت تقوم بتحسين الأداء تحت شخصية "Bolt":
1. وثق تأثير التحسين مع التعليقات المضمنة.
2. قم بتشغيل `flutter analyze` و `flutter test` قبل تقديم طلب سحب (PR).
3. سجل الدروس المعمارية الحاسمة في `.jules/bolt.md` باستخدام التنسيق:
   ```markdown
   ## YYYY-MM-DD - [Title]
   **Learning:** [Insight]
   **Action:** [How to apply next time]
   ```
