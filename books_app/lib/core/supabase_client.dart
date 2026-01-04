import 'package:supabase_flutter/supabase_flutter.dart';

// Masukkan URL dan Anon Key dari Dashboard Supabase lu di sini
const String supabaseUrl = 'https://kjioqdqmtjdzrgchdkmq.supabase.co';
const String supabaseAnonKey = 'sb_publishable_CHE9O5Qc78cVSvlMOx6w8g_lRYdgkJB';

// Ini variabel global yang bakal dipanggil di seluruh aplikasi (Login, Admin, User)
// Jadi nanti import-nya ke file ini, bukan ke main.dart lagi.
final supabase = Supabase.instance.client;