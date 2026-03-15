-- ============================================================
-- InTouch — Full Database Schema
-- Run this in the Supabase SQL Editor
-- ============================================================

-- Enable PostGIS for geo-fenced Discovery feed
CREATE EXTENSION IF NOT EXISTS postgis;


-- ============================================================
-- TABLES (all created first, no forward references)
-- ============================================================

CREATE TABLE users (
  id                      uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username                text UNIQUE NOT NULL,
  full_name               text NOT NULL,
  avatar_url              text,
  primary_location_lat    float8,
  primary_location_lng    float8,
  primary_location_name   text,
  created_at              timestamptz DEFAULT now()
);

CREATE TABLE friendships (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  friend_id   uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status      text NOT NULL CHECK (status IN ('pending', 'accepted')),
  created_at  timestamptz DEFAULT now(),
  UNIQUE (user_id, friend_id)
);

CREATE TABLE groups (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name         text NOT NULL,
  creator_id   uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  description  text,
  created_at   timestamptz DEFAULT now()
);

CREATE TABLE group_members (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id   uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role       text NOT NULL CHECK (role IN ('admin', 'member')),
  joined_at  timestamptz DEFAULT now(),
  UNIQUE (group_id, user_id)
);

CREATE TABLE intents (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  creator_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title           text NOT NULL,
  description     text,
  category        text,
  timeframe       text NOT NULL CHECK (timeframe IN ('immediate', 'planned', 'longterm')),
  visibility      text NOT NULL CHECK (visibility IN ('private', 'friends', 'groups', 'public')),
  location_lat    float8,
  location_lng    float8,
  location_name   text,
  location        geography(POINT, 4326),
  status          text NOT NULL CHECK (status IN ('active', 'expired')) DEFAULT 'active',
  starts_at       timestamptz,
  expires_at      timestamptz,
  created_at      timestamptz DEFAULT now()
);

-- Must exist before intent_joins trigger references it
CREATE TABLE intent_subscriptions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  intent_id   uuid NOT NULL REFERENCES intents(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at  timestamptz DEFAULT now(),
  UNIQUE (intent_id, user_id)
);

-- Must exist before intents RLS policy references it
CREATE TABLE intent_groups (
  intent_id   uuid NOT NULL REFERENCES intents(id) ON DELETE CASCADE,
  group_id    uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  PRIMARY KEY (intent_id, group_id)
);

CREATE TABLE intent_joins (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  intent_id   uuid NOT NULL REFERENCES intents(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at   timestamptz DEFAULT now(),
  UNIQUE (intent_id, user_id)
);

CREATE TABLE intent_comments (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  intent_id     uuid NOT NULL REFERENCES intents(id) ON DELETE CASCADE,
  user_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  message_type  text NOT NULL CHECK (message_type IN ('text', 'image', 'video', 'location', 'link', 'reaction')),
  body          text,
  media_url     text,
  metadata      jsonb,
  created_at    timestamptz DEFAULT now()
);

CREATE TABLE notifications (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type        text NOT NULL,
  payload     jsonb,
  intent_id   uuid REFERENCES intents(id) ON DELETE SET NULL,
  read_at     timestamptz,
  created_at  timestamptz DEFAULT now()
);


-- ============================================================
-- ENABLE ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE users               ENABLE ROW LEVEL SECURITY;
ALTER TABLE friendships         ENABLE ROW LEVEL SECURITY;
ALTER TABLE groups              ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members       ENABLE ROW LEVEL SECURITY;
ALTER TABLE intents             ENABLE ROW LEVEL SECURITY;
ALTER TABLE intent_groups       ENABLE ROW LEVEL SECURITY;
ALTER TABLE intent_joins        ENABLE ROW LEVEL SECURITY;
ALTER TABLE intent_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE intent_comments     ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications       ENABLE ROW LEVEL SECURITY;


-- ============================================================
-- RLS POLICIES (all tables exist at this point)
-- ============================================================

-- users
CREATE POLICY "Users are viewable by everyone"
  ON users FOR SELECT USING (true);

CREATE POLICY "Users can insert own profile"
  ON users FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON users FOR UPDATE USING (auth.uid() = id);

-- friendships
CREATE POLICY "Users can view own friendships"
  ON friendships FOR SELECT
  USING (auth.uid() = user_id OR auth.uid() = friend_id);

CREATE POLICY "Users can create friend requests"
  ON friendships FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own friendships"
  ON friendships FOR UPDATE
  USING (auth.uid() = user_id OR auth.uid() = friend_id);

CREATE POLICY "Users can delete own friendships"
  ON friendships FOR DELETE
  USING (auth.uid() = user_id OR auth.uid() = friend_id);

-- groups
CREATE POLICY "Group members can view group"
  ON groups FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM group_members
      WHERE group_members.group_id = groups.id
        AND group_members.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can create groups"
  ON groups FOR INSERT
  WITH CHECK (auth.uid() = creator_id);

CREATE POLICY "Group admins can update group"
  ON groups FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM group_members
      WHERE group_members.group_id = groups.id
        AND group_members.user_id = auth.uid()
        AND group_members.role = 'admin'
    )
  );

-- group_members
CREATE POLICY "Members can view group membership"
  ON group_members FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM group_members gm
      WHERE gm.group_id = group_members.group_id
        AND gm.user_id = auth.uid()
    )
  );

CREATE POLICY "Admins can add group members"
  ON group_members FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM group_members gm
      WHERE gm.group_id = group_members.group_id
        AND gm.user_id = auth.uid()
        AND gm.role = 'admin'
    )
    OR auth.uid() = (SELECT creator_id FROM groups WHERE id = group_members.group_id)
  );

CREATE POLICY "Users can leave groups"
  ON group_members FOR DELETE
  USING (auth.uid() = user_id);

-- intents (all referenced tables now exist)
CREATE POLICY "Intents visible based on visibility setting"
  ON intents FOR SELECT
  USING (
    auth.uid() = creator_id
    OR visibility = 'public'
    OR (visibility = 'friends' AND EXISTS (
      SELECT 1 FROM friendships
      WHERE status = 'accepted'
        AND (
          (user_id = creator_id AND friend_id = auth.uid())
          OR (friend_id = creator_id AND user_id = auth.uid())
        )
    ))
    OR (visibility = 'groups' AND EXISTS (
      SELECT 1 FROM intent_groups ig
      JOIN group_members gm ON gm.group_id = ig.group_id
      WHERE ig.intent_id = intents.id
        AND gm.user_id = auth.uid()
    ))
  );

CREATE POLICY "Users can create intents"
  ON intents FOR INSERT
  WITH CHECK (auth.uid() = creator_id);

CREATE POLICY "Creators can update own intents"
  ON intents FOR UPDATE
  USING (auth.uid() = creator_id);

CREATE POLICY "Creators can delete own intents"
  ON intents FOR DELETE
  USING (auth.uid() = creator_id);

-- intent_groups
CREATE POLICY "Intent groups visible to group members"
  ON intent_groups FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM group_members
      WHERE group_members.group_id = intent_groups.group_id
        AND group_members.user_id = auth.uid()
    )
  );

CREATE POLICY "Intent creators can manage intent groups"
  ON intent_groups FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM intents
      WHERE intents.id = intent_groups.intent_id
        AND intents.creator_id = auth.uid()
    )
  );

CREATE POLICY "Intent creators can delete intent groups"
  ON intent_groups FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM intents
      WHERE intents.id = intent_groups.intent_id
        AND intents.creator_id = auth.uid()
    )
  );

-- intent_joins
CREATE POLICY "Joins visible to intent viewers"
  ON intent_joins FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM intents
      WHERE intents.id = intent_joins.intent_id
    )
  );

CREATE POLICY "Users can join intents"
  ON intent_joins FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can leave intents"
  ON intent_joins FOR DELETE
  USING (auth.uid() = user_id);

-- intent_subscriptions
CREATE POLICY "Users can view own subscriptions"
  ON intent_subscriptions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own subscriptions"
  ON intent_subscriptions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can unsubscribe"
  ON intent_subscriptions FOR DELETE
  USING (auth.uid() = user_id);

-- intent_comments
CREATE POLICY "Comments visible to intent viewers"
  ON intent_comments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM intents
      WHERE intents.id = intent_comments.intent_id
    )
  );

CREATE POLICY "Users can post comments"
  ON intent_comments FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own comments"
  ON intent_comments FOR DELETE
  USING (auth.uid() = user_id);

-- notifications
CREATE POLICY "Users can view own notifications"
  ON notifications FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can mark notifications read"
  ON notifications FOR UPDATE
  USING (auth.uid() = user_id);


-- ============================================================
-- TRIGGERS & FUNCTIONS
-- ============================================================

-- Auto-create user profile row on sign-up
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, full_name, username)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'username', '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Auto-subscribe user to intent thread on Join
CREATE OR REPLACE FUNCTION handle_intent_join()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.intent_subscriptions (intent_id, user_id)
  VALUES (NEW.intent_id, NEW.user_id)
  ON CONFLICT (intent_id, user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_intent_joined
  AFTER INSERT ON intent_joins
  FOR EACH ROW EXECUTE FUNCTION handle_intent_join();

-- Keep PostGIS geography column in sync with lat/lng
CREATE OR REPLACE FUNCTION sync_intent_location()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.location_lat IS NOT NULL AND NEW.location_lng IS NOT NULL THEN
    NEW.location = ST_SetSRID(ST_MakePoint(NEW.location_lng, NEW.location_lat), 4326)::geography;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER sync_intent_location_trigger
  BEFORE INSERT OR UPDATE ON intents
  FOR EACH ROW EXECUTE FUNCTION sync_intent_location();


-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX ON intents (creator_id);
CREATE INDEX ON intents (status, expires_at);
CREATE INDEX ON intents (visibility);
CREATE INDEX ON intent_joins (intent_id);
CREATE INDEX ON intent_joins (user_id);
CREATE INDEX ON intent_comments (intent_id, created_at);
CREATE INDEX ON intent_subscriptions (intent_id);
CREATE INDEX ON intent_subscriptions (user_id);
CREATE INDEX ON friendships (user_id, status);
CREATE INDEX ON friendships (friend_id, status);
CREATE INDEX ON notifications (user_id, read_at);
CREATE INDEX ON intents USING GIST (location);
