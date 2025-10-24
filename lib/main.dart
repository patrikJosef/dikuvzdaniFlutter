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
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

void main() {
  runApp(const MyApp());
}

const linkColor = Colors.lightBlueAccent;
const translucentBlue =
Color.fromRGBO(3, 169, 244, 0.3); // RGB pro lightBlueAccent
const barvaFunkcnichTlacitekVyberuTextuAKurzoru = translucentBlue;
const barvaFunkcnichTlacitekVyberuTextuAKurzoruPrusvitnost =
    Color.fromRGBO(255, 193, 7, 0.3);


class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Nastavit barvu status baru
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.black, // barva pod notchem / status barem
        statusBarIconBrightness: Brightness.light, // ikony bílé
      ),
    );
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
  String _calendarId = '';

  @override
  void initState() {
    super.initState();
    _loadFiles();
    _loadDailyMotto();
    _loadFontSize();
    _loadTodayEvents();
  }

  List<InlineSpan> _parseSimpleMarkdown(String text, {Color? baseColor}) {
    final spans = <InlineSpan>[];
    final defaultColor = baseColor ?? Colors.white;

    // Rozděl podle řádků pro zachování odřádkování
    final lines = text.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      int lastIndex = 0;

      // Najdi všechny formátovací prvky na řádku
      final linkRegex = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');
      final boldRegex = RegExp(r'\*\*(.+?)\*\*');
      final italicRegex = RegExp(r'\*(.+?)\*');

      // Vytvoř seznam všech matches s jejich pozicemi a typy
      final allMatches = <Map<String, dynamic>>[];

      for (var m in linkRegex.allMatches(line)) {
        allMatches.add({'start': m.start, 'end': m.end, 'match': m, 'type': 'link'});
      }
      for (var m in boldRegex.allMatches(line)) {
        allMatches.add({'start': m.start, 'end': m.end, 'match': m, 'type': 'bold'});
      }
      for (var m in italicRegex.allMatches(line)) {
        // Zkontroluj, zda není součástí bold (**text**)
        bool isPartOfBold = false;
        for (var boldMatch in allMatches.where((m) => m['type'] == 'bold')) {
          if (m.start >= boldMatch['start'] && m.end <= boldMatch['end']) {
            isPartOfBold = true;
            break;
          }
        }
        if (!isPartOfBold) {
          allMatches.add({'start': m.start, 'end': m.end, 'match': m, 'type': 'italic'});
        }
      }

      // Seřaď podle pozice
      allMatches.sort((a, b) => a['start'].compareTo(b['start']));

      // Odstraň překrývající se matches (upřednostni delší/dřívější)
      final filteredMatches = <Map<String, dynamic>>[];
      for (var match in allMatches) {
        bool overlaps = false;
        for (var existing in filteredMatches) {
          if ((match['start'] >= existing['start'] && match['start'] < existing['end']) ||
              (match['end'] > existing['start'] && match['end'] <= existing['end'])) {
            overlaps = true;
            break;
          }
        }
        if (!overlaps) {
          filteredMatches.add(match);
        }
      }

      for (var matchData in filteredMatches) {
        final match = matchData['match'] as Match;
        final type = matchData['type'] as String;

        // Přidej text před matchem
        if (match.start > lastIndex) {
          spans.add(TextSpan(
            text: line.substring(lastIndex, match.start),
            style: TextStyle(color: defaultColor, fontSize: 18, height: 1.4),
          ));
        }

        // Zpracuj match podle typu
        if (type == 'link') {
          final linkText = match.group(1)!;
          final url = match.group(2)!;
          spans.add(TextSpan(
            text: linkText,
            style: TextStyle(
              color: linkColor,
              fontSize: 18,
              height: 1.4,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _launchUrlFromMarkdown(url),
          ));
        } else if (type == 'bold') {
          spans.add(TextSpan(
            text: match.group(1),
            style: TextStyle(
              color: defaultColor,
              fontSize: 18,
              height: 1.4,
              fontWeight: FontWeight.bold,
            ),
          ));
        } else if (type == 'italic') {
          spans.add(TextSpan(
            text: match.group(1),
            style: TextStyle(
              color: defaultColor,
              fontSize: 18,
              height: 1.4,
              fontStyle: FontStyle.italic,
            ),
          ));
        }

        lastIndex = match.end;
      }

      // Přidej zbývající text na řádku
      if (lastIndex < line.length) {
        spans.add(TextSpan(
          text: line.substring(lastIndex),
          style: TextStyle(color: defaultColor, fontSize: 18, height: 1.4),
        ));
      }

      // Přidej odřádkování kromě posledního řádku
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return spans;
  }

  void _launchUrlFromMarkdown(String url) async {
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

  Widget _buildColoredMarkdown(String text) {
    final spans = <InlineSpan>[];
    int lastIndex = 0;

    final colorRegex = RegExp(r'<(red|blue|green|orange|purple|pink|yellow|grey)>(.*?)</\1>', dotAll: true);

    final matches = colorRegex.allMatches(text).toList();

    for (var match in matches) {
      // Přidej text před barevným textem
      if (match.start > lastIndex) {
        final beforeText = text.substring(lastIndex, match.start);
        spans.addAll(_parseSimpleMarkdown(beforeText));
      }

      // Přidej barevný text (může obsahovat další formátování)
      final colorName = match.group(1) ?? 'white';
      final color = _parseColor(colorName);
      final coloredText = match.group(2) ?? '';

      // Parsuj markdown uvnitř barevného textu
      spans.addAll(_parseSimpleMarkdown(coloredText, baseColor: color));

      lastIndex = match.end;
    }

    // Přidej zbývající text
    if (lastIndex < text.length) {
      final remainingText = text.substring(lastIndex);
      spans.addAll(_parseSimpleMarkdown(remainingText));
    }

    return SelectableText.rich(
      TextSpan(children: spans),
      style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.4),
    );
  }

  PopupMenuItem<String> _buildColorMenuItem(String label, String value, Color color) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white30),
            ),
          ),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
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
    final notes = await FileUtils.readFromFile(notesFilename);
    final intentions = await FileUtils.readFromFile(intentionsFilename);

    setState(() {
      _notesController.text = notes;
      _intentionsController.text = intentions;
    });
  }

  List<Map<String, dynamic>> _todayEvents = [];

  Future<void> _loadTodayEvents() async {
    try {
      final now = DateTime.now();

      // začátek a konec dne podle místního času
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // načtení API key a calendarId z moznosti.txt
      final content = await FileUtils.readFromFile(moznostiFilename);
      final lines = content.split('\n');
      const apiKey = String.fromEnvironment('GOOGLE_API_KEY');
      final calendarId = lines.length >  8? lines[8].trim() : '';

      if (apiKey.isEmpty || calendarId.isEmpty) {
        print('❌ API key nebo Calendar ID nejsou nastaveny.');
        setState(() => _todayEvents = []);
        return;
      }

      // 💡 Tady je klíč: převeď čas do formátu s časovou zónou
      String formatWithTimezone(DateTime dt) {
        final duration = dt.timeZoneOffset;
        final hours = duration.inHours.abs().toString().padLeft(2, '0');
        final minutes = (duration.inMinutes.abs() % 60).toString().padLeft(2, '0');
        final sign = duration.isNegative ? '-' : '+';
        return '${dt.toIso8601String()}$sign$hours:$minutes';
      }

      final timeMin = formatWithTimezone(startOfDay);
      final timeMax = formatWithTimezone(endOfDay);

      final url =
          'https://www.googleapis.com/calendar/v3/calendars/$calendarId/events'
          '?key=$apiKey'
          '&timeMin=${Uri.encodeComponent(timeMin)}'
          '&timeMax=${Uri.encodeComponent(timeMax)}'
          '&singleEvents=true'
          '&orderBy=startTime';

      print('🔎 Fetching events: $url');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final events = data['items'] as List<dynamic>;

        final joinedEvents = events.map((event) {
          final summary = event['summary'] ?? '(bez názvu)';
          final start = event['start']['dateTime'] ?? event['start']['date'];
          final time = start != null && start.toString().length >= 16
              ? start.toString().substring(11, 16)
              : '';
          return time.isNotEmpty ? '$time $summary' : summary;
        }).join(' * ');

        setState(() {
          _todayEvents = [
            {'summary': joinedEvents}
          ];
        });
      } else {
        print('❌ Chyba načítání kalendáře: ${response.statusCode}');
        print(response.body);
        setState(() => _todayEvents = []);
      }
    } catch (e) {
      print('❌ Chyba: $e');
      setState(() => _todayEvents = []);
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
      if (lines.length > 8) {
        _calendarId = lines[8].trim();
      }
      if (lines.length > 9) {
        _latin = lines[9].trim().toLowerCase() == 'true';
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
    await FileUtils.writeToFile(_notesController.text, notesFilename);
    await FileUtils.writeToFile(_intentionsController.text, intentionsFilename);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('POZNÁMKY I ÚMYSLY ULOŽENY'),
        backgroundColor: Colors.amber,
        duration: Duration(seconds: 2),
      ),
    );

    if (_sendMailChecked) {
      final shareContent =
          '${_notesController.text}\n\n${_intentionsController.text}';

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
              style: const TextStyle(
                fontSize: 15,
                fontStyle: FontStyle.italic,
                color: Colors.white,
              ),
            ),
          ),
          backgroundColor: Colors.blueGrey[900],
        ),
      ),
      backgroundColor: Colors.black,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildButtonBar(),

          // 🗓️ Události – pouze na home view, malé písmo, vlevo, malé mezery
          if (_currentView == 'home')
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
              child: Text(
                _todayEvents.isNotEmpty && _todayEvents.first['summary'] != null
                    ? _todayEvents.first['summary']!
                    : 'Dnes nejsou žádné události',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.left,
                overflow: TextOverflow.ellipsis,
                maxLines: 3,
              ),
            ),

          // Přepínač jazyků (ponechán dle původního kódu)
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
                  Expanded(child: Container()), // prázdný prostor vlevo
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _switchLanguage(!_latin),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12), // 🔹 poloviční výška
                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        // velikost textu
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: _latin ? const Text('ČESKY') : const Text('LATINSKY'),
                    ),
                  ),
                ],
              ),

            ),

          // 📖 Hlavní obsah
          Expanded(
            child: _buildMainContent(),
          ),
        ],
      ),
    );
  }





  Widget _buildButtonBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 3),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Vypočítat šířku tlačítka (4 tlačítka vedle sebe s mezerami)
          final buttonWidth = (constraints.maxWidth - (3 * 6)) / 4;

          return Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _NavButton('Úmysly', _clickHome, barvaTextuNavTlacitek, buttonWidth),
              _NavButton('Modlitby', () => _setView('prayers'), barvaTextuNavTlacitek, buttonWidth),
              _NavButton('2. Žalm', () => _setView('psalm2'), barvaTextuNavTlacitek, buttonWidth),
              _NavButton('Adoro te', () => _setView('adoro'), barvaTextuNavTlacitek, buttonWidth),
              _NavButton('Trium', () => _setView('trium'), barvaTextuNavTlacitek, buttonWidth),
              _NavButton('Quicumque', () => _setView('quicumque'), barvaTextuNavTlacitek, buttonWidth),
              _NavButton('Maria', () => _setView('litanie'), barvaTextuNavTlacitek, buttonWidth),
              _NavButton('Přede mší', () => _setView('beforeMass'), barvaTextuNavTlacitek, buttonWidth),
              _NavButton('Po mši', () => _setView('afterMass'), barvaTextuNavTlacitek, buttonWidth),
              _NavButton('Při mši', () => _setView('onMass'), barvaTextuNavTlacitek, buttonWidth),
              _NavButton('Poznámky', () => _setView('notes'), barvaTextuFunTlacitek, buttonWidth),
              _NavButton('Úmysly', () => _setView('intentions'), barvaTextuFunTlacitek, buttonWidth),
            ],
          );
        },
      ),
    );
  }

  void _setView(String view) => setState(() => _currentView = view);
  void _clickHome() {
    setState(() => _currentView = 'home');
    _loadTodayEvents();
  }

  Widget _buildMainContent() {
    switch (_currentView) {
      case 'home':
        return _buildHomeView('intentions');
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
        return _buildHomeView('intentions');
    }
  }

// ------------------------
// HOME VIEW – pouze Markdown
// ------------------------
  Widget _buildHomeView(String type) {
    final text = type == 'notes' ? _notesController.text : _intentionsController.text;

    // Zpracuj Markdown a HTML tagy současně
    String processedText = text;

    // Převeď jednoduché color tagy
    // Regex najde <red>text</red>, <blue>text</blue> atd.
    final colorRegex = RegExp(r'<(red|blue|green|orange|purple|pink|yellow|grey)>(.*?)</\1>', dotAll: true);
    final matches = colorRegex.allMatches(processedText);

    // Pokud jsou nějaké barvy, použij custom builder
    if (matches.isNotEmpty) {
      return Container(
        color: Colors.black,
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: _buildColoredMarkdown(text),
        ),
      );
    }

    // Standardní Markdown bez barev
    final formattedText = text.replaceAll('\n', '  \n');

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: MarkdownBody(
          data: formattedText,
          styleSheet: MarkdownStyleSheet(
            p: const TextStyle(color: Colors.white, fontSize: 18, height: 1.4),
            a: const TextStyle(color: linkColor, decoration: TextDecoration.underline),
          ),
          onTapLink: (text, href, title) {
            if (href != null) _launchUrlFromMarkdown(href);
          },
        ),
      ),
    );
  }


// ------------------------
// EDITABLE VIEW – Markdown s toolbar a funkcemi
// ------------------------
  Widget _buildEditableView(String type) {
    final controller = type == 'notes' ? _notesController : _intentionsController;

    // Funkce pro toolbar
    void wrapSelection(String left, String right) {
      final sel = controller.selection;
      final text = controller.text;
      final before = text.substring(0, sel.start);
      final selected = text.substring(sel.start, sel.end);
      final after = text.substring(sel.end);
      final newText = '$before$left$selected$right$after';
      controller.text = newText;
      controller.selection = TextSelection.collapsed(offset: sel.end + left.length + right.length);
    }

    return Column(
      children: [
        // Toolbar pro Markdown
        if (type == 'intentions')
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.format_bold),
                  color: Colors.white,
                  onPressed: () => wrapSelection('**', '**'),
                ),
                IconButton(
                  icon: const Icon(Icons.format_italic),
                  color: Colors.white,
                  onPressed: () => wrapSelection('*', '*'),
                ),
                IconButton(
                  icon: const Icon(Icons.link),
                  color: Colors.white,
                  onPressed: () => wrapSelection('[', '](url)'),
                ),
                IconButton(
                  icon: const Icon(Icons.format_list_bulleted),
                  color: Colors.white,
                  onPressed: () => wrapSelection('- ', ''),
                ),
                // 🎨 Tlačítko pro barvy
                PopupMenuButton<String>(
                  icon: const Icon(Icons.palette, color: Colors.white),
                  color: Colors.grey[800],
                  onSelected: (color) {
                    wrapSelection('<$color>', '</$color>');
                  },
                  itemBuilder: (context) => [
                    _buildColorMenuItem('Červená', 'red', Colors.red),
                    _buildColorMenuItem('Modrá', 'blue', Colors.blue),
                    _buildColorMenuItem('Zelená', 'green', Colors.green),
                    _buildColorMenuItem('Oranžová', 'orange', Colors.orange),
                    _buildColorMenuItem('Fialová', 'purple', Colors.purple),
                    _buildColorMenuItem('Růžová', 'pink', Colors.pinkAccent),
                    _buildColorMenuItem('Žlutá', 'yellow', Colors.yellow),
                    _buildColorMenuItem('Šedá', 'grey', Colors.grey),
                  ],
                ),
              ],
            ),
          ),

        // Editor
        Expanded(
          child: TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(color: Colors.black),
            decoration: const InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
          ),
        ),

        // Dolní tlačítka
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 🔹 NASTAVENÍ
              Expanded(
                child: ElevatedButton(
                  onPressed: _showMoznostiDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: barvaFunkcnichTlacitekVyberuTextuAKurzoru,
                    foregroundColor: barvaTextuNavTlacitek,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('NASTAVENÍ'),
                ),
              ),
              const SizedBox(width: 6),
              // 🔹 TÉMATA
              Expanded(
                child: ElevatedButton(
                  onPressed: _showTemataDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: barvaFunkcnichTlacitekVyberuTextuAKurzoru,
                    foregroundColor: barvaTextuNavTlacitek,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('TÉMATA'),
                ),
              ),
              const SizedBox(width: 6),
              // 🔹 Checkbox ZÁLOHOVAT
              Row(
                children: [
                  Checkbox(
                    value: _sendMailChecked,
                    onChanged: (val) => setState(() => _sendMailChecked = val ?? false),
                    fillColor: const MaterialStatePropertyAll(Colors.white),
                    checkColor: Colors.black,
                    visualDensity: VisualDensity.compact,
                  ),
                  const Text(
                    'ZÁLOHOVAT',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              // 🔹 ULOŽIT
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveFiles,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: barvaFunkcnichTlacitekVyberuTextuAKurzoru,
                    foregroundColor: barvaTextuNavTlacitek,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('ULOŽIT'),
                ),
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
                        // Načti celý obsah
                        final oldContent = await FileUtils.readFromFile(moznostiFilename);
                        final oldLines = oldContent.split('\n');

                        // Ujisti se, že má soubor aspoň 11 řádků
                        while (oldLines.length < 11) {
                          oldLines.add('');
                        }

                        // Ulož 7 mott se sanitizací
                        for (int i = 0; i < 7; i++) {
                          String clean = controllers[i].text.replaceAll(RegExp(r'[\n\r\t]'), '');
                          if (clean.length > 200) clean = clean.substring(0, 200);
                          oldLines[i] = clean;
                        }

                        // Znovu slož soubor
                        final newContent = oldLines.join('\n');

                        // Zapiš zpět
                        await FileUtils.writeToFile(newContent, moznostiFilename);

                        // Obnov motto dne
                        await _loadDailyMotto();

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('TÉMATA ULOŽENA'),
                              backgroundColor: Colors.amber,
                            ),
                          );
                        }
                      },

                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            barvaFunkcnichTlacitekVyberuTextuAKurzoru,
                        foregroundColor: barvaTextuNavTlacitek,
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
                        // Načti celý obsah
                        final oldContent = await FileUtils.readFromFile(moznostiFilename);
                        final oldLines = oldContent.split('\n');

                        // Ujisti se, že má soubor aspoň 11 řádků
                        while (oldLines.length < 10) {
                          oldLines.add('');
                        }

                        // Ulož 7 mott se sanitizací
                        for (int i = 0; i < 7; i++) {
                          String clean = controllers[i].text.replaceAll(RegExp(r'[\n\r\t]'), '');
                          if (clean.length > 200) clean = clean.substring(0, 200);
                          oldLines[i] = clean;
                        }

                        // Znovu slož soubor
                        final newContent = oldLines.join('\n');

                        // Zapiš zpět
                        await FileUtils.writeToFile(newContent, moznostiFilename);

                        // Obnov motto dne
                        await _loadDailyMotto();

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('TÉMATA ULOŽENA'),
                              backgroundColor: Colors.amber,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            barvaFunkcnichTlacitekVyberuTextuAKurzoru,
                        foregroundColor: barvaTextuNavTlacitek,
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

    // zajistit, aby bylo alespoň 11 řádků
    while (lines.length < 11) lines.add('');

    // Předvyplněné hodnoty
    String selectedSize = (lines.length > 7 && lines[7].trim().isNotEmpty) ? lines[7].trim() : '1.0';
    String calendarId = (lines.length > 8) ? lines[8].trim() : '';
    bool latinFlag = (lines.length > 9) ? lines[9].trim().toLowerCase() == 'true' : false;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        String tempSize = selectedSize;
        String tempCalendarId = calendarId;
        bool tempLatin = latinFlag;

        return Dialog(
          backgroundColor: Colors.grey[900],
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('NASTAVENÍ',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  // 1️⃣ Velikost textu
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Velikost textu',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 4),
                      StatefulBuilder(
                        builder: (context, setStateDropdown) {
                          return DropdownButton<String>(
                            value: tempSize,
                            dropdownColor: Colors.grey[800],
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(value: '0.5', child: Text('0.5x (Velmi malá)', style: TextStyle(color: Colors.white))),
                              DropdownMenuItem(value: '0.75', child: Text('0.75x (Malá)', style: TextStyle(color: Colors.white))),
                              DropdownMenuItem(value: '1.0', child: Text('1.0x (Normální)', style: TextStyle(color: Colors.white))),
                              DropdownMenuItem(value: '1.25', child: Text('1.25x (Větší)', style: TextStyle(color: Colors.white))),
                              DropdownMenuItem(value: '1.5', child: Text('1.5x (Velká)', style: TextStyle(color: Colors.white))),
                              DropdownMenuItem(value: '2.0', child: Text('2.0x (Velmi velká)', style: TextStyle(color: Colors.white))),
                              DropdownMenuItem(value: '3.0', child: Text('3.0x (Obrovská)', style: TextStyle(color: Colors.white))),
                            ],
                            onChanged: (value) {
                              if (value != null) setStateDropdown(() => tempSize = value);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 2️⃣ Defaultní jazyk (latina)
                  Row(
                    children: [
                      const Expanded(child: Text('Použít latinu jako výchozí:', style: TextStyle(color: Colors.white70))),
                      StatefulBuilder(
                        builder: (context, setStateCheck) {
                          return Checkbox(
                            value: tempLatin,
                            onChanged: (val) => setStateCheck(() => tempLatin = val ?? false),
                            fillColor: MaterialStateProperty.all(Colors.white),
                            checkColor: Colors.black,
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 4️⃣ API Key
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Google kalendář ID - NESAHAT!!!',
                      labelStyle: TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white24,
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(color: Colors.white),
                    controller: TextEditingController(text: tempCalendarId),
                    onChanged: (val) => tempCalendarId = val,
                  ),

                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('ZRUŠIT', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          // upravit řádky 8–10
                          while (lines.length < 10) lines.add('');
                          lines[7] = tempSize;
                          lines[8] = tempCalendarId;
                          lines[9] = tempLatin.toString();


                          await FileUtils.writeToFile(lines.join('\n'), moznostiFilename);

                          setState(() {
                            _scaleFactor = double.tryParse(tempSize) ?? 1.0;
                            _baseScaleFactor = _scaleFactor;
                            _latin = tempLatin;
                          });

                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('NASTAVENÍ ULOŽENO'),
                              backgroundColor: Colors.amber,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: barvaFunkcnichTlacitekVyberuTextuAKurzoru,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('ULOŽIT', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
    _notesController.dispose();
    _intentionsController.dispose();
    super.dispose();
  }

  void _launchUrl(String href) {}
}

Widget _NavButton(String label, VoidCallback onPressed, Color textColor, double width) {
  return SizedBox(
    width: width,
    height: 42, // Fixní výška tlačítka
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueGrey,
        foregroundColor: textColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label.toUpperCase(),
          maxLines: 1,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
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

    // Nastavit barvu status baru
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.black, // barva pod notchem / status barem
        statusBarIconBrightness: Brightness.light, // ikony bílé
      ),
    );
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
          return '[opusdei.cz](https://opusdei.cz)  [escriva.org/cs](https://escriva.org/cs)  [Studio Vox](https://studiovox.cz)\n'
              '**Petr**\n'
              '*Pavel*\n'
              '<red>Simon</red>\n'
              '<purple>Matous</purple>\n'
              '<yellow>Jan</yellow>\n'
              '- Filip\n'
              '- Natanael\n'
              'Jakub';
        }
        if (fileName == 'notes.txt') {
          return 'Zpytování svědomí';
        }
        if (fileName == 'moznosti.txt') {
            return 'Sancta Maria, Mater misericordiae, succurre animabus in purgatorio, den stráže, otec, bratři\n'
                'Sancti Angeli Custodes nostri, deféndite nos, kolegové\n'
                'Sancte Ioseph, ora pro nobis, rodina, rodiče\n'
                'Iesu, in te confido, povolání, věrnost\n'
                'Per crucem et passionem tuam, Domine, libera nos, kamarádi\n'
                'Cor Mariae dulcissimum, iter para tutum, apoštoláty\n'
                'Gloria Patri, et Filio, et Spiritui Sancto, díkůvzdání, papež\n'
                '1.0\n'      // řádek 8: velikost písma
                'k9grn9pcub347543afce5uiv50@group.calendar.google.com\n'         // řádek 9: calendar ID (prázdné)
                'false';     // řádek 10: latina (false)
        }
        return '';
      }

      return await file.readAsString();
    } catch (e) {
      if (fileName == 'intentions.txt') {
        return '[opusdei.cz](https://opusdei.cz)  [escriva.org/cs](https://escriva.org/cs)  [Studio Vox](https://studiovox.cz)\n'
            '**Petr**\n'
            '*Pavel*\n'
            '<red>Simon</red>\n'
            '<purple>Matous</purple>\n'
            '<yellow>Jan</yellow>\n'
            '- Filip\n'
            '- Natanael\n'
            'Jakub';
      }
      if (fileName == 'notes.txt') {
        return 'Zpytování svědomí';
      }
      if (fileName == 'moznosti.txt') {
        return 'Sancta Maria, Mater misericordiae, succurre animabus in purgatorio, den stráže, otec, bratři\n'
            'Sancti Angeli Custodes nostri, deféndite nos, kolegové\n'
            'Sancte Ioseph, ora pro nobis, rodina, rodiče\n'
            'Iesu, in te confido, povolání, věrnost\n'
            'Per crucem et passionem tuam, Domine, libera nos, kamarádi\n'
            'Cor Mariae dulcissimum, iter para tutum, apoštoláty\n'
            'Gloria Patri, et Filio, et Spiritui Sancto, díkůvzdání, papež\n'
            '1.0\n'      // řádek 8: velikost písma
            'k9grn9pcub347543afce5uiv50@group.calendar.google.com\n'         // řádek 9: calendar ID (prázdné)
            'false';     //
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