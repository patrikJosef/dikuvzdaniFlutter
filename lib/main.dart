import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import 'dart:async';
import 'package:html/parser.dart' as html_parser;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import 'package:html/dom.dart' as dom;

void main() {
  runApp(const MyApp());
}

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
  final TextEditingController _examinationController = TextEditingController();
  final TextEditingController _peopleListController = TextEditingController();

  String _currentView = 'home';
  double _scaleFactor = 1.0;
  double _baseScaleFactor = 1.0;
  bool _sendMailChecked = false;

  static const String taskListFilename = 'taskList.txt';
  static const String examinationFilename = 'examination.txt';
  static const String peopleListFilename = 'peopleList.txt';

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final taskList = await FileUtils.readFromFile(taskListFilename);
    final examination = await FileUtils.readFromFile(examinationFilename);
    final peopleList = await FileUtils.readFromFile(peopleListFilename);

    setState(() {
      _taskListController.text = taskList;
      _examinationController.text = examination;
      _peopleListController.text = peopleList;
    });
  }

  Future<void> _saveFiles() async {
    await FileUtils.writeToFile(_taskListController.text, taskListFilename);
    await FileUtils.writeToFile(_examinationController.text, examinationFilename);
    await FileUtils.writeToFile(_peopleListController.text, peopleListFilename);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Poznámky i úmysly uloženy'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );

    if (_sendMailChecked) {
      setState(() => _sendMailChecked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
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
      padding: const EdgeInsets.all(12.0),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2,
        children: [
          _NavButton('Přehled', _clickHome),
          _NavButton('Modlitby', () => _setView('prayers')),
          _NavButton('2. Žalm', () => _setView('psalm2')),
          _NavButton('Adoro te', () => _setView('adoro')),
          _NavButton('Trium', () => _setView('trium')),
          _NavButton('Quicum', () => _setView('quicumque')),
          _NavButton('Litanie', () => _setView('triumLat')),
          _NavButton('Před mší', () => _setView('beforeMass')),
          _NavButton('Po mši', () => _setView('afterMass')),
          _NavButton('Při mši', () => _setView('onMass')),
          _NavButton('Zpytování', () => _setView('examination')),
          _NavButton('Lidé', () => _setView('peopleList')),
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
      case 'examination':
        return _buildEditableView('examination');
      case 'peopleList':
        return _buildEditableView('peopleList');
      case 'psalm2':
      case 'adoro':
      case 'trium':
      case 'quicumque':
      case 'prayers':
      case 'beforeMass':
      case 'afterMass':
      case 'onMass':
      case 'triumLat':
        return _buildTextView(_currentView);
      default:
        return _buildHomeView();
    }
  }

  Widget _buildHomeView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: HtmlText(
        '${_taskListController.text}\n\n${_peopleListController.text}',
        scaleFactor: _scaleFactor,
      ),
    );
  }

  Widget _buildEditableView(String type) {
    final controller = type == 'examination'
        ? _examinationController
        : _peopleListController;

    return Column(
      children: [
        if (type == 'peopleList') _buildHtmlToolbar(controller),
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
              ),
              const Text('Zálohovat', style: TextStyle(color: Colors.white)),
              const Spacer(),
              ElevatedButton(
                onPressed: _saveFiles,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Uložit'),
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
    _examinationController.dispose();
    _peopleListController.dispose();
    super.dispose();
  }
}

Widget _NavButton(String label, VoidCallback onPressed) {
  return ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
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

    return RichText(
      text: textSpan,
      softWrap: true,
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
            color: Colors.lightBlueAccent,
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

        print('FONT element: color=$colorAttr, text=$text, parsed color=$color');

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

  List<TextSpan> _getChildren(dom.Element element) {
    final List<TextSpan> children = [];

    for (var node in element.nodes) {
      final span = _parseNode(node);
      if (span != null) {
        children.add(span);
      }
    }

    return children;
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
        if (fileName == peopleListFilename) {
          return '<a href="https://escriva.org/cs">escriva.org/cs</a> &nbsp;&nbsp; <a href="https://opusdei.cz">Opus Dei</a> &nbsp;&nbsp; <a href="https://catholica.cz">catholica.cz</a><br/><br/><a href="https://kalendar.katolik.cz">kalendar.katolik.cz</a> &nbsp;&nbsp; <a href="https://studiovox.cz">studiovox.cz</a>\n<font color="red">Cor Mariae dulcissimum, iter para tutum</font>';
        }
        return '';
      }

      return await file.readAsString();
    } catch (e) {
      if (fileName == peopleListFilename) {
        return '<a href="https://escriva.org/cs">escriva.org/cs</a> &nbsp;&nbsp; <a href="https://opusdei.cz">Opus Dei</a> &nbsp;&nbsp; <a href="https://catholica.cz">catholica.cz</a><br/><br/><a href="https://kalendar.katolik.cz">kalendar.katolik.cz</a> &nbsp;&nbsp; <a href="https://studiovox.cz">studiovox.cz</a>\n<font color="red">Cor Mariae dulcissimum, iter para tutum</font>';
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

  static const String peopleListFilename = 'peopleList.txt';
}