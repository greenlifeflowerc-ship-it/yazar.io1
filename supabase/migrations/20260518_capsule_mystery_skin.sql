-- ── Capsule & Mystery Skin System ────────────────────────────────────────────
-- Run this migration in the Supabase SQL editor.
-- Safe to re-run: every statement uses IF NOT EXISTS / OR REPLACE.

-- 1. Capsule inventory (one row per slot per user)
CREATE TABLE IF NOT EXISTS public.capsule_inventory (
  id            uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id       uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  slot_index    smallint    NOT NULL CHECK (slot_index BETWEEN 0 AND 2),
  tier          text        NOT NULL,            -- 'common'|'rare'|'epic'|'legendary'|'mystery'
  brew_started  timestamptz NOT NULL DEFAULT now(),
  is_opened     boolean     NOT NULL DEFAULT false,
  created_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, slot_index)
);

ALTER TABLE public.capsule_inventory ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS capsule_own ON public.capsule_inventory;
CREATE POLICY capsule_own ON public.capsule_inventory
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- 2. Mystery skin pieces (one row per skin per user)
CREATE TABLE IF NOT EXISTS public.mystery_skin_pieces (
  id              uuid     DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id         uuid     NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  skin_key        text     NOT NULL,
  pieces_owned    int      NOT NULL DEFAULT 0 CHECK (pieces_owned >= 0),
  evolution_level smallint NOT NULL DEFAULT 0 CHECK (evolution_level BETWEEN 0 AND 3),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, skin_key)
);

ALTER TABLE public.mystery_skin_pieces ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS mystery_skin_own ON public.mystery_skin_pieces;
CREATE POLICY mystery_skin_own ON public.mystery_skin_pieces
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- 3. Pity counter (guarantees a rare+ after N common opens)
CREATE TABLE IF NOT EXISTS public.capsule_pity_counter (
  user_id      uuid     PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  common_opens int      NOT NULL DEFAULT 0,
  rare_opens   int      NOT NULL DEFAULT 0
);

ALTER TABLE public.capsule_pity_counter ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pity_own ON public.capsule_pity_counter;
CREATE POLICY pity_own ON public.capsule_pity_counter
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ── RPC: open a capsule ───────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.open_capsule(
  p_slot_index  smallint,
  p_skip_dna    int DEFAULT 0          -- DNA cost to skip brew (0 = free open)
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_row      public.capsule_inventory%ROWTYPE;
  v_tier     text;
  v_reward   jsonb;
  v_profile  public.profiles%ROWTYPE;
  v_brew_sec bigint;
  v_elapsed  bigint;
BEGIN
  SELECT * INTO v_row
  FROM public.capsule_inventory
  WHERE user_id = auth.uid() AND slot_index = p_slot_index AND NOT is_opened;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No active capsule in slot %', p_slot_index;
  END IF;

  v_tier := v_row.tier;
  v_brew_sec := CASE v_tier
    WHEN 'common'    THEN 1800
    WHEN 'rare'      THEN 7200
    WHEN 'epic'      THEN 28800
    WHEN 'legendary' THEN 86400
    WHEN 'mystery'   THEN 43200
    ELSE 1800
  END;

  v_elapsed := EXTRACT(EPOCH FROM (now() - v_row.brew_started))::bigint;

  -- If brew not done, require DNA skip payment
  IF v_elapsed < v_brew_sec THEN
    IF p_skip_dna <= 0 THEN
      RAISE EXCEPTION 'Capsule not ready. Use DNA to skip.';
    END IF;
    SELECT * INTO v_profile FROM public.profiles WHERE id = auth.uid();
    IF v_profile.dna < p_skip_dna THEN
      RAISE EXCEPTION 'Not enough DNA';
    END IF;
    UPDATE public.profiles SET dna = dna - p_skip_dna WHERE id = auth.uid();
  END IF;

  -- Mark capsule as opened
  UPDATE public.capsule_inventory SET is_opened = true
  WHERE id = v_row.id;

  -- Generate reward (simple server-side roll)
  v_reward := public.generate_capsule_reward(v_tier, auth.uid());

  RETURN v_reward;
END;
$$;

-- ── RPC: generate capsule reward ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.generate_capsule_reward(
  p_tier    text,
  p_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_roll  float := random();
  v_type  text;
  v_coins int := 0;
  v_dna   int := 0;
  v_key   text;
  v_skins text[] := ARRAY[
    'mystery_bat', 'mystery_bbb', 'mystery_eagle',
    'mystery_jago', 'mystery_rick'
  ];
  v_picked text;
BEGIN
  -- Determine reward type based on tier
  v_type := CASE
    WHEN p_tier = 'legendary'             THEN 'full_skin'
    WHEN p_tier = 'mystery'               THEN 'skin_piece'
    WHEN p_tier = 'epic'   AND v_roll < 0.40 THEN 'skin_piece'
    WHEN p_tier = 'rare'   AND v_roll < 0.20 THEN 'skin_piece'
    WHEN p_tier = 'common' AND v_roll < 0.08 THEN 'skin_piece'
    WHEN v_roll < 0.5                     THEN 'coins'
    ELSE                                       'dna'
  END;

  IF v_type IN ('skin_piece', 'full_skin') THEN
    -- Pick a random skin key
    v_picked := v_skins[1 + floor(random() * array_length(v_skins, 1))::int];

    IF v_type = 'full_skin' THEN
      -- Give 5 pieces (full set)
      INSERT INTO public.mystery_skin_pieces (user_id, skin_key, pieces_owned)
      VALUES (p_user_id, v_picked, 5)
      ON CONFLICT (user_id, skin_key)
      DO UPDATE SET pieces_owned = LEAST(mystery_skin_pieces.pieces_owned + 5, 30),
                    updated_at = now();
    ELSE
      INSERT INTO public.mystery_skin_pieces (user_id, skin_key, pieces_owned)
      VALUES (p_user_id, v_picked, 1)
      ON CONFLICT (user_id, skin_key)
      DO UPDATE SET pieces_owned = mystery_skin_pieces.pieces_owned + 1,
                    updated_at = now();
    END IF;

    RETURN jsonb_build_object(
      'type', v_type,
      'skin_key', v_picked
    );
  END IF;

  IF v_type = 'coins' THEN
    v_coins := CASE p_tier
      WHEN 'common'    THEN 10 + floor(random() * 20)::int
      WHEN 'rare'      THEN 30 + floor(random() * 40)::int
      WHEN 'epic'      THEN 80 + floor(random() * 70)::int
      WHEN 'legendary' THEN 200 + floor(random() * 150)::int
      ELSE 20
    END;
    UPDATE public.profiles SET coins = coins + v_coins WHERE id = p_user_id;
    RETURN jsonb_build_object('type', 'coins', 'amount', v_coins);
  END IF;

  -- dna
  v_dna := CASE p_tier
    WHEN 'common'    THEN 5 + floor(random() * 10)::int
    WHEN 'rare'      THEN 15 + floor(random() * 20)::int
    WHEN 'epic'      THEN 35 + floor(random() * 30)::int
    WHEN 'legendary' THEN 80 + floor(random() * 60)::int
    ELSE 10
  END;
  UPDATE public.profiles SET dna = dna + v_dna WHERE id = p_user_id;
  RETURN jsonb_build_object('type', 'dna', 'amount', v_dna);
END;
$$;

-- ── RPC: get mystery skin progress ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_mystery_skin_progress()
RETURNS TABLE (
  skin_key        text,
  pieces_owned    int,
  evolution_level smallint
)
LANGUAGE sql SECURITY DEFINER AS $$
  SELECT skin_key, pieces_owned, evolution_level
  FROM public.mystery_skin_pieces
  WHERE user_id = auth.uid();
$$;

-- ── RPC: evolve mystery skin ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.evolve_mystery_skin(p_skin_key text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_row   public.mystery_skin_pieces%ROWTYPE;
  v_need  int;
BEGIN
  SELECT * INTO v_row
  FROM public.mystery_skin_pieces
  WHERE user_id = auth.uid() AND skin_key = p_skin_key;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No pieces found for skin %', p_skin_key;
  END IF;

  IF v_row.evolution_level >= 3 THEN
    RAISE EXCEPTION 'Already at max level';
  END IF;

  v_need := CASE v_row.evolution_level
    WHEN 0 THEN 5
    WHEN 1 THEN 15
    WHEN 2 THEN 30
    ELSE 9999
  END;

  IF v_row.pieces_owned < v_need THEN
    RAISE EXCEPTION 'Not enough pieces (need %, have %)', v_need, v_row.pieces_owned;
  END IF;

  UPDATE public.mystery_skin_pieces
  SET evolution_level = evolution_level + 1,
      updated_at = now()
  WHERE user_id = auth.uid() AND skin_key = p_skin_key;

  RETURN jsonb_build_object(
    'skin_key', p_skin_key,
    'new_level', v_row.evolution_level + 1
  );
END;
$$;
