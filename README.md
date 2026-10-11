# أثير AI — Flutter + Realtime Voice

نسخة تطبيق Android أولية بهوية واجهة تقنية سينمائية داكنة: شبكة عصبية مضيئة باللون السماوي، لوحة حالة، ساعة رقمية، سجل حوار، ومركز مهام. الواجهة مرسومة داخل Flutter ولا تعتمد على صورة ثابتة.

## محتويات المشروع
- `lib/main.dart`: واجهة التطبيق والشاشات.
- `lib/widgets/neural_orb.dart`: هولوغرام الشبكة العصبية المتحركة المرسوم برمجيًا.
- `lib/services/realtime_voice_service.dart`: WebRTC audio session، طلب secret مؤقت من الخادم، استقبال أحداث المحادثة والنصوص.
- `lib/services/app_config.dart`: تخزين عنوان الخادم ورمز الوصول محليًا، مع تخزين الرمز عبر secure storage.
- `backend/server.js`: خادم Node/Express يصدر OpenAI Realtime client secret قصير العمر، ولا يكشف المفتاح الرئيسي.
- `.github/workflows/build-apk.yml`: workflow ينشئ Android scaffold ثم يحلل الكود ويبني APK.

## طريقة فتحه في Klencod IDE
1. حمّل ملف ZIP وفك ضغطه إلى مجلد `atheer_ai_complete`.
2. من Klencod اختر فتح/استيراد مشروع Flutter من المجلد الذي يحتوي على `pubspec.yaml`.
3. إذا كان Klencod يتطلب قالبًا أولًا، أنشئ Flutter Blank Project باسم `atheer_ai`، ثم انسخ مجلد `lib` و`pubspec.yaml` و`scripts` إليه، واحتفظ بملفات Android التي أنشأها IDE.
4. شغّل `flutter pub get` إذا كان هناك Terminal. إن لم توجد أداة terminal، استخدم خيار Packages/Dependencies في IDE.
5. قبل تشغيل الصوت، أضف صلاحيات Android الموجودة في `scripts/ensure_android_permissions.py` إلى manifest، وارفع `minSdk` إلى 23 على الأقل.

يمكن بناء APK أيضًا من GitHub: ارفع المشروع إلى مستودعك، ثم افتح تبويب **Actions** وشغّل **Build Atheer Android APK**. بعد انتهاء المهمة نزّل Artifact باسم `atheer-ai-release-apk`. الـworkflow يولّد ملفات Android الافتراضية إن لم تكن موجودة.

## تشغيل الخادم الآمن
الخادم موجود في `backend/` ويصدر سرًا مؤقتًا فقط. لا تضع مفتاح OpenAI في Flutter أو داخل APK.

1. انشر مجلد `backend` كتطبيق Node.js على Replit أو استضف `server.js` في Node 20+.
2. اضبط Environment Secrets في بيئة الخادم:
   - `OPENAI_API_KEY`: مفتاح OpenAI السري.
   - `APP_ACCESS_CODE`: رمز طويل وعشوائي تختاره أنت، ولا تشاركه.
   - `PORT`: عادة يحدده مزود الاستضافة تلقائيًا.
   - `RESEARCH_MODEL`: اختياري؛ الافتراضي `gpt-5.5` للبحث باستخدام Responses API.
3. نفّذ `npm install` ثم `npm start`.
4. اختبر `https://عنوان-خادمك/health`؛ يفترض أن يعطي JSON فيه `ok: true`.
5. افتح أثير > Settings، وضع رابط الخادم HTTPS ورمز الوصول نفسه.
6. اضغط Start Voice واسمح باستخدام الميكروفون.

### عقد الاتصال المتوقع
التطبيق يرسل `POST /api/realtime/client-secret` مع `X-Atheer-Access-Code`. يتوقع JSON مثل:
```json
{"value":"ek_...","expires_at":1234567890}
```
إذا كان لديك خادم Replit قديم بمسار مختلف، عدّل `RealtimeVoiceService._fetchEphemeralKey` ليتوافق مع استجابته أو أضف المسار المذكور أعلاه إلى ذلك الخادم.

## ما يعمل وما لا يعمل بعد
- يعمل بصريًا: الهولوغرام المتحرك، مؤشرات النظام، الساعة، لوحة الأوامر، شاشة سجل المحادثة، إضافة المهام وإنجازها محليًا.
- مهيّأ للاتصال الصوتي الحقيقي عبر WebRTC بعد إعداد الخادم ورمز الوصول وصلاحيات الميكروفون.
- المهام تحفظ محليًا على الهاتف، ولا تُزامن بين الأجهزة.
- الملاحظات في الذاكرة تحفظ محليًا، ويمكن تمريرها كسياق إلى جلسة الصوت عند بدء المحادثة.
- البحث على الإنترنت متاح عبر Responses API وأداة web search من الخادم، مع عرض روابط المصادر.
- التقويم ومواعيد التنبيه وإجراءات الهاتف والتزامن السحابي ليست مفعّلة بعد.
- لا تضع مفتاح OpenAI الرئيسي في التطبيق أبدًا. المفتاح محفوظ في الخادم، والتطبيق يأخذ رمز جلسة مؤقتًا فقط.
- رمز الوصول في التطبيق الشخصي حاجز أولي وليس بديلًا عن تسجيل دخول قوي ومصادقة مستخدم من الخادم. لا تنشر التطبيق للعموم بهذه الحماية فقط.

## شخصية أثير
الشخصية معرفة في `backend/server.js` في الثابت `PERSONA`: عربية بلهجة يمنية وصنعانية خفيفة، ذكية وصريحة، تفتح حوارًا عميقًا عند ملاءمته، وتقدم خطوات عملية. لا تدعي مشاعر بشرية ولا تختلق البحث أو الذاكرة.

## الخطوط
واجهة Android تستخدم خط النظام كتراجع تلقائي لأن SF Pro خط Apple وليس مثبتًا بشكل افتراضي على أندرويد. يمكن إضافة خط عربي مرخّص إلى `assets/fonts` لاحقًا إذا رغبت بمظهر أكثر تحديدًا.

## مراجع تقنية
- OpenAI Realtime client secrets: https://developers.openai.com/api/reference/resources/realtime/subresources/client_secrets/methods/create
- OpenAI Web search: https://developers.openai.com/api/docs/guides/tools-web-search
- Flutter WebRTC: https://pub.dev/packages/flutter_webrtc
