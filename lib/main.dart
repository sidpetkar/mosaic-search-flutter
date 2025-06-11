import 'package:flutter/material.dart';
import 'package:mosaic_search/app.dart'; // Import the new App widget
import 'package:workmanager/workmanager.dart';
import 'package:mosaic_search/core/background_services/background_indexing_service.dart';
// import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart'; // We will remove the call that uses this directly for now
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // For sqfliteFfiInit and databaseFactoryFfi
import 'package:sqflite/sqflite.dart'; // Add this for Sqflite.setDebugModeOn and databaseFactory

// This must be a top-level function (not a class method)
// and must be annotated with @pragma('vm:entry-point')
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Initialize sqflite FFI for this background isolate
    // It's crucial that this is done in each isolate that uses the database.
    // Also, ensure Flutter bindings are initialized if any plugin used by sqflite FFI requires it.
    // WidgetsFlutterBinding.ensureInitialized(); // May or may not be needed, let's try without first.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Optionally, enable debug logging for the background isolate too
    // await Sqflite.setDebugModeOn(true); // Can be noisy, enable if needed for BG troubleshooting

    print("[Workmanager] Native called background task: $task with FFI initialized.");

    if (task == BackgroundIndexingService.imageProcessingTask) {
      if (inputData != null && inputData.containsKey(BackgroundIndexingService.folderIdKey)) {
        final int folderId = inputData[BackgroundIndexingService.folderIdKey] as int;
        print("[Workmanager] Processing folder ID: $folderId");
        final indexingService = BackgroundIndexingService();
        try {
          bool success = await indexingService.processFolder(folderId);
          return Future.value(success);
        } catch (e, stacktrace) {
          print("[Workmanager] Error processing folder ID $folderId: $e");
          print(stacktrace);
          return Future.value(false); // Indicate failure
        }
      } else {
        print("[Workmanager] Error: Missing folderId for task $task");
        return Future.value(false);
      }
    } else {
      print("[Workmanager] Unknown task: $task");
      return Future.value(false); // Or true if you want to acknowledge other tasks
    }
  });
}

void main() async { // main needs to be async for Workmanager initialization
  // It's good practice to ensure Flutter bindings are initialized, especially
  // if you're doing anything before runApp.
  WidgetsFlutterBinding.ensureInitialized();

  // Enable Sqflite FFI debug logging
  await Sqflite.setDebugModeOn(true);

  // Initialize sqflite_common_ffi for FTS5 support
  sqfliteFfiInit();
  // Change the default factory for sqflite to use the FFI implementation.
  databaseFactory = databaseFactoryFfi;

  // The call to applyWorkaroundToOpenSqlite3OnOldAndroidVersions(); is removed.
  // sqfliteFfiInit() should handle loading the library provided by sqlite3_flutter_libs.

  // Initialize Workmanager
  await Workmanager().initialize(
    callbackDispatcher, // The top-level function to be called when a task is triggered
    isInDebugMode: true, // Set to false in release mode. Helps with logging.
  );
  
  // Example: Register a one-off task (for testing, actual registration will be elsewhere)
  /*
  Workmanager().registerOneOffTask(
    "1", 
    BackgroundIndexingService.imageProcessingTask,
    inputData: {BackgroundIndexingService.folderIdKey: 123}, // example folderId
    constraints: Constraints(
        networkType: NetworkType.connected, // Only run when connected to a network
        // requiresStorageNotLow: true,
    )
  );
  */

  runApp(const MosaicApp()); // Use the new App widget
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
