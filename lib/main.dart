import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/app_config.dart';
import 'services/realtime_voice_service.dart';
import 'services/research_service.dart';
import 'widgets/neural_orb.dart';

const Color bg = Color(0xFF030609);
const Color panel = Color(0xFF080D12);
const Color cyan = Color(0xFF53E7FF);
const Color cyanDim = Color(0xFF1A94BA);
const Color textBright = Color(0xFFE4F7FA);
const Color textMuted = Color(0xFF71858D);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AtheerApp());
}

class AtheerApp extends StatelessWidget {
  const AtheerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'أثير AI',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: bg,
          colorScheme: const ColorScheme.dark(primary: cyan, surface: panel),
          fontFamily: 'SF Pro Display',
          useMaterial3: true,
          snackBarTheme: const SnackBarThemeData(
            backgroundColor: Color(0xFF101B22),
            contentTextStyle: TextStyle(color: textBright),
          ),
        ),
        home: const AtHearthHome(),
      );
}

class AtHearthHome extends StatefulWidget {
  const AtHearthHome({super.key});
  @override
  State<AtHearthHome> createState() => _AtHearthHomeState();
}

class _AtHearthHomeState extends State<AtHearthHome> {
  final RealtimeVoiceService _voice = RealtimeVoiceService();
  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  AtheerVoiceState _voiceState = AtheerVoiceState.idle;
  bool _drawerOpen = false;
  bool _configReady = false;
  bool _localDataReady = false;
  final List<String> _memories = <String>[];
  String _latestText = 'النظام جاهز. افتح قناة الاتصال عندما تكون مستعدًا.';
  String _latestWho = 'أثير CORE';
  final List<_Message> _conversation = <_Message>[];
  final List<_Task> _tasks = <_Task>[
    _Task('مراجعة خطة التداول', '09:00', false),
    _Task('قراءة وتعلّم', '11:30', false),
    _Task('مراجعة أهداف الأسبوع', '18:00', true),
  ];

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _voice.onState = (value) {
      if (mounted) setState(() => _voiceState = value);
    };
    _voice.onTranscript = (text, {required isUser}) {
      if (!mounted) return;
      setState(() {
        _latestText = text;
        _latestWho = isUser ? 'خليل' : 'أثير';
        _conversation.add(_Message(text, isUser));
        if (_conversation.length > 30) _conversation.removeAt(0);
      });
    };
    _loadConfig();
    _loadLocalData();
  }

  Future<void> _loadConfig() async {
    final url = await AppConfig.getBackendUrl();
    if (mounted) setState(() => _configReady = url.isNotEmpty);
  }

  Future<void> _loadLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTasks = prefs.getString('atheer_tasks_v1');
    final savedMemories = prefs.getStringList('atheer_memories_v1') ?? <String>[];
    if (savedTasks != null) {
      try {
        final parsed = jsonDecode(savedTasks);
        if (parsed is List) {
          _tasks
            ..clear()
            ..addAll(parsed.whereType<Map>().map((item) => _Task(
              (item['title'] ?? '').toString(),
              (item['time'] ?? 'بدون موعد').toString(),
              item['done'] == true,
            )).where((task) => task.title.isNotEmpty));
        }
      } catch (_) {
        // Keep the starter tasks if saved data was malformed.
      }
    } else {
      await _persistTasks();
    }
    _memories
      ..clear()
      ..addAll(savedMemories.where((item) => item.trim().isNotEmpty));
    if (mounted) setState(() => _localDataReady = true);
  }

  Future<void> _persistTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('atheer_tasks_v1', jsonEncode(_tasks.map((task) => <String, dynamic>{
      'title': task.title, 'time': task.time, 'done': task.done,
    }).toList()));
  }

  Future<void> _persistMemories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('atheer_memories_v1', _memories);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _voice.dispose();
    super.dispose();
  }

  bool get _isActive => _voiceState == AtheerVoiceState.listening ||
      _voiceState == AtheerVoiceState.thinking ||
      _voiceState == AtheerVoiceState.speaking ||
      _voiceState == AtheerVoiceState.connecting;
  bool get _isSpeaking => _voiceState == AtheerVoiceState.speaking;

  String get _statusLabel {
    switch (_voiceState) {
      case AtheerVoiceState.idle: return _configReady ? 'STANDBY • READY' : 'SETUP REQUIRED';
      case AtheerVoiceState.connecting: return 'INITIALIZING SECURE LINK';
      case AtheerVoiceState.listening: return 'LISTENING • AUDIO INPUT';
      case AtheerVoiceState.thinking: return 'PROCESSING • NEURAL CORE';
      case AtheerVoiceState.speaking: return 'VOICE OUTPUT • ACTIVE';
      case AtheerVoiceState.error: return 'LINK ERROR • CHECK SYSTEM';
    }
  }

  Future<void> _toggleVoice() async {
    if (!_localDataReady) { _showSnack('لحظة يا خليل، أجهز بيانات أثير المحلية.'); return; }
    if (_isActive) {
      await _voice.stop();
      return;
    }
    try {
      await _voice.start(memories: _memories);
    } catch (e) {
      if (!mounted) return;
      _showSnack(_voice.lastError ?? e.toString());
    }
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text, textDirection: TextDirection.rtl)));
  }

  String _clockText() {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    final s = _now.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _dateText() {
    const days = <String>['الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت','الأحد'];
    const months = <String>['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    return '${days[_now.weekday - 1]} • ${_now.day} ${months[_now.month - 1]} ${_now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              const _CircuitBackground(),
              Positioned.fill(child: _buildMain()),
              if (_drawerOpen) ...[
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => setState(() => _drawerOpen = false),
                    child: Container(color: Colors.black.withOpacity(.68)),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: _CommandDrawer(
                    onClose: () => setState(() => _drawerOpen = false),
                    onSelect: (item) => _selectCommand(item),
                    taskCount: _tasks.where((t) => !t.done).length,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMain() {
    return LayoutBuilder(builder: (context, constraints) {
      final height = constraints.maxHeight;
      return Column(
        children: [
          _topBar(),
          _clockPanel(),
          Expanded(
            child: Stack(
              children: [
                Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: height * .025, bottom: 18),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 490, maxHeight: 490),
                        child: NeuralOrb(active: _isActive, speaking: _isSpeaking),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 16,
                  child: _sideDataStrip(),
                ),
                Positioned(
                  right: 16,
                  top: 18,
                  child: _systemIndicators(),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 7,
                  child: _voiceConsole(),
                ),
              ],
            ),
          ),
          _bottomStatusBar(),
        ],
      );
    });
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Row(children: [
      _IconSquare(icon: CupertinoIcons.line_horizontal_3, onTap: () => setState(() => _drawerOpen = true)),
      const SizedBox(width: 10),
      Container(width: 1, height: 32, color: cyan.withOpacity(.15)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('أثير  //  ATHEER AI', style: TextStyle(color: textBright, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
        const SizedBox(height: 3),
        Text('PERSONAL INTELLIGENCE SYSTEM', style: TextStyle(color: cyan.withOpacity(.62), fontSize: 8.5, letterSpacing: 1.3)),
      ])),
      _LiveBadge(active: _isActive),
    ]),
  );

  Widget _clockPanel() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 6),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF041017).withOpacity(.86),
        border: Border.all(color: cyan.withOpacity(.3)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: cyan.withOpacity(.055), blurRadius: 22)],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('LOCAL CLOCK', style: TextStyle(color: cyan.withOpacity(.6), fontSize: 7, letterSpacing: 1.1)),
          const SizedBox(height: 3),
          Text(_dateText(), style: const TextStyle(color: textMuted, fontSize: 9)),
        ]),
        Text(_clockText(), style: const TextStyle(color: cyan, fontSize: 23, fontWeight: FontWeight.w700, letterSpacing: 3, fontFeatures: [])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('CORE TIME', style: TextStyle(color: cyan.withOpacity(.6), fontSize: 7, letterSpacing: 1)),
          const SizedBox(height: 3),
          const Text('SYNC // 100%', style: TextStyle(color: textMuted, fontSize: 8)),
        ]),
      ]),
    ),
  );

  Widget _sideDataStrip() => SizedBox(
    width: 106,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _miniPanel('NEURAL CORE', 'ONLINE', true),
      const SizedBox(height: 7),
      _miniPanel('VOICE ENGINE', _isActive ? 'ACTIVE' : 'STANDBY', _isActive),
      const SizedBox(height: 7),
      _miniPanel('TASK QUEUE', '${_tasks.where((t) => !t.done).length} OPEN', false),
      const SizedBox(height: 7),
      _miniPanel('MEMORY', 'LOCAL ONLY', false),
    ]),
  );

  Widget _miniPanel(String title, String value, bool active) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xFF071016).withOpacity(.88),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: (active ? cyan : const Color(0xFF29414A)).withOpacity(.45)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: textMuted, fontSize: 7, letterSpacing: .6)),
      const SizedBox(height: 4),
      Row(children: [
        Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: active ? cyan : textMuted)),
        const SizedBox(width: 4),
        Expanded(child: Text(value, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? cyan : textBright, fontSize: 8, fontWeight: FontWeight.w600, letterSpacing: .4))),
      ]),
    ]),
  );

  Widget _systemIndicators() => Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
    _smallTag('SECURE CHANNEL', CupertinoIcons.lock_shield, cyan),
    const SizedBox(height: 7),
    _smallTag('VOICE: MARIN', CupertinoIcons.waveform, _isActive ? cyan : textMuted),
    const SizedBox(height: 7),
    _smallTag('LANG: AR-YE', CupertinoIcons.globe, textMuted),
  ]);

  Widget _smallTag(String label, IconData icon, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(color: panel.withOpacity(.77), border: Border.all(color: color.withOpacity(.19)), borderRadius: BorderRadius.circular(5)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 10), const SizedBox(width: 5), Text(label, style: TextStyle(color: color, fontSize: 7.5, letterSpacing: .45))]),
  );

  Widget _voiceConsole() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
    child: Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFF030A0F).withOpacity(.92),
          border: Border.all(color: cyan.withOpacity(.18)),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 5, height: 30, decoration: BoxDecoration(color: _isActive ? cyan : cyanDim.withOpacity(.4), borderRadius: BorderRadius.circular(5))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_latestWho.toUpperCase(), style: TextStyle(color: cyan.withOpacity(.75), fontSize: 8, letterSpacing: 1.1)),
            const SizedBox(height: 4),
            Text(_latestText, maxLines: 2, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl, style: const TextStyle(color: textBright, fontSize: 12, height: 1.4)),
          ])),
          const SizedBox(width: 6),
          Icon(CupertinoIcons.waveform_path, color: _isActive ? cyan : textMuted, size: 19),
        ]),
      ),
      const SizedBox(height: 15),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _roundControl(
          icon: _isActive ? CupertinoIcons.stop_fill : CupertinoIcons.mic_fill,
          label: _isActive ? 'END SESSION' : 'START VOICE',
          large: true,
          active: _isActive,
          onTap: _toggleVoice,
        ),
        const SizedBox(width: 12),
        _roundControl(icon: CupertinoIcons.text_bubble, label: 'TRANSCRIPT', onTap: _openTranscript),
        const SizedBox(width: 12),
        _roundControl(icon: CupertinoIcons.gear, label: 'SETTINGS', onTap: _openSettings),
      ]),
      const SizedBox(height: 7),
      Text(_voiceState == AtheerVoiceState.error ? (_voice.lastError ?? 'LINK ERROR') : _statusLabel,
        style: TextStyle(color: _voiceState == AtheerVoiceState.error ? const Color(0xFFFF7380) : cyan.withOpacity(.63), fontSize: 8, letterSpacing: 1.15)),
    ]),
  );

  Widget _roundControl({required IconData icon, required String label, required VoidCallback onTap, bool large = false, bool active = false}) {
    final size = large ? 58.0 : 42.0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(width: large ? 82 : 64, child: Column(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? cyan.withOpacity(.17) : const Color(0xFF07131A),
            border: Border.all(color: (active ? cyan : cyanDim).withOpacity(large ? .8 : .55), width: large ? 1.5 : 1),
            boxShadow: active || large ? [BoxShadow(color: cyan.withOpacity(active ? .18 : .07), blurRadius: 22)] : null,
          ),
          child: Icon(icon, size: large ? 22 : 17, color: active ? textBright : cyan),
        ),
        const SizedBox(height: 6),
        Text(label, maxLines: 1, style: TextStyle(color: large ? cyan : textMuted, fontSize: 6.5, letterSpacing: .45)),
      ])),
    );
  }

  Widget _bottomStatusBar() => Container(
    margin: const EdgeInsets.fromLTRB(14, 5, 14, 10),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: const Color(0xFF071016), borderRadius: BorderRadius.circular(7), border: Border.all(color: cyan.withOpacity(.15))),
    child: Row(children: [
      Icon(CupertinoIcons.waveform_path, color: cyan.withOpacity(.8), size: 13),
      const SizedBox(width: 7),
      Expanded(child: Text(_statusLabel, style: const TextStyle(color: textMuted, fontSize: 8, letterSpacing: .9))),
      Text('ATHEER OS  /  v1.0', style: TextStyle(color: cyan.withOpacity(.45), fontSize: 7, letterSpacing: .8)),
    ]),
  );

  void _selectCommand(String item) {
    setState(() => _drawerOpen = false);
    switch (item) {
      case 'voice': _toggleVoice(); break;
      case 'transcript': _openTranscript(); break;
      case 'tasks': _openTasks(); break;
      case 'settings': _openSettings(); break;
      case 'memory': _openMemory(); break;
      case 'research': _openResearch(); break;
      case 'advisor': _showInfo('المستشارة', 'أثير مهيأة للحوار اليمني الدافئ وتقديم نصائح عملية. ستعمل هذه الشخصية عند نجاح اتصال الصوت.'); break;
      case 'tasks_add': _addTask(); break;
    }
  }

  void _openSettings() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: panel,
    builder: (_) => _SettingsSheet(onSaved: _loadConfig),
  );

  void _openTranscript() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: panel,
    builder: (_) => Directionality(textDirection: TextDirection.rtl, child: SafeArea(
      child: SizedBox(height: MediaQuery.of(context).size.height * .72, child: Column(children: [
        const Padding(padding: EdgeInsets.all(16), child: Text('سجل المحادثة', style: TextStyle(color: cyan, fontSize: 18, fontWeight: FontWeight.w600))),
        const Divider(color: Color(0xFF19303A)),
        Expanded(child: _conversation.isEmpty
          ? const Center(child: Text('لا توجد رسائل بعد. ابدأ جلسة صوتية.', style: TextStyle(color: textMuted)))
          : ListView.builder(itemCount: _conversation.length, itemBuilder: (context, i) {
              final message = _conversation[i];
              return Align(alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5), padding: const EdgeInsets.all(12), constraints: const BoxConstraints(maxWidth: 320),
                  decoration: BoxDecoration(color: message.isUser ? const Color(0xFF102833) : const Color(0xFF11171C), borderRadius: BorderRadius.circular(12), border: Border.all(color: cyan.withOpacity(.13))),
                  child: Text(message.text, style: const TextStyle(color: textBright, height: 1.5)),
                ),
              );
            })),
      ])),
    )),
  );

  void _openTasks() => showModalBottomSheet<void>(
    context: context, isScrollControlled: true, backgroundColor: panel,
    builder: (_) => Directionality(textDirection: TextDirection.rtl, child: StatefulBuilder(builder: (context, sheetSetState) => SafeArea(
      child: SizedBox(height: MediaQuery.of(context).size.height * .68, child: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [const Expanded(child: Text('مركز المهام', style: TextStyle(color: cyan, fontSize: 19, fontWeight: FontWeight.w700))), IconButton(onPressed: () => _addTask(sheetSetState), icon: const Icon(CupertinoIcons.add, color: cyan))])),
        Expanded(child: ListView.builder(itemCount: _tasks.length, itemBuilder: (context, index) {
          final task = _tasks[index];
          return CheckboxListTile(
            value: task.done,
            onChanged: (value) => sheetSetState(() => setState(() => task.done = value ?? false)),
            activeColor: cyan,
            checkColor: bg,
            title: Text(task.title, style: const TextStyle(color: textBright)),
            subtitle: Text(task.time, style: const TextStyle(color: textMuted)),
            secondary: const Icon(CupertinoIcons.circle_grid_3x3, color: cyanDim),
          );
        })),
      ])),
    ))),
  );

  void _addTask([StateSetter? sheetSetState]) {
    final controller = TextEditingController();
    showDialog<void>(context: context, builder: (dialogContext) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: const Color(0xFF101820),
        title: const Text('مهمة جديدة', style: TextStyle(color: cyan)),
        content: TextField(controller: controller, autofocus: true, style: const TextStyle(color: textBright), decoration: const InputDecoration(hintText: 'اكتب المهمة', hintStyle: TextStyle(color: textMuted))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          FilledButton(onPressed: () {
            if (controller.text.trim().isNotEmpty) {
              setState(() => _tasks.add(_Task(controller.text.trim(), 'بدون موعد', false)));
              _persistTasks();
              sheetSetState?.call(() {});
            }
            Navigator.pop(dialogContext);
          }, child: const Text('إضافة')),
        ],
      ),
    ));
  }

  void _openMemory() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: panel,
    builder: (sheetContext) => Directionality(
      textDirection: TextDirection.rtl,
      child: StatefulBuilder(builder: (context, sheetSetState) => SafeArea(
        child: SizedBox(height: MediaQuery.of(context).size.height * .68, child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(18, 18, 10, 12), child: Row(children: [
            const Expanded(child: Text('الذاكرة الشخصية', style: TextStyle(color: cyan, fontSize: 19, fontWeight: FontWeight.w700))),
            IconButton(onPressed: () => _addMemory(sheetSetState), icon: const Icon(CupertinoIcons.add_circled, color: cyan)),
          ])),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: Text('تُحفظ هذه الملاحظات على هاتفك، وتُرسل كسياق للمساعد عند بدء جلسة صوتية.', style: TextStyle(color: textMuted, height: 1.5, fontSize: 11))),
          const SizedBox(height: 10),
          Expanded(child: _memories.isEmpty
            ? const Center(child: Text('لم تحفظ أي ملاحظات بعد.', style: TextStyle(color: textMuted)))
            : ListView.builder(itemCount: _memories.length, itemBuilder: (context, index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFF0C151B), borderRadius: BorderRadius.circular(9), border: Border.all(color: cyan.withOpacity(.12))),
                child: ListTile(
                  leading: const Icon(CupertinoIcons.bookmark, color: cyanDim),
                  title: Text(_memories[index], style: const TextStyle(color: textBright, fontSize: 12, height: 1.4)),
                  trailing: IconButton(icon: const Icon(CupertinoIcons.trash, color: textMuted, size: 17), onPressed: () async {
                    setState(() => _memories.removeAt(index));
                    await _persistMemories();
                    sheetSetState(() {});
                  }),
                ),
              ))),
        ])),
      )),
    ),
  );

  void _addMemory(StateSetter sheetSetState) {
    final controller = TextEditingController();
    showDialog<void>(context: context, builder: (dialogContext) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: const Color(0xFF101820),
        title: const Text('احفظ ملاحظة', style: TextStyle(color: cyan)),
        content: TextField(controller: controller, autofocus: true, maxLines: 3, style: const TextStyle(color: textBright), decoration: const InputDecoration(hintText: 'معلومة أو تفضيل تود أن تتذكره أثير…')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          FilledButton(onPressed: () async {
            final value = controller.text.trim();
            if (value.isNotEmpty) {
              setState(() { _memories.add(value); if (_memories.length > 50) _memories.removeAt(0); });
              await _persistMemories();
              sheetSetState(() {});
            }
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          }, child: const Text('حفظ')),
        ],
      ),
    ));
  }

  void _openResearch() {
    final queryController = TextEditingController();
    bool loading = false;
    String answer = '';
    String? error;
    List<Map<String, dynamic>> sources = <Map<String, dynamic>>[];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: panel,
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(builder: (context, sheetSetState) {
          Future<void> runSearch() async {
            final query = queryController.text.trim();
            if (query.length < 3 || loading) return;
            sheetSetState(() { loading = true; error = null; answer = ''; sources = <Map<String, dynamic>>[]; });
            try {
              final result = await ResearchService.search(query);
              sheetSetState(() {
                answer = (result['answer'] ?? '').toString();
                sources = (result['sources'] is List)
                    ? List<Map<String, dynamic>>.from((result['sources'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)))
                    : <Map<String, dynamic>>[];
              });
            } catch (e) {
              sheetSetState(() => error = e.toString().replaceFirst('Exception: ', ''));
            } finally {
              sheetSetState(() => loading = false);
            }
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(context).viewInsets.bottom + 18),
              child: SizedBox(height: MediaQuery.of(context).size.height * .78, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('مركز البحث والتحليل', style: TextStyle(color: cyan, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 7),
                const Text('ابحثي عبر الويب، ثم لخّصي النتائج وأظهري المصادر.', style: TextStyle(color: textMuted, fontSize: 11)),
                const SizedBox(height: 13),
                Row(children: [
                  Expanded(child: TextField(controller: queryController, textInputAction: TextInputAction.search, onSubmitted: (_) => runSearch(), style: const TextStyle(color: textBright), decoration: const InputDecoration(hintText: 'ما الذي تريد البحث عنه؟', border: OutlineInputBorder(), prefixIcon: Icon(CupertinoIcons.search)))),
                  const SizedBox(width: 8),
                  IconButton.filled(onPressed: runSearch, icon: const Icon(CupertinoIcons.arrow_up_right, color: bg)),
                ]),
                const SizedBox(height: 12),
                if (loading) const LinearProgressIndicator(color: cyan, backgroundColor: Color(0xFF142630)),
                if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(error!, style: const TextStyle(color: Color(0xFFFF8790)))),
                Expanded(child: ListView(children: [
                  if (answer.isNotEmpty) Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF091319), border: Border.all(color: cyan.withOpacity(.12)), borderRadius: BorderRadius.circular(9)), child: SelectableText(answer, style: const TextStyle(color: textBright, fontSize: 13, height: 1.65))),
                  if (sources.isNotEmpty) const Padding(padding: EdgeInsets.only(top: 14, bottom: 7), child: Text('المصادر', style: TextStyle(color: cyan, fontWeight: FontWeight.w700))),
                  ...sources.map((source) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(CupertinoIcons.link, color: cyanDim),
                    title: Text((source['title'] ?? source['url'] ?? 'المصدر').toString(), style: const TextStyle(color: textBright, fontSize: 12)),
                    subtitle: Text((source['url'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: textMuted, fontSize: 9)),
                    onTap: () async {
                      final rawUrl = (source['url'] ?? '').toString();
                      final uri = Uri.tryParse(rawUrl);
                      if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  )),
                ])),
              ])),
            ),
          );
        }),
      ),
    );
  }

  void _showInfo(String title, String message) => showDialog<void>(context: context, builder: (_) => Directionality(
    textDirection: TextDirection.rtl,
    child: AlertDialog(
      backgroundColor: const Color(0xFF101820),
      title: Text(title, style: const TextStyle(color: cyan)),
      content: Text(message, style: const TextStyle(color: textBright, height: 1.6)),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسنًا'))],
    ),
  ));
}

class _IconSquare extends StatelessWidget {
  const _IconSquare({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(7),
    child: Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFF08131A), border: Border.all(color: cyan.withOpacity(.25)), borderRadius: BorderRadius.circular(7)), child: Icon(icon, color: cyan, size: 18)),
  );
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(color: (active ? cyan : textMuted).withOpacity(.07), border: Border.all(color: (active ? cyan : textMuted).withOpacity(.3)), borderRadius: BorderRadius.circular(5)),
    child: Row(children: [Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: active ? cyan : textMuted)), const SizedBox(width: 5), Text(active ? 'LIVE' : 'STANDBY', style: TextStyle(color: active ? cyan : textMuted, fontSize: 8, letterSpacing: .8))]),
  );
}

class _CommandDrawer extends StatelessWidget {
  const _CommandDrawer({required this.onClose, required this.onSelect, required this.taskCount});
  final VoidCallback onClose;
  final ValueChanged<String> onSelect;
  final int taskCount;
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF060B10),
    child: SafeArea(child: SizedBox(width: mathMax(255, MediaQuery.of(context).size.width * .76), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 12, 18), child: Row(children: [
          const Icon(CupertinoIcons.circle_hexagongrid_fill, color: cyan, size: 23),
          const SizedBox(width: 10),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('ATHEER CONTROL', style: TextStyle(color: textBright, fontWeight: FontWeight.w700, letterSpacing: 1)), SizedBox(height: 4), Text('PERSONAL SYSTEM MENU', style: TextStyle(color: textMuted, fontSize: 8, letterSpacing: .8))])),
          IconButton(onPressed: onClose, icon: const Icon(CupertinoIcons.xmark, color: textMuted, size: 18)),
        ])),
        const Divider(color: Color(0xFF1A3943), height: 1),
        _section('CORE INTERFACE'),
        _item('الواجهة الرئيسية', 'DASHBOARD', CupertinoIcons.square_grid_2x2, 'advisor'),
        _item('المحادثة الصوتية', 'VOICE LINK', CupertinoIcons.waveform, 'voice'),
        _item('سجل الحوار', 'TRANSCRIPT LOG', CupertinoIcons.text_bubble, 'transcript'),
        _section('PERSONAL TOOLS'),
        _item('مركز المهام', '$taskCount OPEN TASKS', CupertinoIcons.checkmark_square, 'tasks'),
        _item('إضافة مهمة', 'CREATE NEW TASK', CupertinoIcons.add_circled, 'tasks_add'),
        _item('الذاكرة الشخصية', 'MEMORY CORE', CupertinoIcons.archivebox, 'memory'),
        _item('البحث والتحليل', 'RESEARCH ENGINE', CupertinoIcons.search, 'research'),
        _section('SYSTEM'),
        _item('إعدادات الاتصال', 'BACKEND / SECURITY', CupertinoIcons.gear, 'settings'),
        const Spacer(),
        Padding(padding: const EdgeInsets.all(16), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF07151B), border: Border.all(color: cyan.withOpacity(.15)), borderRadius: BorderRadius.circular(7)), child: const Text('أثير • نسخة أولية\nالصوت يعمل عند إعداد الخادم ورمز الوصول.', style: TextStyle(color: textMuted, fontSize: 11, height: 1.6)))),
      ],
    ))),
  );

  double mathMax(double a, double b) => a > b ? a : b;

  Widget _section(String title) => Padding(padding: const EdgeInsets.fromLTRB(16, 15, 16, 7), child: Text(title, style: TextStyle(color: cyan.withOpacity(.6), fontSize: 8, letterSpacing: 1.2)));
  Widget _item(String title, String subtitle, IconData icon, String key) => InkWell(
    onTap: () => onSelect(key),
    child: Container(margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10), decoration: BoxDecoration(color: const Color(0xFF0A1218), border: Border.all(color: cyan.withOpacity(.08)), borderRadius: BorderRadius.circular(6)), child: Row(children: [
      Icon(icon, color: cyan.withOpacity(.83), size: 18),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: textBright, fontSize: 12)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: textMuted, fontSize: 7, letterSpacing: .6))])),
      const Icon(CupertinoIcons.chevron_left, color: textMuted, size: 12),
    ])),
  );
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({required this.onSaved});
  final VoidCallback onSaved;
  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  final _urlController = TextEditingController();
  final _codeController = TextEditingController();
  bool _loading = true;
  bool _hideCode = true;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    _urlController.text = await AppConfig.getBackendUrl();
    _codeController.text = await AppConfig.getAccessCode();
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: SafeArea(child: Padding(
      padding: EdgeInsets.fromLTRB(20, 22, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: _loading ? const Center(child: CircularProgressIndicator(color: cyan)) : SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('إعداد الاتصال الآمن', style: TextStyle(color: cyan, fontSize: 21, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('اكتب عنوان خادمك المنشور على HTTPS ورمز الوصول الذي أعددته في الخادم. لا تضع مفتاح OpenAI هنا.', style: TextStyle(color: textMuted, height: 1.6, fontSize: 12)),
          const SizedBox(height: 20),
          const Text('رابط الخادم', style: TextStyle(color: textBright, fontSize: 12)),
          const SizedBox(height: 7),
          TextField(controller: _urlController, keyboardType: TextInputType.url, style: const TextStyle(color: textBright), decoration: const InputDecoration(hintText: 'https://your-project.replit.app', prefixIcon: Icon(CupertinoIcons.link), filled: true, fillColor: Color(0xFF080F15), border: OutlineInputBorder())),
          const SizedBox(height: 16),
          const Text('رمز الوصول', style: TextStyle(color: textBright, fontSize: 12)),
          const SizedBox(height: 7),
          TextField(controller: _codeController, obscureText: _hideCode, style: const TextStyle(color: textBright), decoration: InputDecoration(hintText: 'الرمز الذي ضبطته في الخادم', prefixIcon: const Icon(CupertinoIcons.lock), suffixIcon: IconButton(icon: Icon(_hideCode ? CupertinoIcons.eye : CupertinoIcons.eye_slash), onPressed: () => setState(() => _hideCode = !_hideCode)), filled: true, fillColor: const Color(0xFF080F15), border: const OutlineInputBorder())),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () async {
              final url = _urlController.text.trim();
              if (url.isNotEmpty && !url.startsWith('https://')) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('استخدم رابط HTTPS آمنًا.')));
                return;
              }
              await AppConfig.save(backendUrl: url, accessCode: _codeController.text);
              widget.onSaved();
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(CupertinoIcons.checkmark_shield),
            label: const Text('حفظ الإعدادات'),
          ),
          const SizedBox(height: 8),
          const Text('الأمان: رمز الوصول ليس بديلًا عن تسجيل دخول قوي. لا توزّع هذا التطبيق على العامة قبل إضافة مصادقة للمستخدمين.', style: TextStyle(color: textMuted, fontSize: 10, height: 1.5)),
        ],
      )),
    )),
  );
}

class _CircuitBackground extends StatelessWidget {
  const _CircuitBackground();
  @override
  Widget build(BuildContext context) => IgnorePointer(child: CustomPaint(painter: _CircuitPainter(), size: Size.infinite));
}

class _CircuitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = .5..color = cyan.withOpacity(.045);
    const step = 36.0;
    for (double x = 0; x < size.width; x += step) {
      final p = Path()..moveTo(x, 0)..lineTo(x, size.height);
      canvas.drawPath(p, paint);
    }
    for (double y = 0; y < size.height; y += step) {
      final p = Path()..moveTo(0, y)..lineTo(size.width, y);
      canvas.drawPath(p, paint);
    }
    final glowPaint = Paint()..shader = RadialGradient(colors: [cyan.withOpacity(.035), Colors.transparent]).createShader(Rect.fromCircle(center: Offset(size.width * .52, size.height * .47), radius: size.width * .63));
    canvas.drawRect(Offset.zero & size, glowPaint);
    final cornerPaint = Paint()..color = cyan.withOpacity(.12)..style = PaintingStyle.stroke..strokeWidth = 1.3;
    const l = 20.0;
    for (final corner in <Offset>[Offset(12,12), Offset(size.width-12,12), Offset(12,size.height-12), Offset(size.width-12,size.height-12)]) {
      final sx = corner.dx < size.width/2 ? 1.0 : -1.0;
      final sy = corner.dy < size.height/2 ? 1.0 : -1.0;
      final path = Path()..moveTo(corner.dx + sx*l, corner.dy)..lineTo(corner.dx, corner.dy)..lineTo(corner.dx, corner.dy + sy*l);
      canvas.drawPath(path, cornerPaint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Message { _Message(this.text, this.isUser); final String text; final bool isUser; }
class _Task { _Task(this.title, this.time, this.done); final String title; final String time; bool done; }