-- Arcanova — Neuaufbau 15.08.2026 (vorheriger Chat-Verlauf mit dem
-- Original-Code wurde versehentlich gelöscht, siehe Übergabeprotokoll vom
-- 29.07.2026). Ersetzt die 5 alten, fragmentierten Schema-Dateien durch
-- einen einzigen konsolidierten Satz für den aktuellen Kern-Loop
-- (Onboarding + Missionen mit Minispielen + Sternenenergie + Planeten-
-- Fortschritt). Quests/reward_catalog/redemptions kommen in einer eigenen
-- Migration, sobald der Belohnungs-Shop/Quest-Teil dran ist.
--
-- WICHTIG vor dem Ausführen: Falls im Supabase-Projekt
-- (dpjlfhxquqxmubstuyeb) noch Reste der alten Tabellen (tasks, progress,
-- rewards, profile, quests, ...) aus dem vorherigen Anlauf existieren,
-- vorher kurz im Table Editor prüfen — die hier neuen Tabellennamen
-- (arcanova_profile/arcanova_fortschritt/arcanova_missionen_log) sind
-- bewusst anders benannt, um nicht versehentlich mit altem, evtl.
-- inkonsistentem Bestand zu kollidieren.

create table if not exists public.arcanova_profile (
  child_id text primary key,
  heldenname text not null,
  age_group text not null check (age_group in ('3-6', '6-9')),
  onboarding_done boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.arcanova_fortschritt (
  child_id text primary key references public.arcanova_profile (child_id) on delete cascade,
  sternenenergie integer not null default 0,
  missionen_gesamt integer not null default 0
);

create table if not exists public.arcanova_missionen_log (
  id uuid primary key default gen_random_uuid(),
  child_id text not null references public.arcanova_profile (child_id) on delete cascade,
  typ text not null check (typ in ('morgen', 'tag', 'abend')),
  minispiel text not null,
  erfolgreich boolean not null,
  sternenenergie_erhalten integer not null,
  datum date not null default current_date,
  erstellt_am timestamptz not null default now()
);

create index if not exists arcanova_missionen_log_child_datum_idx
  on public.arcanova_missionen_log (child_id, datum);

-- Kein Login-System (bewusste Vorgabe aus dem Übergabeprotokoll: feste
-- child_id "kind_1", geräteübergreifend synchron über denselben
-- Datensatz). Die App greift ausschließlich über den Anon-/Publishable-Key
-- im Frontend zu — RLS bleibt hier bewusst offen für diesen einen festen
-- Datensatz, da es keine Nutzer-Authentifizierung gibt, die eine RLS-Regel
-- sinnvoll einschränken könnte. Das ist eine direkte Konsequenz der
-- No-Login-Entscheidung, hier nicht neu gelöst — heißt aber auch: Wer den
-- öffentlichen Anon-Key kennt (er steht im Frontend-Code, ist also nie
-- geheim), könnte theoretisch "kind_1"s Daten lesen/ändern. Für ein
-- Familien-internes Tool ohne Konto ist das ein akzeptierter Kompromiss,
-- lohnt sich aber, im Hinterkopf zu behalten, falls die App mal über den
-- Familienkreis hinausgeht.
alter table public.arcanova_profile enable row level security;
alter table public.arcanova_fortschritt enable row level security;
alter table public.arcanova_missionen_log enable row level security;

create policy "arcanova_profile: offen" on public.arcanova_profile for all using (true) with check (true);
create policy "arcanova_fortschritt: offen" on public.arcanova_fortschritt for all using (true) with check (true);
create policy "arcanova_missionen_log: offen" on public.arcanova_missionen_log for all using (true) with check (true);
