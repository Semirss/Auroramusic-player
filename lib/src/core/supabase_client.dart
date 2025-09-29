import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  static const String _supabaseUrl = 'https://dpxszyqgfylbihhvgjnc.supabase.co';
  static const String _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRweHN6eXFnZnlsYmloaHZnam5jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTkwNjA4MjAsImV4cCI6MjA3NDYzNjgyMH0.8irNMejJ_mj4SSidOcS-ArpETg9HgNnJ6XuBSZIwsNE';

  Future<void> initialize() async {
    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
    );
    print('Supabase initialized successfully');
  }

  SupabaseClient get client => Supabase.instance.client;
}