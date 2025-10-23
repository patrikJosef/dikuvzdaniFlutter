import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import 'dart:async';
import 'package:html/parser.dart' as html_parser;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import 'package:html/dom.dart' as dom;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

const linkColor = Colors.lightBlueAccent;
const barvaFunkcnichTlacitekVyberuTextuAKurzoru = Colors.amber;
const barvaFunkcnichTlacitekVyberuTextuAKurzoruPrusvitnost =
    Color.fromRGBO(255, 193, 7, 0.3);
const translucentBlue =
    Color.fromRGBO(3, 169, 244, 0.3); // RGB pro lightBlueAccent

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Díkůvzdání',
      theme: ThemeData(
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: barvaFunkcnichTlacitekVyberuTextuAKurzoru,
          selectionColor: barvaFunkcnichTlacitekVyberuTextuAKurzoruPrusvitnost,
          selectionHandleColor: barvaFunkcnichTlacitekVyberuTextuAKurzoru,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderSide:
                BorderSide(color: barvaFunkcnichTlacitekVyberuTextuAKurzoru),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
                color: barvaFunkcnichTlacitekVyberuTextuAKurzoru, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide:
                BorderSide(color: barvaFunkcnichTlacitekVyberuTextuAKurzoru),
          ),
        ),
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
      ),
      home: const MainActivity(),
      locale: const Locale('cs'),
      supportedLocales: const [
        Locale('cs'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

class MainActivity extends StatefulWidget {
  const MainActivity({Key? key}) : super(key: key);

  @override
  State<MainActivity> createState() => _MainActivityState();
}

class _MainActivityState extends State<MainActivity> {
  final TextEditingController _taskListController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _intentionsController = TextEditingController();

  String _currentView = 'home';
  double _scaleFactor = 1.0;
  double _baseScaleFactor = 1.0;
  bool _sendMailChecked = false;
  String _dailyMotto = '';
  Color barvaTextuNavTlacitek = Colors.white;
  Color barvaTextuFunTlacitek = Colors.black;

  bool _latin = false; // false = Česky, true = Latinsky

  @override
  void initState() {
    super.initState();
    _loadFiles();
    _loadDailyMotto();
    _loadFontSize();
    _loadTodayEvents();
  }

  String _latinVariant(String path) {
    if (path.endsWith('.txt')) {
      return path.replaceFirst('.txt', '_lat.txt');
    } else {
      return '${path}_lat';
    }
  }

  void _switchLanguage(bool latin) {
    setState(() {
      _latin = latin;
    });
  }

  Future<void> _loadFiles() async {
    final taskList = await FileUtils.readFromFile(taskListFilename);
    final notes = await FileUtils.readFromFile(notesFilename);
    final intentions = await FileUtils.readFromFile(intentionsFilename);

    setState(() {
      _taskListController.text = taskList;
      _notesController.text = notes;
      _intentionsController.text = intentions;
    });
  }

  List<Map<String, dynamic>> _todayEvents = [];

  Future<void> _loadTodayEvents() async {
    try {
      final now = DateTime.now().toUtc();
      final startOfDay = DateTime.utc(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      const calendarId = 'k9grn9pcub347543afce5uiv50@group.calendar.google.com';
      const apiKey = 'AIzaSyAfvufRSQUCvBS8wpIOkibNq9m-CvfQa0M';

      final url =
          'https://www.googleapis.com/calendar/v3/calendars/$calendarId/events'
          '?key=$apiKey'
          '&timeMin=${startOfDay.toIso8601String()}Z'
          '&timeMax=${endOfDay.toIso8601String()}Z'
          '&singleEvents=true'
          '&orderBy=startTime';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final events = data['items'] as List<dynamic>;

        setState(() {
          _todayEvents = events.take(4).map((event) {
            final summary = event['summary'] ?? '(bez názvu)';
            final start = event['start']['dateTime'] ?? event['start']['date'];
            final time =
                start != null ? start.toString().substring(11, 16) : '';
            return {
              'time': time,
              'summary': summary,
            };
          }).toList();
        });
      } else {
        print('Chyba načítání kalendáře: ${response.statusCode}');
      }
    } catch (e) {
      print('Chyba: $e');
    }
  }

  Future<void> _loadFontSize() async {
    try {
      final content = await FileUtils.readFromFile(moznostiFilename);
      final lines = content.split('\n');
      if (lines.length > 7) {
        final sizeStr = lines[7].trim();
        final size = double.tryParse(sizeStr) ?? 1.0;
        setState(() {
          _scaleFactor = size.clamp(0.5, 3.0);
          _baseScaleFactor = _scaleFactor;
        });
      }
    } catch (e) {
      // Default value
    }
  }

  Future<void> _loadDailyMotto() async {
    try {
      final content = await FileUtils.readFromFile(moznostiFilename);
      final lines =
          content.split('\n').where((line) => line.trim().isNotEmpty).toList();
      final dayOfWeek = DateTime.now().weekday;

      if (lines.isNotEmpty) {
        final index = (dayOfWeek - 1).clamp(0, lines.length - 1);
        setState(() {
          _dailyMotto = lines[index];
        });
      }
    } catch (e) {
      setState(() {
        _dailyMotto = 'Cor Mariae dulcissimum, iter para tutum';
      });
    }
  }

  Future<void> _saveFiles() async {
    await FileUtils.writeToFile(_taskListController.text, taskListFilename);
    await FileUtils.writeToFile(_notesController.text, notesFilename);
    await FileUtils.writeToFile(_intentionsController.text, intentionsFilename);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('POZNÁMKY I ÚMYSLY ULOŽENY'),
        backgroundColor: barvaFunkcnichTlacitekVyberuTextuAKurzoru,
        duration: Duration(seconds: 2),
      ),
    );

    if (_sendMailChecked) {
      final shareContent =
          '${_taskListController.text}\n\n${_notesController.text}\n\n${_intentionsController.text}';

      await Share.share(
        shareContent,
        subject: 'ZalohaDikuvzdani',
      );

      setState(() => _sendMailChecked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(35),
        child: AppBar(
          title: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              text: _dailyMotto.isNotEmpty
                  ? _dailyMotto
                  : 'Cor Mariae dulcissimum, iter para tutum',
              style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic),
            ),
          ),
        ),
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          _buildButtonBar(),
          if (_todayEvents.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _todayEvents.map((event) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey[800],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${event['time']}  ${event['summary']}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          // Přepínač jazyků
          // Přepínač jazyků (jen pro statické texty)
          if (_currentView != 'home' &&
              _currentView != 'beforeMass' &&
              _currentView != 'afterMass' &&
              _currentView != 'onMass' &&
              _currentView != 'notes' &&
              _currentView != 'intentions')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _switchLanguage(false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _latin ? Colors.blueGrey : Colors.black,
                        foregroundColor: _latin ? Colors.white : Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('ČESKY'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _switchLanguage(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            !_latin ? Colors.blueGrey : Colors.black,
                        foregroundColor: !_latin ? Colors.white : Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('LATINSKY'),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildMainContent()),
        ],
      ),
    );
  }

  Widget _buildButtonBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 3),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 2.67,
        children: [
          _NavButton('Úmysly', _clickHome, barvaTextuNavTlacitek),
          _NavButton(
              'Modlitby', () => _setView('prayers'), barvaTextuNavTlacitek),
          _NavButton(
              '2. Žalm', () => _setView('psalm2'), barvaTextuNavTlacitek),
          _NavButton(
              'Adoro te', () => _setView('adoro'), barvaTextuNavTlacitek),
          _NavButton('Trium', () => _setView('trium'), barvaTextuNavTlacitek),
          _NavButton(
              'Quicumque', () => _setView('quicumque'), barvaTextuNavTlacitek),
          _NavButton(
              'Litanie', () => _setView('litanie'), barvaTextuNavTlacitek),
          _NavButton(
              'Přede mší', () => _setView('beforeMass'), barvaTextuNavTlacitek),
          _NavButton(
              'Po mši', () => _setView('afterMass'), barvaTextuNavTlacitek),
          _NavButton(
              'Při mši', () => _setView('onMass'), barvaTextuNavTlacitek),
          _NavButton(
              'Poznámky', () => _setView('notes'), barvaTextuFunTlacitek),
          _NavButton(
              'Úmysly', () => _setView('intentions'), barvaTextuFunTlacitek),
        ],
      ),
    );
  }

  void _setView(String view) => setState(() => _currentView = view);
  void _clickHome() => setState(() => _currentView = 'home');

  Widget _buildMainContent() {
    switch (_currentView) {
      case 'home':
        return _buildHomeView();
      case 'notes':
        return _buildEditableView('notes');
      case 'intentions':
        return _buildEditableView('intentions');
      case 'psalm2':
      case 'adoro':
      case 'trium':
      case 'quicumque':
      case 'prayers':
      case 'beforeMass':
      case 'afterMass':
      case 'onMass':
      case 'litanie':
        return _buildTextView(_currentView);
      default:
        return _buildHomeView();
    }
  }

  Widget _buildHomeView() {
    final content =
        '${_taskListController.text}\n\n${_intentionsController.text}';

    return GestureDetector(
      onScaleStart: (details) => _baseScaleFactor = _scaleFactor,
      onScaleUpdate: (details) => setState(() =>
          _scaleFactor = (_baseScaleFactor * details.scale).clamp(0.5, 3.0)),
      onScaleEnd: (details) => _baseScaleFactor = _scaleFactor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: HtmlText(
          content,
          scaleFactor: _scaleFactor,
        ),
      ),
    );
  }

  Widget _buildEditableView(String type) {
    final controller =
        type == 'notes' ? _notesController : _intentionsController;

    return Column(
      children: [
        if (type == 'intentions') _buildHtmlToolbar(controller),
        Expanded(
          child: TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            style: const TextStyle(color: Colors.black),
            decoration: const InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              ElevatedButton(
                onPressed: _showMoznostiDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: barvaFunkcnichTlacitekVyberuTextuAKurzoru,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  textStyle: const TextStyle(fontSize: 12), // zmenšené písmo
                  //   minimumSize: const Size(60, 30), // menší výška a šířka
                ),
                child: const Text('NASTAVENÍ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _showTemataDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: barvaFunkcnichTlacitekVyberuTextuAKurzoru,
                  foregroundColor: barvaTextuFunTlacitek,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  textStyle: const TextStyle(fontSize: 12), // zmenšené písmo
                  // minimumSize: const Size(60, 30), // menší výška a šířka
                ),
                child: const Text('TÉMATA',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              Checkbox(
                value: _sendMailChecked,
                onChanged: (val) =>
                    setState(() => _sendMailChecked = val ?? false),
                fillColor: MaterialStatePropertyAll(Colors.white),
                checkColor: Colors.black,
              ),
              const Text('ZÁLOHOVAT',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              const Spacer(),
              ElevatedButton(
                onPressed: _saveFiles,
                style: ElevatedButton.styleFrom(
                  backgroundColor: barvaFunkcnichTlacitekVyberuTextuAKurzoru,
                  foregroundColor: barvaTextuFunTlacitek,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  textStyle: const TextStyle(fontSize: 12), // zmenšené písmo
                  // minimumSize: const Size(60, 30), // menší výška a šířka
                ),
                child: const Text('ULOŽIT',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }

// --- dialog TÉMATA (7 políček + ZRUŠIT a ULOŽIT) ---
  Future<void> _showTemataDialog() async {
    String content = await FileUtils.readFromFile(moznostiFilename);
    List<String> lines = content.split('\n');

    final controllers = List.generate(7, (i) {
      final controller = TextEditingController();
      if (i < lines.length && lines[i].trim().isNotEmpty) {
        controller.text = lines[i];
      } else {
        controller.text = '';
      }
      return controller;
    });

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.grey[900],
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('TÉMATA',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('ZRUŠIT',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final oldContent =
                            await FileUtils.readFromFile(moznostiFilename);
                        final oldLines = oldContent.split('\n');
                        final fontSizeLine =
                            oldLines.length > 7 ? oldLines[7] : '1.0';
                        final newLines = [
                          ...controllers.map((c) => c.text),
                          fontSizeLine
                        ];
                        await FileUtils.writeToFile(
                            newLines.join('\n'), moznostiFilename);
                        await _loadDailyMotto();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('TÉMATA ULOŽENA'),
                            backgroundColor:
                                barvaFunkcnichTlacitekVyberuTextuAKurzoru,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            barvaFunkcnichTlacitekVyberuTextuAKurzoru,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('ULOŽIT',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...List.generate(7, (i) {
                  final days = [
                    'Pondělí',
                    'Úterý',
                    'Středa',
                    'Čtvrtek',
                    'Pátek',
                    'Sobota',
                    'Neděle'
                  ];
                  final currentDay = DateTime.now().weekday - 1;
                  final isToday = i == currentDay;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${days[i]}${isToday ? ' (DNES)' : ''}',
                          style: TextStyle(
                            color: isToday
                                ? barvaFunkcnichTlacitekVyberuTextuAKurzoru
                                : Colors.white70,
                            fontSize: 12,
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: controllers[i],
                          maxLines: 2,
                          style: const TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('ZRUŠIT',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final oldContent =
                            await FileUtils.readFromFile(moznostiFilename);
                        final oldLines = oldContent.split('\n');
                        final fontSizeLine =
                            oldLines.length > 7 ? oldLines[7] : '1.0';
                        final newLines = [
                          ...controllers.map((c) => c.text),
                          fontSizeLine
                        ];
                        await FileUtils.writeToFile(
                            newLines.join('\n'), moznostiFilename);
                        await _loadDailyMotto();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('TÉMATA ULOŽENA'),
                            backgroundColor:
                                barvaFunkcnichTlacitekVyberuTextuAKurzoru,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            barvaFunkcnichTlacitekVyberuTextuAKurzoru,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('ULOŽIT',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

// --- dialog NASTAVENÍ (jen velikost písma) ---
  Future<void> _showMoznostiDialog() async {
    String content = await FileUtils.readFromFile(moznostiFilename);
    List<String> lines = content.split('\n');

    // Dropdown pro velikost textu
    const validSizes = ['0.5', '0.75', '1.0', '1.25', '1.5', '2.0', '3.0'];
    String selectedSize =
        (lines.length > 7 && validSizes.contains(lines[7].trim()))
            ? lines[7].trim()
            : '1.0';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.grey[900],
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'NASTAVENÍ',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Dropdown pro velikost textu
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Velikost textu',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  StatefulBuilder(
                    builder: (context, setStateDropdown) {
                      return DropdownButton<String>(
                        value: selectedSize,
                        dropdownColor: Colors.grey[800],
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                              value: '0.5',
                              child: Text('0.5x (Velmi malá)',
                                  style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(
                              value: '0.75',
                              child: Text('0.75x (Malá)',
                                  style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(
                              value: '1.0',
                              child: Text('1.0x (Normální)',
                                  style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(
                              value: '1.25',
                              child: Text('1.25x (Větší)',
                                  style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(
                              value: '1.5',
                              child: Text('1.5x (Velká)',
                                  style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(
                              value: '2.0',
                              child: Text('2.0x (Velmi velká)',
                                  style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(
                              value: '3.0',
                              child: Text('3.0x (Obrovská)',
                                  style: TextStyle(color: Colors.white))),
                        ],
                        onChanged: (value) {
                          if (value != null)
                            setStateDropdown(() => selectedSize = value);
                        },
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('ZRUŠIT',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final newLines = [...lines.take(7), selectedSize];
                      await FileUtils.writeToFile(
                          newLines.join('\n'), moznostiFilename);
                      await _loadFontSize();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('NASTAVENÍ ULOŽENO'),
                          backgroundColor:
                              barvaFunkcnichTlacitekVyberuTextuAKurzoru,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          barvaFunkcnichTlacitekVyberuTextuAKurzoru,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('ULOŽIT',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHtmlToolbar(TextEditingController controller) {
    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          _htmlButton('B', () => _wrapSelectionWith(controller, '<b>', '</b>')),
          _htmlButton('I', () => _wrapSelectionWith(controller, '<i>', '</i>')),
          _htmlButton('🔗', () => _insertLink(controller)),
          _colorPicker(controller),
          const Spacer(),
          const Text('HTML',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _htmlButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }

  Widget _colorPicker(TextEditingController controller) {
    const colorMap = {
      'red': 'Červená',
      'blue': 'Modrá',
      'green': 'Zelená',
      'orange': 'Oranžová',
      'purple': 'Fialová',
      'pink': 'Růžová',
    };

    return DropdownButton<String>(
      dropdownColor: Colors.grey[900],
      hint: const Text('Barva',
          style: TextStyle(color: Colors.white, fontSize: 12)),
      items: colorMap.entries.map((entry) {
        final value = entry.key;
        final label = entry.value;
        return DropdownMenuItem<String>(
          value: value,
          child: Text(
            label,
            style: TextStyle(color: _parseColorForToolbar(value)),
          ),
        );
      }).toList(),
      onChanged: (String? selectedColor) {
        if (selectedColor != null) {
          _wrapSelectionWith(
              controller, '<font color="$selectedColor">', '</font>');
        }
      },
    );
  }

  Color _parseColorForToolbar(String colorStr) {
    switch (colorStr) {
      case 'red':
        return Colors.red;
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orange;
      case 'purple':
        return Colors.purple;
      case 'pink':
        return Colors.pinkAccent;
      default:
        return Colors.white;
    }
  }

  void _wrapSelectionWith(
      TextEditingController controller, String startTag, String endTag) {
    final text = controller.text;
    final selection = controller.selection;

    if (!selection.isValid || selection.isCollapsed) return;

    final selectedText = selection.textInside(text);
    final before = selection.textBefore(text);
    final after = selection.textAfter(text);

    final newText = '$before$startTag$selectedText$endTag$after';

    controller.text = newText;
    controller.selection = TextSelection.collapsed(
        offset: (before + startTag + selectedText + endTag).length);
  }

  void _insertLink(TextEditingController controller) {
    final selectedText = controller.selection.textInside(controller.text);
    final url = 'https://example.com';

    final link = '<a href="$url">$selectedText</a>';
    final before = controller.selection.textBefore(controller.text);
    final after = controller.selection.textAfter(controller.text);

    controller.text = '$before$link$after';
    controller.selection =
        TextSelection.collapsed(offset: (before + link).length);
  }

  Widget _buildTextView(String viewId) {
    final path = _latin
        ? _latinVariant('assets/texts/$viewId.txt') // např. psalm2_lat.txt
        : 'assets/texts/$viewId.txt';

    return FutureBuilder<String>(
      future: rootBundle.loadString(path),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: HtmlText(
            snapshot.data ?? '',
            scaleFactor: _scaleFactor,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _taskListController.dispose();
    _notesController.dispose();
    _intentionsController.dispose();
    super.dispose();
  }
}

Widget _NavButton(String label, VoidCallback onPressed, Color textColor) {
  return ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.blueGrey,
      foregroundColor: textColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, 48),
    ),
    child: Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            label.toUpperCase(),
            maxLines: 1,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    ),
  );
}

class HtmlText extends StatelessWidget {
  final String htmlContent;
  final double scaleFactor;

  const HtmlText(this.htmlContent, {required this.scaleFactor, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final document = html_parser.parse(htmlContent);
    final body = document.body;
    if (body == null) {
      return const Text('No content', style: TextStyle(color: Colors.white));
    }

    final textSpan = _parseBody(body);

    return SelectableText.rich(
      textSpan,
      textAlign: TextAlign.left,
      showCursor: false,
      cursorWidth: 0,
      enableInteractiveSelection: true,
    );
  }

  TextSpan _parseBody(dom.Element body) {
    final List<TextSpan> children = [];

    for (var node in body.nodes) {
      final span = _parseNode(node);
      if (span != null) {
        children.add(span);
      }
    }

    return TextSpan(children: children);
  }

  TextSpan? _parseNode(dom.Node node) {
    if (node.nodeType == dom.Node.TEXT_NODE) {
      final text = node.text ?? '';
      if (text.isEmpty) return null;

      return TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 19 * scaleFactor,
        ),
      );
    }

    if (node is! dom.Element) return null;

    final element = node;

    switch (element.localName) {
      case 'a':
        final href = element.attributes['href'] ?? '';
        final text = element.text;

        return TextSpan(
          text: text,
          style: TextStyle(
            color: linkColor,
            fontSize: 19 * scaleFactor,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()..onTap = () => _launchUrl(href),
        );

      case 'b':
      case 'strong':
        return TextSpan(
          text: element.text,
          style: TextStyle(
            color: Colors.white,
            fontSize: 19 * scaleFactor,
            fontWeight: FontWeight.bold,
          ),
        );

      case 'i':
      case 'em':
        return TextSpan(
          text: element.text,
          style: TextStyle(
            color: Colors.white,
            fontSize: 19 * scaleFactor,
            fontStyle: FontStyle.italic,
          ),
        );

      case 'font':
        final colorAttr = element.attributes['color'] ?? 'white';
        final color = _parseColor(colorAttr);
        final text = element.text;

        return TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: 19 * scaleFactor,
          ),
        );

      case 'br':
        return const TextSpan(text: '\n');

      case 'p':
        return TextSpan(
          text: '\n${element.text}\n',
          style: TextStyle(
            color: Colors.white,
            fontSize: 19 * scaleFactor,
          ),
        );

      default:
        return TextSpan(
          text: element.text,
          style: TextStyle(
            color: Colors.white,
            fontSize: 19 * scaleFactor,
          ),
        );
    }
  }

  void _launchUrl(String url) async {
    final norm = _normalizeUrl(url);
    final uri = Uri.parse(norm);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  String _normalizeUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    return 'https://$url';
  }

  Color _parseColor(String colorStr) {
    final clean = colorStr.replaceFirst('#', '').toLowerCase();

    const map = <String, Color>{
      'red': Colors.red,
      'blue': Colors.blue,
      'green': Colors.green,
      'orange': Colors.orange,
      'purple': Colors.purple,
      'pink': Colors.pinkAccent,
      'white': Colors.white,
      'yellow': Colors.yellow,
      'grey': Colors.grey,
    };

    if (map.containsKey(clean)) {
      return map[clean]!;
    }

    if (clean.length == 6) {
      try {
        return Color(int.parse('FF$clean', radix: 16));
      } catch (_) {}
    }

    return Colors.white;
  }
}

// 📄 názvy souborů používaných pro ukládání dat
const String taskListFilename = 'tasklist.txt';
const String notesFilename = 'notes.txt';
const String intentionsFilename = 'intentions.txt';
const String moznostiFilename = 'moznosti.txt';

class FileUtils {
  static Future<String> readFromFile(String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');

      if (!await file.exists()) {
        if (fileName == 'intentions.txt') {
          return '<a href="https://escriva.org/cs">escriva.org/cs</a> &nbsp;&nbsp; <a href="https://opusdei.cz">Opus Dei</a> &nbsp;&nbsp; <a href="https://catholica.cz">catholica.cz</a><br/><br/><a href="https://kalendar.katolik.cz">kalendar.katolik.cz</a> &nbsp;&nbsp; <a href="https://studiovox.cz">studiovox.cz</a>\n<font color="red">Cor Mariae dulcissimum, iter para tutum</font>';
        }
        if (fileName == 'moznosti.txt') {
          return 'Sancta Maria, Mater misericordiae, succurre animabus in purgatorio\nSancte Angele, adiuva nos\nSancte Ioseph, ora pro nobis\nIesu, in te confido\nPer crucem et passionem tuam, Domine, libera nos\nCor Mariae dulcissimum, iter para tutum\nGloria Patri, et Filio, et Spiritui Sancto';
        }
        return '';
      }

      return await file.readAsString();
    } catch (e) {
      if (fileName == 'intentions.txt') {
        return '<a href="https://escriva.org/cs">escriva.org/cs</a>';
      }
      if (fileName == 'moznosti.txt') {
        return 'Cor Mariae dulcissimum, iter para tutum';
      }
      return '';
    }
  }

  static Future<void> writeToFile(String data, String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(data);
    } catch (e) {
      print('File write failed: $e');
    }
  }
}