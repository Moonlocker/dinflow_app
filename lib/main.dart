import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Necessário para datas/meses em português (DateFormat 'pt_BR').
  await initializeDateFormatting('pt_BR');

  // Mesmo projeto Supabase usado pelo webapp (auth, banco, storage).
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );

  runApp(const DinFlowApp());
}
