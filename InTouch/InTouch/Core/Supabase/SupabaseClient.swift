import Foundation
import Supabase

// MARK: - Supabase client singleton
// Replace the placeholder values below with your actual project URL and anon key
// from: Supabase Dashboard → Project Settings → API

let supabase = SupabaseClient(
    supabaseURL: URL(string: "YOUR_SUPABASE_URL")!,
    supabaseKey: "YOUR_SUPABASE_ANON_KEY"
)
