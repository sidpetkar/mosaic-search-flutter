import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mosaic_search/core/database/database_helper.dart';
import 'package:mosaic_search/core/permissions/permission_service.dart';
import 'package:mosaic_search/features/folder_management/bloc/folder_bloc.dart';
import 'package:mosaic_search/features/home/presentation/screens/home_screen.dart';
import 'package:mosaic_search/features/search/bloc/search_bloc.dart';
import 'package:mosaic_search/core/folder_sync_service.dart';
import 'package:mosaic_search/features/folder_view/bloc/folder_view_bloc.dart';
import 'package:flutter_swipe_action_cell/flutter_swipe_action_cell.dart';

class MosaicApp extends StatelessWidget {
  const MosaicApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize services that FolderBloc depends on.
    // These could also be provided by a more sophisticated DI solution if the app grows.
    final DatabaseHelper databaseHelper = DatabaseHelper.instance;
    final PermissionService permissionService = PermissionService();
    final FolderSyncService folderSyncService = FolderSyncService();

    return MultiBlocProvider(
      providers: [
        BlocProvider<FolderBloc>(
          create: (context) => FolderBloc(
            databaseHelper: databaseHelper,
            permissionService: permissionService,
            folderSyncService: folderSyncService,
          ),
        ),
        BlocProvider<SearchBloc>(
          create: (context) => SearchBloc(
            databaseHelper: databaseHelper,
          ),
        ),
        BlocProvider<FolderViewBloc>(
          create: (context) => FolderViewBloc(
            databaseHelper: databaseHelper,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Mosaic Search',
        navigatorObservers: [SwipeActionNavigatorObserver()],
        theme: ThemeData(
          // Let's use a seed color for Material 3 theming
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurpleAccent),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF8F8F8),
          // Apply DM Sans to the default text theme
          textTheme: GoogleFonts.dmSansTextTheme(
            Theme.of(context).textTheme, // Use the default text theme as a base
          ),
          // Apply DM Sans to the primary text theme as well for full coverage
          primaryTextTheme: GoogleFonts.dmSansTextTheme(
            Theme.of(context).primaryTextTheme,
          ),
          // Optional: Customize AppBar theme or other global theme properties
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.deepPurpleAccent[700],
            foregroundColor: Colors.white, // For title and icons
          )
        ),
        home: const HomeScreen(), // Set HomeScreen as the initial route
      ),
    );
  }
}

// The placeholder MyHomePage is no longer needed as HomeScreen is the new home.
// class MyHomePage extends StatelessWidget { ... } 