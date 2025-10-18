import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import 'dart:async';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;




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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          _buildButtonBar(),
          Expanded(
            child: _buildMainContent(),
          ),
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
        physics: NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2, // čtvercové tlačítka
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
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SelectableText(
          '${_taskListController.text}\n\n${_peopleListController.text}',
          style: TextStyle(
            color: Colors.white,
            fontSize: 19 * _scaleFactor,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildEditableView(String type) {
    final controller = type == 'examination'
        ? _examinationController
        : _peopleListController;

    return Column(
      children: [
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
      padding: EdgeInsets.zero, // žádné extra mezery
      minimumSize: const Size(0, 48), // poloviční výška tlačítka
    ),
    child: Center(
      child: FittedBox(
        fit: BoxFit.scaleDown, // automaticky zmenší text
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
        children.add(_buildElement(node as html_dom.Element));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildElement(html_dom.Element element) {
    switch (element.localName) {
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

  Color _parseColor(String colorStr) {
    // Odstranit # pokud je na začátku
    String cleanColor = colorStr.replaceFirst('#', '');

    // Pojmenované barvy
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

    // Pokud je pojmenovaná barva
    if (colors.containsKey(cleanColor.toLowerCase())) {
      return colors[cleanColor.toLowerCase()]!;
    }

    // Pokud je hex kód
    if (cleanColor.length == 6) {
      try {
        return Color(int.parse('FF$cleanColor', radix: 16));
      } catch (e) {
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
          return '<font color="red" size="10pt"> escriva.org/cs      &nbsp;&nbsp; opusdei.cz    &nbsp;&nbsp;  catholica.cz &nbsp;&nbsp; <br/><br/>kalendar.katolik.cz &nbsp;&nbsp; studiovox.cz</font>\nCor Mariae dulcissimum, iter para tutum';
        }
        return '';
      }

      return await file.readAsString();
    } catch (e) {
      if (fileName == peopleListFilename) {
        return '<font color="red" size="10pt"> escriva.org/cs      &nbsp;&nbsp; opusdei.cz    &nbsp;&nbsp;  catholica.cz &nbsp;&nbsp; <br/><br/>kalendar.katolik.cz &nbsp;&nbsp; studiovox.cz</font>\nCor Mariae dulcissimum, iter para tutum';
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