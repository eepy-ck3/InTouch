# InTouch — Technical Design Document

**InTouch** is a "Social Intent" iOS app where users share what they *intend* to do (Open Invites), replacing group texts with a centralized, actionable feed. Core engagement is measured by **Joins** and **Coordinations**, not likes or scroll time.

**Stack:** Swift + SwiftUI (iOS native) + Supabase (PostgreSQL, Auth, Realtime, Storage)

---

## Database Schema (PostgreSQL / Supabase)

```sql
-- Users
users (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username        text UNIQUE NOT NULL,
  full_name       text NOT NULL,
  avatar_url      text,
  primary_location_lat   float8,
  primary_location_lng   float8,
  primary_location_name  text,
  created_at      timestamptz DEFAULT now()
)

-- Social graph
friendships (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid REFERENCES users(id),
  friend_id   uuid REFERENCES users(id),
  status      text CHECK (status IN ('pending', 'accepted')),
  created_at  timestamptz DEFAULT now(),
  UNIQUE (user_id, friend_id)
)

-- Groups
groups (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name         text NOT NULL,
  creator_id   uuid REFERENCES users(id),
  description  text,
  created_at   timestamptz DEFAULT now()
)

group_members (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id   uuid REFERENCES groups(id),
  user_id    uuid REFERENCES users(id),
  role       text CHECK (role IN ('admin', 'member')),
  joined_at  timestamptz DEFAULT now(),
  UNIQUE (group_id, user_id)
)

-- Core intent post
intents (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  creator_id      uuid REFERENCES users(id),
  title           text NOT NULL,
  description     text,
  category        text,
  timeframe       text CHECK (timeframe IN ('immediate', 'planned', 'longterm')),
  visibility      text CHECK (visibility IN ('private', 'friends', 'groups', 'public')),
  location_lat    float8,
  location_lng    float8,
  location_name   text,
  status          text CHECK (status IN ('active', 'expired')) DEFAULT 'active',
  starts_at       timestamptz,
  expires_at      timestamptz,
  created_at      timestamptz DEFAULT now()
)

-- Which groups can see a given intent (when visibility = 'groups')
intent_groups (
  intent_id   uuid REFERENCES intents(id),
  group_id    uuid REFERENCES groups(id),
  PRIMARY KEY (intent_id, group_id)
)

-- Join tracking
intent_joins (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  intent_id   uuid REFERENCES intents(id),
  user_id     uuid REFERENCES users(id),
  joined_at   timestamptz DEFAULT now(),
  UNIQUE (intent_id, user_id)
)

-- Rich comment / message thread on an intent
-- message_type drives rendering:
--   text     → body = message text
--   image    → media_url = Storage URL
--   video    → media_url = Storage URL
--   location → metadata = { lat, lng, name }
--   link     → media_url = URL, metadata = { og_title, og_description, og_image }
--   reaction → body = emoji character
intent_comments (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  intent_id     uuid REFERENCES intents(id),
  user_id       uuid REFERENCES users(id),
  message_type  text CHECK (message_type IN ('text', 'image', 'video', 'location', 'link', 'reaction')),
  body          text,
  media_url     text,
  metadata      jsonb,
  created_at    timestamptz DEFAULT now()
)

-- Notification subscriptions (auto-created on Join)
intent_subscriptions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  intent_id   uuid REFERENCES intents(id),
  user_id     uuid REFERENCES users(id),
  created_at  timestamptz DEFAULT now(),
  UNIQUE (intent_id, user_id)
)

-- In-app notifications
notifications (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid REFERENCES users(id),
  type        text NOT NULL,
  payload     jsonb,
  intent_id   uuid REFERENCES intents(id),
  read_at     timestamptz,
  created_at  timestamptz DEFAULT now()
)
```

---

## State Management Strategy

### Local view state
- **SwiftUI + `@Observable`** (iOS 17+) for all local view state
- No external state management library — keep it native

### Live data
- **Supabase Realtime** channels subscribe to `postgres_changes` events on:
  - `intent_joins` — live participant count updates on Intent detail screen
  - `intent_comments` — live message thread updates
- Each feed type (Personal, Discovery) has its own `FeedViewModel` that manages its Realtime subscription lifecycle (`onAppear` subscribe, `onDisappear` unsubscribe)

### Push notifications
- **APNs** for remote push delivery
- **Supabase Edge Functions** act as push trigger handlers — fired by Supabase Database Webhooks on relevant table events (new join, new comment, etc.)
- Edge Functions call APNs HTTP/2 API to deliver notifications to subscribed users

---

## Primary API Surface

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `POST` | `/auth/v1/signup` | Create account |
| `POST` | `/auth/v1/token` | Sign in |
| `POST` | `/rest/v1/intents` | Create intent |
| `GET`  | `/functions/v1/personal-feed` | Fetch personal feed (friends + groups) |
| `GET`  | `/functions/v1/discovery-feed?lat=&lng=&radius=` | Fetch geo-fenced public intents |
| `POST` | `/rest/v1/intent_joins` | Join an intent |
| `GET`  | `/rest/v1/intent_joins?intent_id=eq.{id}` | Get participants for an intent |
| `POST` | `/rest/v1/intent_comments` | Post update on intent thread |
| `GET`  | `/rest/v1/notifications?user_id=eq.{id}` | Fetch notifications |

**Note:** Personal and Discovery feeds are implemented as Edge Functions rather than direct REST queries because they require:
- Personal feed: join across `friendships` + `group_members` with privacy filtering
- Discovery feed: PostGIS `ST_DWithin` geo-filter on `intents.location`

---

## MVP Roadmap

### Step 1 — Intent + Auth loop (due 2026-04-15)
Core create/view/join flow with auth.

- Xcode project setup (SwiftUI, iOS 17+, Supabase Swift SDK)
- Supabase project config (schema, RLS policies, Storage buckets)
- Sign Up / Sign In screens (Supabase Auth)
- Onboarding flow (profile setup + primary location)
- "Create Intent" form (title, description, category, timeframe, visibility)
- Intent detail screen with Join button + live participants list
- Rich comment thread (text, image, video, location, link, reaction message types)
- Post expiry logic (cron or Supabase scheduled function: `active` → `expired`)

### Step 2 — Feed logic (due 2026-05-15)
Surfaces intents to the right users.

- Personal Feed (chronological; intents from friends + joined groups, respecting visibility)
- Discovery Feed (geo-fenced public intents filtered by radius using PostGIS)
- Feed filtering by category

### Step 3 — Notifications & subscriptions (due 2026-06-15)
Push triggers that drive coordination.

- APNs setup + Supabase push notification config
- Auto-subscribe user to intent thread on Join (insert into `intent_subscriptions`)
- Push trigger: new user joins your intent
- Push trigger: creator posts update on a joined intent
- Push trigger: friend posts an "Immediate" intent

### v1.0 — Groups, privacy, polish (due 2026-08-01)
Full social graph and access control.

- Groups creation & management screen
- Group invites & member roles (admin / member)
- Granular visibility controls (private / friends / groups / public)
- User profile & friend management screen

---

## Key Design Decisions

### Why Edge Functions for feeds?
Direct Supabase REST queries don't support PostGIS spatial filtering or complex multi-table joins with RLS logic in a single call. Edge Functions let us compose the query server-side and return a clean, paginated result.

### Why `@Observable` over `ObservableObject`?
iOS 17+ `@Observable` has finer-grained re-rendering (only views that read a property re-render on change) and simpler syntax. Since InTouch targets iOS 17+, this is the right default.

### Why Realtime only on detail screens, not the feed?
Feed-level Realtime subscriptions for every visible cell would create excessive open connections. Instead, feeds poll on pull-to-refresh, and only the open Intent detail screen subscribes to live join/comment updates.

### `message_type` pattern for intent comments
A single `intent_comments` table handles all rich message types via a discriminated `message_type` column. This avoids separate tables per message type and keeps queries simple. The iOS rendering layer switches on `message_type` to pick the right SwiftUI view.
