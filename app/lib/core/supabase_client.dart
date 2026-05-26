import 'package:supabase_flutter/supabase_flutter.dart';

/// Single global instance helper to access the Supabase client
SupabaseClient get supabaseClient => Supabase.instance.client;
