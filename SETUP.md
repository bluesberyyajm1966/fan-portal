# Fan Footage Portal — Setup Guide

Everything you need to go from zero to live in ~15 minutes.

---

## 1. Create a Supabase Project

1. Go to [supabase.com](https://supabase.com) → **Start your project** (free tier is fine)
2. Choose a name (e.g. `band-fan-footage`) and a strong database password — save the password somewhere safe
3. Pick the region closest to your fans
4. Wait ~2 minutes for the project to provision

---

## 2. Run the Database Schema

1. In your Supabase dashboard, click **SQL Editor** in the left sidebar
2. Click **New query**
3. Paste the entire contents of **`supabase-schema.sql`** into the editor
4. Click **Run** (or `Cmd/Ctrl + Enter`)

This creates:
- The `submissions` table with all metadata fields
- Row-Level Security policies (fans can insert; only admins can read/update/delete)
- The `fan-videos` storage bucket (500 MB limit, MP4/MOV only)
- Storage policies (anonymous uploads to `submissions/`, public reads)
- A `moderation_queue` view for easy admin access

---

## 3. Get Your API Credentials

1. In the dashboard, go to **Settings → API**
2. Copy:
   - **Project URL** → looks like `https://abcdefghij.supabase.co`
   - **anon / public key** → the long `eyJ...` string under "Project API keys"

---

## 4. Paste Credentials into the HTML

Open `fan-footage-portal.html` and find this block near the bottom `<script>`:

```js
const SUPABASE_URL = 'https://YOUR_PROJECT_ID.supabase.co';
const SUPABASE_ANON_KEY = 'YOUR_ANON_KEY';
const STORAGE_BUCKET = 'fan-videos';
```

Replace the placeholder values with your real URL and anon key.

> **Security note:** The anon key is safe to expose in frontend code — it's
> designed for public use. The RLS policies you ran in step 2 ensure fans
> can only *insert*, never read or modify other submissions.

---

## 5. Deploy the Site

The portal is a single HTML file — deploy it anywhere:

| Platform | How |
|---|---|
| **Vercel** | `npx vercel` in the folder, or drag-and-drop in the dashboard |
| **Netlify** | Drag the folder onto [app.netlify.com/drop](https://app.netlify.com/drop) |
| **GitHub Pages** | Push to a repo, enable Pages in Settings |

No build step needed — it's vanilla HTML + ES modules loaded from a CDN.

---

## 6. Create an Admin Account (for moderation)

1. In Supabase dashboard → **Authentication → Users → Add user**
2. Enter the band manager's email + a strong password
3. They can now query the `moderation_queue` view directly in the SQL editor, or you can build a simple dashboard later (Phase 2)

**Quick moderation via SQL Editor:**

```sql
-- See all pending submissions
select id, created_at, fan_name, show_location, video_url
from moderation_queue
where status = 'pending';

-- Approve a clip
update submissions set status = 'approved' where id = '<paste-uuid>';

-- Reject a clip with a note
update submissions
  set status = 'rejected', admin_notes = 'Duplicate clip'
where id = '<paste-uuid>';
```

---

## 7. (Optional) Email Notifications on New Submission

To get an email every time a fan submits:

1. In Supabase → **Database → Webhooks → Create a new hook**
2. Table: `submissions` | Event: `INSERT`
3. Point it at a free [Make.com](https://make.com) or [Zapier](https://zapier.com) webhook
4. In Make/Zapier: trigger → send email to band manager

---

## What Each File Does

| File | Purpose |
|---|---|
| `fan-footage-portal.html` | The entire fan-facing website |
| `supabase-schema.sql` | Run once in Supabase SQL Editor to set up DB + Storage |
| `SETUP.md` | This guide |

---

## Phase 2 Checklist (Fan Gallery)

When you're ready to build the public gallery:

- [ ] Query `submissions` where `status = 'approved'` using the Supabase JS client
- [ ] Render a CSS Grid of `<video>` thumbnails using `video_url`
- [ ] Add a lightbox (e.g. [GLightbox](https://biati-digital.github.io/glightbox/)) for full-screen playback
- [ ] Build a simple admin dashboard (React or plain HTML) with approve/reject buttons

---

## Troubleshooting

**Upload fails with "Invalid API key"**
→ Double-check you pasted the **anon** key, not the **service_role** key.

**"new row violates row-level security policy"**
→ Re-run the SQL schema — the anon INSERT policy may not have been created.

**Video URL returns 400**
→ Make sure the bucket is set to **Public** in Storage → Buckets → Edit.

**CORS error on localhost**
→ In Supabase → Settings → API → add `http://localhost:PORT` to allowed origins, or just test on the deployed URL.
