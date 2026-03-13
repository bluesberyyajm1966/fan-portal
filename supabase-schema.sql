-- ============================================================
--  Fan Footage Portal — Supabase Schema
--  Run this entire file in: Supabase Dashboard → SQL Editor
-- ============================================================


-- ── TABLE: submissions ──────────────────────────────────────
create table if not exists public.submissions (
  id            uuid primary key default gen_random_uuid(),
  created_at    timestamptz not null default now(),

  -- Fan info (all optional)
  fan_name      text,
  fan_handle    text,

  -- Show context (all optional)
  show_location text,
  show_date     text,
  notes         text,

  -- Video
  video_path    text not null,          -- storage path, e.g. submissions/1234_clip.mp4
  video_url     text not null,          -- public CDN URL

  -- Moderation
  status        text not null default 'pending'
                  check (status in ('pending', 'approved', 'rejected')),
  consented     boolean not null default true,
  admin_notes   text                    -- internal notes for band/admin
);

-- Index for the moderation queue (admin filters by status)
create index if not exists idx_submissions_status
  on public.submissions (status, created_at desc);


-- ── ROW-LEVEL SECURITY ──────────────────────────────────────
alter table public.submissions enable row level security;

-- Fans can INSERT (submit a clip) — no auth needed
create policy "Anyone can submit"
  on public.submissions
  for insert
  to anon
  with check (true);

-- Only authenticated admins can SELECT / UPDATE / DELETE
-- (In Supabase Dashboard → Authentication → Users, create an admin account)
create policy "Admins can read all submissions"
  on public.submissions
  for select
  to authenticated
  using (true);

create policy "Admins can update submissions"
  on public.submissions
  for update
  to authenticated
  using (true)
  with check (true);

create policy "Admins can delete submissions"
  on public.submissions
  for delete
  to authenticated
  using (true);


-- ── STORAGE BUCKET ──────────────────────────────────────────
-- Create the bucket via Dashboard → Storage → New Bucket
-- Name: fan-videos
-- Public: YES (so approved video URLs work without signed tokens)
-- File size limit: 524288000  (500 MB in bytes)
-- Allowed MIME types: video/mp4, video/quicktime

-- Storage RLS: allow anonymous uploads into submissions/ prefix only
-- Run these in the SQL editor after creating the bucket:

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'fan-videos',
  'fan-videos',
  true,
  524288000,
  array['video/mp4', 'video/quicktime']
)
on conflict (id) do nothing;

-- Allow anonymous users to upload to submissions/ folder
create policy "Anon upload to submissions"
  on storage.objects
  for insert
  to anon
  with check (
    bucket_id = 'fan-videos'
    and (storage.foldername(name))[1] = 'submissions'
  );

-- Allow public read of all objects in this bucket
create policy "Public read fan-videos"
  on storage.objects
  for select
  to public
  using (bucket_id = 'fan-videos');

-- Allow authenticated admins to delete objects (e.g. reject + remove)
create policy "Admin delete fan-videos"
  on storage.objects
  for delete
  to authenticated
  using (bucket_id = 'fan-videos');


-- ── HELPER VIEW: moderation queue ───────────────────────────
create or replace view public.moderation_queue as
  select
    id,
    created_at,
    fan_name,
    fan_handle,
    show_location,
    show_date,
    notes,
    video_url,
    video_path,
    status,
    admin_notes
  from public.submissions
  order by
    case status when 'pending' then 0 when 'approved' then 1 else 2 end,
    created_at desc;


-- ── SAMPLE: approve / reject via SQL ────────────────────────
-- (You can also do this from a dashboard you build later)

-- Approve:
--   update public.submissions set status = 'approved' where id = '<uuid>';

-- Reject + add note:
--   update public.submissions
--     set status = 'rejected', admin_notes = 'Out of focus'
--   where id = '<uuid>';
