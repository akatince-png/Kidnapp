-- Arcanova — Belohnungs-Shop 13.09.2026. Löst die in
-- 20260815100000_arcanova_kern_schema.sql angekündigte separate Migration
-- für Quests/reward_catalog/redemptions ein: Eltern legen im Dashboard einen
-- Katalog an Prämien fest (Name, Icon, Kosten in Sternenenergie), Kinder
-- lösen sie über ihr gesammeltes (kumulatives, nie automatisch verbrauchtes)
-- sternenenergie-Guthaben aus arcanova_fortschritt ein. arcanova_redemptions
-- ist das Einlöse-Log — abgeholt=false markiert Prämien, die das Kind schon
-- "gekauft", aber die Eltern noch nicht real ausgehändigt haben.

create table if not exists public.arcanova_reward_catalog (
  id uuid primary key default gen_random_uuid(),
  child_id text not null references public.arcanova_profile (child_id) on delete cascade,
  name text not null,
  icon text not null default '🎁',
  kosten integer not null default 20 check (kosten > 0),
  reihenfolge integer not null default 0,
  aktiv boolean not null default true
);

create table if not exists public.arcanova_redemptions (
  id uuid primary key default gen_random_uuid(),
  child_id text not null references public.arcanova_profile (child_id) on delete cascade,
  reward_id uuid references public.arcanova_reward_catalog (id) on delete set null,
  reward_name text not null,
  reward_icon text not null default '🎁',
  kosten integer not null,
  abgeholt boolean not null default false,
  eingeloest_am timestamptz not null default now()
);

create index if not exists arcanova_reward_catalog_child_idx
  on public.arcanova_reward_catalog (child_id, reihenfolge);
create index if not exists arcanova_redemptions_child_idx
  on public.arcanova_redemptions (child_id, eingeloest_am);

-- RLS wie in arcanova_schema_v2.sql begründet: kein Login-System, offen für
-- den öffentlichen Anon-Key — gilt unverändert auch für die neuen Tabellen.
alter table public.arcanova_reward_catalog enable row level security;
alter table public.arcanova_redemptions enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where tablename = 'arcanova_reward_catalog' and policyname = 'arcanova_reward_catalog: offen') then
    create policy "arcanova_reward_catalog: offen" on public.arcanova_reward_catalog for all using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where tablename = 'arcanova_redemptions' and policyname = 'arcanova_redemptions: offen') then
    create policy "arcanova_redemptions: offen" on public.arcanova_redemptions for all using (true) with check (true);
  end if;
end $$;

-- Sinnvolle Startbelegung, damit der Shop nicht komplett leer ist — nur
-- falls für kind_1 noch GAR kein Katalog existiert.
insert into public.arcanova_reward_catalog (child_id, name, icon, kosten, reihenfolge)
select * from (values
  ('kind_1', '15 Minuten extra Freizeit', '🕹️', 15, 0),
  ('kind_1', 'Film-Abend aussuchen', '🍿', 40, 1),
  ('kind_1', 'Kleine Überraschung', '🎁', 60, 2)
) as t(child_id, name, icon, kosten, reihenfolge)
where not exists (select 1 from public.arcanova_reward_catalog where child_id = 'kind_1');
