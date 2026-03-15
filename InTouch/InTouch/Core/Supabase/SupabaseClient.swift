import Foundation
import Supabase

// MARK: - Supabase client singleton
// Replace the placeholder values below with your actual project URL and anon key
// from: Supabase Dashboard → Project Settings → API

let supabase = SupabaseClient(
    supabaseURL: URL(string: SupabaseConfig.url)!,
    supabaseKey: SupabaseConfig.anonKey,
    options: .init(
        auth: .init(emitLocalSessionAsInitialSession: true)
    )
)
