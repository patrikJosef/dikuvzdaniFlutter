import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import 'dart:async';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;
import 'package:url_launcher/url_launcher.dart';

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

  Widget _colorPicker(TextEditingController controller) {
    return DropdownButton<String>(
      dropdownColor: Colors.grey[900],
      hint: const Text('Barva', style: TextStyle(color: Colors.white)),
      items: <String>['red', 'blue', 'green', 'orange', 'purple', 'black']
          .map((color) => DropdownMenuItem<String>(
        value: color,
        child: Text(
          color,
          style: TextStyle(color: _parseColor(color)),
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

  Color _parseColor(String colorStr) {
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
    final url = 'https://'; // nebo otevřít dialog

    final link = '<a href="$url">$selectedText</a>';
    final before = controller.selection.textBefore(controller.text);
    final after = controller.selection.textAfter(controller.text);

    controller.text = '$before$link$after';
    controller.selection = TextSelection.collapsed(offset: (before + link).length);
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
      _sendEmail();
      setState(() => _sendMailChecked = false);
    }
  }

  void _sendEmail() {
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final subject = 'Záloha Díkůvzdání $dateStr';
    final body = '${_examinationController.text}${_peopleListController.text}';

    print('Email: $subject\n$body');
  }

  @override
  Widget build(BuildContext context) {
    bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          if (!isKeyboardVisible) _buildButtonBar(),
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
    return GestureDetector(
      onScaleStart: (details) {
        _baseScaleFactor = _scaleFactor;
      },
      onScaleUpdate: (details) {
        setState(() {
          _scaleFactor = (_baseScaleFactor * details.scale).clamp(0.5, 3.0);
        });
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: HtmlText(
          '${_taskListController.text}\n\n${_peopleListController.text}',
          scaleFactor: _scaleFactor,
        ),
      ),
    );
  }

  Widget _buildHtmlToolbar(TextEditingController controller) {
    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _htmlButton('B', () => _wrapSelectionWith(controller, '<b>', '</b>')),
          _htmlButton('I', () => _wrapSelectionWith(controller, '<i>', '</i>')),
          _htmlButton('🔗', () => _insertLink(controller)),
          _colorPicker(controller),
          const Spacer(),
          const Text('HTML nástroje', style: TextStyle(color: Colors.white70)),
        ],
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


  Widget _buildTextView(String viewId) {
    return FutureBuilder<String>(
      future: rootBundle.loadString('assets/texts/$viewId.txt'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        return GestureDetector(
          onScaleUpdate: (details) {
            setState(() {
              _scaleFactor = (_baseScaleFactor * details.scale).clamp(0.5, 3.0);
            });
          },
          onScaleEnd: (details) {
            _baseScaleFactor = _scaleFactor;
          },
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: HtmlText(
                snapshot.data ?? '',
                scaleFactor: _scaleFactor,
              ),
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

  const HtmlText(this.htmlContent, {required this.scaleFactor});

  @override
  Widget build(BuildContext context) {
    return _parseHtml(htmlContent);
  }

  Widget _parseHtml(String html) {
    final document = html_parser.parse(html);
    return _buildWidgetTree(document.body!);
  }

  Widget _buildWidgetTree(html_dom.Element element) {
    final children = <Widget>[];

    for (var node in element.nodes) {
      if (node.nodeType == 3) {
        final text = node.text?.trim();
        if (text != null && text.isNotEmpty) {
          children.add(
            Text(text, style: TextStyle(color: Colors.white, fontSize: 19 * scaleFactor)),
          );
        }
      } else if (node is html_dom.Element) {
        children.add(_buildElement(node));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildElement(html_dom.Element element) {
    switch (element.localName) {
      case 'a':
        final href = element.attributes['href'] ?? '';
        return GestureDetector(
          onTap: () => _launchUrl(href),
          child: Text(
            element.text,
            style: TextStyle(
              color: Colors.lightBlueAccent,
              fontSize: 19 * scaleFactor,
              decoration: TextDecoration.underline,
            ),
          ),
        );

      case 'b':
      case 'strong':
        return Text(
          element.text,
          style: TextStyle(
            color: Colors.white,
            fontSize: 19 * scaleFactor,
            fontWeight: FontWeight.bold,
          ),
        );

      case 'i':
      case 'em':
        return Text(
          element.text,
          style: TextStyle(
            color: Colors.white,
            fontSize: 19 * scaleFactor,
            fontStyle: FontStyle.italic,
          ),
        );

      case 'br':
        return const SizedBox(height: 8);

      case 'font':
        final colorAttr = element.attributes['color'] ?? 'white';
        final color = _parseColor(colorAttr);
        return Text(
          element.text,
          style: TextStyle(
            color: color,
            fontSize: 19 * scaleFactor,
          ),
        );

      case 'p':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            element.text,
            style: TextStyle(
              color: Colors.white,
              fontSize: 19 * scaleFactor,
            ),
          ),
        );

      default:
        return Text(
          element.text,
          style: TextStyle(
            color: Colors.white,
            fontSize: 19 * scaleFactor,
          ),
        );
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(_normalizeUrl(url));
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Nepodařilo se otevřít odkaz: $uri');
    }
  }

  String _normalizeUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    return 'https://$url';
  }

  Color _parseColor(String colorStr) {
    String cleanColor = colorStr.replaceFirst('#', '');
    final colors = {
      'red': Colors.red,
      'blue': Colors.blue,
      'green': Colors.green,
      'white': Colors.white,
      'black': Colors.black,
      'yellow': Colors.yellow,
      'orange': Colors.orange,
      'purple': Colors.purple,
      'pink': Colors.pink,
      'grey': Colors.grey,
    };

    if (colors.containsKey(cleanColor.toLowerCase())) {
      return colors[cleanColor.toLowerCase()]!;
    }

    if (cleanColor.length == 6) {
      try {
        return Color(int.parse('FF$cleanColor', radix: 16));
      } catch (_) {
        return Colors.white;
      }
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
          return 'escriva.org/cs &nbsp;&nbsp; <a href="opusdei.cz">Opus Dei</a>    opusdei.cz &nbsp;&nbsp; catholica.cz<br/><br/>kalendar.katolik.cz &nbsp;&nbsp; studiovox.cz\nCor Mariae dulcissimum, iter para tutum';
        }
        return '';
      }

      return await file.readAsString();
    } catch (e) {
      if (fileName == peopleListFilename) {
        return 'escriva.org/cs &nbsp;&nbsp; <a href="opusdei.cz">Opus Dei</a>   opusdei.cz &nbsp;&nbsp; catholica.cz<br/><br/>kalendar.katolik.cz &nbsp;&nbsp; studiovox.cz\nCor Mariae dulcissimum, iter para tutum';
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