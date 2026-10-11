import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

void main() => runApp(const AtheerApp());

const Color bg = Color(0xFF090B0E);
const Color panel = Color(0xFF12161B);
const Color gold = Color(0xFFC6A879);
const Color muted = Color(0xFF8C929B);
const Color cream = Color(0xFFE9E0D2);

class AtheerApp extends StatelessWidget {
  const AtheerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'أثير',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: gold,
          surface: panel,
        ),
        fontFamily: 'SF Pro Display',
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

enum AssistantState { idle, listening, thinking, speaking }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  int _tab = 0;
  AssistantState _state = AssistantState.idle;
  late final AnimationController _pulse;
  final List<_Task> _tasks = [
    _Task('مراجعة خطة التداول', '09:00', false),
    _Task('قراءة 10 صفحات', '11:30', false),
    _Task('مراجعة مسار التعلّم', '18:00', true),
  ];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String get _stateLabel {
    switch (_state) {
      case AssistantState.idle: return 'جاهزة حين تحتاجني';
      case AssistantState.listening: return 'أسمعك يا خليل…';
      case AssistantState.thinking: return 'أرتّب أفكاري…';
      case AssistantState.speaking: return 'أتحدث معك الآن';
    }
  }

  void _toggleVoice() {
    setState(() {
      if (_state == AssistantState.listening) {
        _state = AssistantState.idle;
      } else {
        _state = AssistantState.listening;
      }
    });
    if (_state == AssistantState.listening) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هذه واجهة تجريبية؛ لم يتم ربط الصوت بالخادم بعد.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _addTask() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: panel,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('مهمة جديدة', textAlign: TextAlign.right,
              style: TextStyle(color: cream, fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              textDirection: TextDirection.rtl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'اكتب المهمة هنا…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) {
                  setState(() => _tasks.add(_Task(value, 'بدون موعد', false)));
                }
                Navigator.pop(ctx);
              },
              child: const Text('إضافة المهمة'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              const _AmbientBackground(),
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _topBar()),
                  SliverToBoxAdapter(child: _heroOrb()),
                  SliverToBoxAdapter(child: _greeting()),
                  SliverToBoxAdapter(child: _quickStatus()),
                  SliverToBoxAdapter(child: _insightCard()),
                  SliverToBoxAdapter(child: _tasksSection()),
                  const SliverToBoxAdapter(child: SizedBox(height: 110)),
                ],
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _bottomBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
    child: Row(
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(.035),
            border: Border.all(color: gold.withOpacity(.35)),
          ),
          child: const Icon(CupertinoIcons.sparkles, color: gold, size: 21),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('أثير', style: TextStyle(color: cream, fontSize: 23, fontWeight: FontWeight.w600, letterSpacing: .5)),
              SizedBox(height: 2),
              Text('مساعدتك الشخصية', style: TextStyle(color: muted, fontSize: 12)),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _showInfo('حالة النظام', 'الواجهة تعمل محليًا. يلزم إعداد الخادم لربط الصوت والبحث والذاكرة.'),
          icon: const Icon(CupertinoIcons.waveform_path, color: muted),
          tooltip: 'حالة النظام',
        ),
      ],
    ),
  );

  Widget _heroOrb() => SizedBox(
    height: 300,
    child: Center(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final t = _pulse.value;
          final scale = 0.96 + t * 0.045;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 205, height: 205,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-.28, -.35),
                  radius: .9,
                  colors: [
                    const Color(0xFFEEE0BE).withOpacity(.9),
                    const Color(0xFF9D8051).withOpacity(.7),
                    const Color(0xFF34404B).withOpacity(.6),
                    const Color(0xFF10151B),
                    bg,
                  ],
                  stops: const [0, .18, .43, .72, 1],
                ),
                boxShadow: [
                  BoxShadow(color: gold.withOpacity(.10 + t * .08), blurRadius: 45 + t * 20, spreadRadius: 2),
                  BoxShadow(color: const Color(0xFF8CA8C4).withOpacity(.08), blurRadius: 75),
                ],
                border: Border.all(color: gold.withOpacity(.15 + t * .12), width: 1),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: -.45 + t * .12,
                    child: Container(
                      width: 245, height: 82,
                      decoration: BoxDecoration(
                        border: Border.all(color: gold.withOpacity(.34), width: .8),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cream.withOpacity(.95),
                      boxShadow: [BoxShadow(color: gold.withOpacity(.8), blurRadius: 20)],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _greeting() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('مساء الخير يا خليل', textAlign: TextAlign.center,
          style: TextStyle(color: cream, fontSize: 27, fontWeight: FontWeight.w600, letterSpacing: -.4)),
        const SizedBox(height: 10),
        Text(
          'أنا هنا أساعدك تشوف الصورة كاملة، مش بس أول شيء يبان لك.',
          textAlign: TextAlign.center,
          style: TextStyle(color: cream.withOpacity(.68), height: 1.7, fontSize: 14),
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(_stateLabel, style: const TextStyle(color: gold, fontSize: 12, letterSpacing: .3)),
        ),
        const SizedBox(height: 14),
        Center(
          child: GestureDetector(
            onTap: _toggleVoice,
            child: Container(
              width: 76, height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: gold.withOpacity(.07),
                border: Border.all(color: gold.withOpacity(.65), width: 1.2),
                boxShadow: [BoxShadow(color: gold.withOpacity(.12), blurRadius: 24, spreadRadius: 1)],
              ),
              child: Icon(
                _state == AssistantState.listening ? CupertinoIcons.stop_fill : CupertinoIcons.mic,
                color: gold, size: 29,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text('اضغط لبدء المحادثة', textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 11)),
      ],
    ),
  );

  Widget _quickStatus() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
    child: Row(
      children: [
        Expanded(child: _metric('المهام', '${_tasks.where((t) => !t.done).length}', CupertinoIcons.checkmark_square)),
        const SizedBox(width: 10),
        Expanded(child: _metric('التركيز', 'قيد البناء', CupertinoIcons.scope)),
        const SizedBox(width: 10),
        Expanded(child: _metric('الاتصال', 'غير مربوط', CupertinoIcons.dot_radiowaves_left_right)),
      ],
    ),
  );

  Widget _metric(String title, String value, IconData icon) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: panel.withOpacity(.78),
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: Colors.white.withOpacity(.06)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: gold, size: 17),
        const SizedBox(height: 12),
        Text(value, style: const TextStyle(color: cream, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(title, style: const TextStyle(color: muted, fontSize: 11)),
      ],
    ),
  );

  Widget _insightCard() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 25, 20, 0),
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topRight, end: Alignment.bottomLeft,
          colors: [const Color(0xFF1C2024), const Color(0xFF101317).withOpacity(.8)],
        ),
        border: Border.all(color: gold.withOpacity(.2)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(CupertinoIcons.lightbulb, color: gold, size: 18),
            SizedBox(width: 8),
            Text('ملاحظة من أثير', style: TextStyle(color: gold, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
          SizedBox(height: 12),
          Text(
            'لا تحاول تحسم كل شيء الليلة. اختَر خطوة واحدة تستحق جهدك، وخلّ الباقي ينتظر حتى تتضح الصورة.',
            style: TextStyle(color: cream, fontSize: 14, height: 1.8),
          ),
          SizedBox(height: 8),
          Text('تأمل إرشادي تجريبي — ليس تحليلًا مبنيًا على بياناتك بعد.',
            style: TextStyle(color: muted, fontSize: 10)),
        ],
      ),
    ),
  );

  Widget _tasksSection() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
    child: Column(
      children: [
        Row(
          children: [
            const Expanded(child: Text('مركز المهام', style: TextStyle(color: cream, fontSize: 19, fontWeight: FontWeight.w600))),
            TextButton.icon(
              onPressed: _addTask,
              icon: const Icon(CupertinoIcons.add, size: 17),
              label: const Text('إضافة'),
              style: TextButton.styleFrom(foregroundColor: gold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._tasks.map((task) => Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: panel.withOpacity(.72),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(.055)),
          ),
          child: Row(
            children: [
              Checkbox(
                value: task.done,
                activeColor: gold,
                checkColor: bg,
                onChanged: (v) => setState(() => task.done = v ?? false),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title, style: TextStyle(
                      color: task.done ? muted : cream,
                      decoration: task.done ? TextDecoration.lineThrough : null,
                      fontSize: 13, fontWeight: FontWeight.w500,
                    )),
                    const SizedBox(height: 4),
                    Text(task.time, style: const TextStyle(color: muted, fontSize: 11)),
                  ],
                ),
              ),
              Icon(CupertinoIcons.chevron_left, size: 14, color: gold.withOpacity(.7)),
            ],
          ),
        )),
      ],
    ),
  );

  Widget _bottomBar() => Container(
    padding: EdgeInsets.fromLTRB(12, 12, 12, MediaQuery.of(context).padding.bottom + 12),
    decoration: BoxDecoration(
      color: const Color(0xF20D1014),
      border: Border(top: BorderSide(color: Colors.white.withOpacity(.07))),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _navItem(0, CupertinoIcons.sparkles, 'الرئيسية'),
        _navItem(1, CupertinoIcons.checkmark_square, 'المهام'),
        _navItem(2, CupertinoIcons.waveform, 'الحوار'),
        _navItem(3, CupertinoIcons.circle_grid_3x3, 'البيانات'),
      ],
    ),
  );

  Widget _navItem(int index, IconData icon, String label) {
    final selected = _tab == index;
    return InkWell(
      onTap: () {
        setState(() => _tab = index);
        if (index == 1) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('قائمة المهام موجودة في الصفحة الرئيسية حاليًا.'),
            behavior: SnackBarBehavior.floating,
          ));
        } else if (index == 2) {
          _toggleVoice();
        } else if (index == 3) {
          _showInfo('لوحة البيانات', 'سيتم ربط مؤشرات النظام والذاكرة والبحث بعد تجهيز الخادم.');
        }
      },
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? gold : muted, size: 21),
            const SizedBox(height: 5),
            Text(label, style: TextStyle(color: selected ? gold : muted, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  void _showInfo(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: panel,
        title: Text(title, textAlign: TextAlign.right, style: const TextStyle(color: cream)),
        content: Text(message, textAlign: TextAlign.right, style: const TextStyle(color: muted, height: 1.6)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسنًا')),
        ],
      ),
    );
  }
}

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      children: [
        Positioned(
          top: 90, left: -100,
          child: Container(
            width: 260, height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [gold.withOpacity(.055), Colors.transparent]),
            ),
          ),
        ),
        Positioned(
          top: 400, right: -120,
          child: Container(
            width: 300, height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [const Color(0xFF526A82).withOpacity(.06), Colors.transparent]),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Task {
  _Task(this.title, this.time, this.done);
  final String title;
  final String time;
  bool done;
}