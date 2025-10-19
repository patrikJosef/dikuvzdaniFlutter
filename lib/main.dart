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


void main() {
  runApp(const MyApp());
}

// 🔵 Sdílená barva pro odkazy
const linkColor = Colors.lightBlueAccent;

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Modlitební Aplikace',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
      ),
      home: const MainActivity(),
      locale: const Locale('cs'), // čeština
      supportedLocales: const [
        Locale('cs'), // čeština
        Locale('en'), // angličtina, pokud chceš fallback
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

  static const String taskListFilename = 'taskList.txt';
  static const String notesFilename = 'notes.txt';
  static const String intentionsFilename = 'intentions.txt';

  @override
  void initState() {
    super.initState();
    _loadFiles();
    _loadDailyMotto();
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

  Future<void> _loadDailyMotto() async {
    try {
      final content = await rootBundle.loadString('assets/moznosti.txt');
      final lines = content.split('\n').where((line) => line.trim().isNotEmpty).toList();
      final dayOfWeek = DateTime.now().weekday; // 1=Monday, 7=Sunday

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
        backgroundColor: Colors.blueGrey,
        duration: Duration(seconds: 2),
      ),
    );

    if (_sendMailChecked) {
      // Spojíme obsah všech tří souborů pro sdílení
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
                  style: TextStyle(fontSize: 15, fontStyle: FontStyle.italic)
              ),
            )
        ),
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          _buildButtonBar(),
          Expanded(child: _buildMainContent()),
        ],
      ),
    );
  }

  Widget _buildButtonBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 8),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6, // ⬅️ menší mezery
        crossAxisSpacing: 6, // ⬅️ menší mezery
        childAspectRatio: 2.67,
        children: [
          _NavButton('Úmysly', _clickHome, barvaTextuNavTlacitek),
          _NavButton('Modlitby', () => _setView('prayers'),barvaTextuNavTlacitek),
          _NavButton('2. Žalm', () => _setView('psalm2'),barvaTextuNavTlacitek),
          _NavButton('Adoro te', () => _setView('adoro'),barvaTextuNavTlacitek),
          _NavButton('Trium', () => _setView('trium'),barvaTextuNavTlacitek),
          _NavButton('Quicumque', () => _setView('quicumque'),barvaTextuNavTlacitek),
          _NavButton('Litanie', () => _setView('litanie'),barvaTextuNavTlacitek),
          _NavButton('Přede mší', () => _setView('beforeMass'),barvaTextuNavTlacitek),
          _NavButton('Po mši', () => _setView('afterMass'),barvaTextuNavTlacitek),
          _NavButton('Při mši', () => _setView('onMass'),barvaTextuNavTlacitek),
          _NavButton('Poznámky', () => _setView('notes'),barvaTextuFunTlacitek),
          _NavButton('Úmysly', () => _setView('intentions'),barvaTextuFunTlacitek),
        ],
      ),
    );
  }

  void _setView(String view) {
    setState(() => _currentView = view);
  }

  void _clickHome() {
    setState(() => _currentView = 'home');
  }

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
    return GestureDetector(
      onScaleStart: (details) {
        _baseScaleFactor = _scaleFactor;
      },
      onScaleUpdate: (details) {
        setState(() {
          _scaleFactor = (_baseScaleFactor * details.scale).clamp(0.5, 3.0);
        });
      },
      onScaleEnd: (details) {
        _baseScaleFactor = _scaleFactor;
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: HtmlText(
          '${_taskListController.text}\n\n${_intentionsController.text}',
          scaleFactor: _scaleFactor,
        ),
      ),
    );
  }

  Widget _buildEditableView(String type) {
    final controller = type == 'notes'
        ? _notesController
        : _intentionsController;

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
              Checkbox(
                value: _sendMailChecked,
                onChanged: (val) {
                  setState(() => _sendMailChecked = val ?? false);
                },
                fillColor: WidgetStatePropertyAll(Colors.white),
                checkColor: Colors.black,
              ),
              const Text('ZÁLOHOVAT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const Spacer(),
              ElevatedButton(
                onPressed: _saveFiles,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: barvaTextuFunTlacitek,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('ULOŽIT',
                  style: TextStyle(
                    fontWeight: FontWeight.bold, // tučný text
                  ),),


              ),





            ],
          ),
        ),
      ],
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
          const Text('HTML', style: TextStyle(color: Colors.white70, fontSize: 12)),
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
    return DropdownButton<String>(
      dropdownColor: Colors.grey[900],
      hint: const Text('Barva', style: TextStyle(color: Colors.white, fontSize: 12)),
      items: <String>['red', 'blue', 'green', 'orange', 'purple', 'black']
          .map((color) => DropdownMenuItem<String>(
        value: color,
        child: Text(
          color,
          style: TextStyle(color: _parseColorForToolbar(color)),
        ),
      ))
          .toList(),
      onChanged: (String? selectedColor) {
        if (selectedColor != null) {
          _wrapSelectionWith(controller, '<font color="$selectedColor">', '</font>');
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
      case 'black':
        return Colors.black;
      default:
        return Colors.white;
    }
  }

  void _wrapSelectionWith(TextEditingController controller, String startTag, String endTag) {
    final text = controller.text;
    final selection = controller.selection;

    if (!selection.isValid || selection.isCollapsed) return;

    final selectedText = selection.textInside(text);
    final before = selection.textBefore(text);
    final after = selection.textAfter(text);

    final newText = '$before$startTag$selectedText$endTag$after';

    controller.text = newText;
    controller.selection = TextSelection.collapsed(offset: (before + startTag + selectedText + endTag).length);
  }

  void _insertLink(TextEditingController controller) {
    final selection = controller.selection;
    final selectedText = controller.selection.textInside(controller.text);
    final url = 'https://example.com';

    final link = '<a href="$url">$selectedText</a>';
    final before = controller.selection.textBefore(controller.text);
    final after = controller.selection.textAfter(controller.text);

    controller.text = '$before$link$after';
    controller.selection = TextSelection.collapsed(offset: (before + link).length);
  }

  Widget _buildTextView(String viewId) {
    return FutureBuilder<String>(
      future: rootBundle.loadString('assets/texts/$viewId.txt'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: HtmlText(
              snapshot.data ?? '',
              scaleFactor: _scaleFactor,
            ),
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
      backgroundColor: Colors.blueGrey, // ⚪ bílé tlačítko
      foregroundColor: textColor, // ⚫ černý text
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
          recognizer: TapGestureRecognizer()
            ..onTap = () => _launchUrl(href),
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
      'black': Colors.black,
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

class FileUtils {
  static Future<String> readFromFile(String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');

      if (!await file.exists()) {
        if (fileName == intentionsFilename) {
          return '<a href="https://escriva.org/cs">escriva.org/cs</a> &nbsp;&nbsp; <a href="https://opusdei.cz">Opus Dei</a> &nbsp;&nbsp; <a href="https://catholica.cz">catholica.cz</a><br/><br/><a href="https://kalendar.katolik.cz">kalendar.katolik.cz</a> &nbsp;&nbsp; <a href="https://studiovox.cz">studiovox.cz</a>\n<font color="red">Cor Mariae dulcissimum, iter para tutum</font>';
        }
        return '';
      }

      return await file.readAsString();
    } catch (e) {
      if (fileName == intentionsFilename) {
        return '<a href="https://escriva.org/cs">escriva.org/cs</a> &nbsp;&nbsp; <a href="https://opusdei.cz">Opus Dei</a> &nbsp;&nbsp; <a href="https://catholica.cz">catholica.cz</a><br/><br/><a href="https://kalendar.cz"></a>';

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

  static const String intentionsFilename = 'intentions.txt';
}