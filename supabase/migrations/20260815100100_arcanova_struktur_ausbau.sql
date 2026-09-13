-- Arcanova — Struktur-Ausbau 15.08.2026: Morgenroutine/Abendroutine mit frei
-- konfigurierbaren Punkten, Wake-up-Workout, Lernblock (Workflow-Presets),
-- Eltern-Dashboard (PIN-geschützt) und ein über Sternenenergie freigeschaltetes
-- Spiele-/Freizeitbereich. Ergänzt arcanova_schema_v2.sql (arcanova_profile/
-- arcanova_fortschritt bleiben bestehen — hier per ALTER TABLE erweitert
-- statt neu angelegt) um die zusätzlichen Spalten/Tabellen für den
-- Struktur-Fokus. Sicher erneut ausführbar (if not exists / if not exists
-- column-Prüfung), falls Teile schon liefen.

alter table public.arcanova_profile add column if not exists eltern_pin text not null default '1234';
alter table public.arcanova_profile add column if not exists freizeit_schwelle integer not null default 30;
alter table public.arcanova_profile add column if not exists morgen_playlist_link text;
alter table public.arcanova_profile add column if not exists abend_playlist_link text;

-- Falls die App noch nie geöffnet/das Onboarding noch nie durchlaufen wurde,
-- gibt es noch keine "kind_1"-Zeile in arcanova_profile — die Seed-Inserts
-- weiter unten (routine_punkte etc.) brauchen sie aber wegen der Foreign-Key-
-- Verweise. Platzhalter mit onboarding_done=false anlegen, falls nötig — die
-- App zeigt trotzdem ganz normal den Onboarding-Screen, der echte Name/das
-- echte Alter überschreiben den Platzhalter danach automatisch.
insert into public.arcanova_profile (child_id, heldenname, age_group, onboarding_done)
select 'kind_1', 'Kind', '6-9', false
where not exists (select 1 from public.arcanova_profile where child_id = 'kind_1');

-- Von Eltern frei konfigurierbare Punkte je Routine (Morgen/Abend) — ein
-- Punkt mit typ='workout' öffnet statt eines einfachen Abhak-Tipps das
-- Wake-up-Workout (siehe arcanova_workout_uebungen) statt direkt als
-- erledigt zu gelten.
create table if not exists public.arcanova_routine_punkte (
  id uuid primary key default gen_random_uuid(),
  child_id text not null references public.arcanova_profile (child_id) on delete cascade,
  routine_typ text not null check (routine_typ in ('morgen', 'abend')),
  typ text not null default 'checkbox' check (typ in ('checkbox', 'workout')),
  name text not null,
  icon text not null default '✅',
  reihenfolge integer not null default 0,
  aktiv boolean not null default true
);

create table if not exists public.arcanova_routine_log (
  id uuid primary key default gen_random_uuid(),
  child_id text not null references public.arcanova_profile (child_id) on delete cascade,
  punkt_id uuid not null references public.arcanova_routine_punkte (id) on delete cascade,
  datum date not null default current_date,
  erstellt_am timestamptz not null default now(),
  unique (punkt_id, datum)
);

create table if not exists public.arcanova_workout_uebungen (
  id uuid primary key default gen_random_uuid(),
  child_id text not null references public.arcanova_profile (child_id) on delete cascade,
  name text not null,
  dauer_sek integer not null default 45,
  reihenfolge integer not null default 0,
  aktiv boolean not null default true
);

create table if not exists public.arcanova_workflow_presets (
  id uuid primary key default gen_random_uuid(),
  child_id text not null references public.arcanova_profile (child_id) on delete cascade,
  name text not null,
  arbeit_min integer not null default 15,
  pause_min integer not null default 5,
  gesamt_min integer not null default 45,
  playlist_link text,
  reihenfolge integer not null default 0,
  aktiv boolean not null default true
);

create table if not exists public.arcanova_workflow_log (
  id uuid primary key default gen_random_uuid(),
  child_id text not null references public.arcanova_profile (child_id) on delete cascade,
  preset_id uuid references public.arcanova_workflow_presets (id) on delete set null,
  preset_name text,
  datum date not null default current_date,
  erstellt_am timestamptz not null default now()
);

create table if not exists public.arcanova_freizeit_apps (
  id uuid primary key default gen_random_uuid(),
  child_id text not null references public.arcanova_profile (child_id) on delete cascade,
  name text not null,
  icon text not null default '🎮',
  link text not null,
  reihenfolge integer not null default 0,
  aktiv boolean not null default true
);

create index if not exists arcanova_routine_punkte_child_idx on public.arcanova_routine_punkte (child_id, routine_typ);
create index if not exists arcanova_routine_log_child_datum_idx on public.arcanova_routine_log (child_id, datum);
create index if not exists arcanova_workflow_log_child_datum_idx on public.arcanova_workflow_log (child_id, datum);

-- RLS wie in arcanova_schema_v2.sql begründet: kein Login-System, offen für
-- den öffentlichen Anon-Key (siehe dortiger Kommentar) — gilt unverändert
-- auch für die neuen Tabellen hier.
alter table public.arcanova_routine_punkte enable row level security;
alter table public.arcanova_routine_log enable row level security;
alter table public.arcanova_workout_uebungen enable row level security;
alter table public.arcanova_workflow_presets enable row level security;
alter table public.arcanova_workflow_log enable row level security;
alter table public.arcanova_freizeit_apps enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where tablename = 'arcanova_routine_punkte' and policyname = 'arcanova_routine_punkte: offen') then
    create policy "arcanova_routine_punkte: offen" on public.arcanova_routine_punkte for all using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where tablename = 'arcanova_routine_log' and policyname = 'arcanova_routine_log: offen') then
    create policy "arcanova_routine_log: offen" on public.arcanova_routine_log for all using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where tablename = 'arcanova_workout_uebungen' and policyname = 'arcanova_workout_uebungen: offen') then
    create policy "arcanova_workout_uebungen: offen" on public.arcanova_workout_uebungen for all using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where tablename = 'arcanova_workflow_presets' and policyname = 'arcanova_workflow_presets: offen') then
    create policy "arcanova_workflow_presets: offen" on public.arcanova_workflow_presets for all using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where tablename = 'arcanova_workflow_log' and policyname = 'arcanova_workflow_log: offen') then
    create policy "arcanova_workflow_log: offen" on public.arcanova_workflow_log for all using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where tablename = 'arcanova_freizeit_apps' and policyname = 'arcanova_freizeit_apps: offen') then
    create policy "arcanova_freizeit_apps: offen" on public.arcanova_freizeit_apps for all using (true) with check (true);
  end if;
end $$;

-- Sinnvolle Startbelegung, damit das Eltern-Dashboard nicht komplett leer
-- ist — nur falls für kind_1 noch GAR keine Routine-Punkte existieren
-- (kein erneutes Einfügen bei wiederholtem Ausführen oder falls Eltern
-- schon selbst etwas angelegt haben).
insert into public.arcanova_routine_punkte (child_id, routine_typ, typ, name, icon, reihenfolge)
select * from (values
  ('kind_1', 'morgen', 'workout', 'Wake-up-Workout', '🤸', 0),
  ('kind_1', 'morgen', 'checkbox', 'Zähne putzen', '🦷', 1),
  ('kind_1', 'morgen', 'checkbox', 'Gesicht waschen', '🧼', 2),
  ('kind_1', 'morgen', 'checkbox', 'Anziehen', '👕', 3),
  ('kind_1', 'morgen', 'checkbox', 'Frühstücken', '🥣', 4),
  ('kind_1', 'abend', 'checkbox', 'Zähne putzen', '🦷', 0),
  ('kind_1', 'abend', 'checkbox', 'Schlafanzug anziehen', '🌙', 1),
  ('kind_1', 'abend', 'checkbox', 'Schultasche packen', '🎒', 2)
) as t(child_id, routine_typ, typ, name, icon, reihenfolge)
where not exists (select 1 from public.arcanova_routine_punkte where child_id = 'kind_1');

insert into public.arcanova_workout_uebungen (child_id, name, dauer_sek, reihenfolge)
select * from (values
  ('kind_1', 'Hampelmänner', 30, 0),
  ('kind_1', 'Auf der Stelle laufen', 30, 1),
  ('kind_1', 'Superhelden-Sprünge', 30, 2)
) as t(child_id, name, dauer_sek, reihenfolge)
where not exists (select 1 from public.arcanova_workout_uebungen where child_id = 'kind_1');

insert into public.arcanova_workflow_presets (child_id, name, arbeit_min, pause_min, gesamt_min, reihenfolge)
select 'kind_1', 'Hausaufgaben', 15, 5, 45, 0
where not exists (select 1 from public.arcanova_workflow_presets where child_id = 'kind_1');
