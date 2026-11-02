
-- ============================================================
-- OPEN SCHEDULE
-- Initial PostgreSQL Database Schema
-- ============================================================
-- Tables:
-- 1. profiles
-- 2. subjects
-- 3. class_sessions
-- 4. academic_tasks
-- 5. study_sessions
--
-- Authentication is managed by Supabase Auth.
-- Run this migration ONCE in the new Supabase project.
-- ============================================================

BEGIN;

-- ============================================================
-- 1. PROFILES
-- One profile for each authenticated student.
-- ============================================================

CREATE TABLE public.profiles (
    user_id UUID PRIMARY KEY
        REFERENCES auth.users(id) ON DELETE CASCADE,

    display_name TEXT NOT NULL
        CHECK (LENGTH(BTRIM(display_name)) > 0),

    available_study_hours NUMERIC(5,2) NOT NULL DEFAULT 0
        CHECK (
            available_study_hours >= 0
            AND available_study_hours <= 168
        ),

    timezone TEXT NOT NULL DEFAULT 'Asia/Karachi',

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 2. SUBJECTS
-- Each student can manage multiple academic subjects.
-- ============================================================

CREATE TABLE public.subjects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES auth.users(id) ON DELETE CASCADE,

    subject_name TEXT NOT NULL
        CHECK (LENGTH(BTRIM(subject_name)) > 0),

    course_code TEXT,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Required for same-student composite foreign keys.
    CONSTRAINT subjects_user_id_id_unique
        UNIQUE (user_id, id)
);

-- Prevent duplicate non-empty course codes
-- for the same student, ignoring letter case.
CREATE UNIQUE INDEX subjects_user_course_code_unique
ON public.subjects (user_id, LOWER(BTRIM(course_code)))
WHERE course_code IS NOT NULL
  AND BTRIM(course_code) <> '';

CREATE INDEX subjects_user_active_idx
ON public.subjects (user_id, is_active);

-- ============================================================
-- 3. CLASS_SESSIONS
-- Recurring weekly university classes.
-- Weekday: Monday = 1, Sunday = 7.
-- ============================================================

CREATE TABLE public.class_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES auth.users(id) ON DELETE CASCADE,

    subject_id UUID NOT NULL,

    weekday SMALLINT NOT NULL
        CHECK (weekday BETWEEN 1 AND 7),

    start_time TIME NOT NULL,
    end_time TIME NOT NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT class_session_time_check
        CHECK (end_time > start_time),

    -- A class can only reference a subject
    -- belonging to the same student.
    CONSTRAINT class_session_subject_owner_fk
        FOREIGN KEY (user_id, subject_id)
        REFERENCES public.subjects (user_id, id)
        ON DELETE RESTRICT
);

CREATE INDEX class_sessions_user_weekday_idx
ON public.class_sessions (user_id, weekday, start_time);

-- ============================================================
-- 4. ACADEMIC_TASKS
-- Assignments, quizzes, projects and examinations.
-- ============================================================

CREATE TABLE public.academic_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES auth.users(id) ON DELETE CASCADE,

    subject_id UUID NOT NULL,

    title TEXT NOT NULL
        CHECK (LENGTH(BTRIM(title)) > 0),

    task_type TEXT NOT NULL
        CHECK (
            task_type IN (
                'assignment',
                'quiz',
                'project',
                'exam'
            )
        ),

    due_at TIMESTAMPTZ NOT NULL,

    estimated_remaining_hours NUMERIC(6,2) NOT NULL
        CHECK (estimated_remaining_hours >= 0),

    importance SMALLINT NOT NULL
        CHECK (importance BETWEEN 1 AND 5),

    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (
            status IN (
                'pending',
                'in_progress',
                'completed'
            )
        ),

    completed_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT academic_task_subject_owner_fk
        FOREIGN KEY (user_id, subject_id)
        REFERENCES public.subjects (user_id, id)
        ON DELETE RESTRICT,

    CONSTRAINT academic_task_completion_check
        CHECK (
            (status = 'completed' AND completed_at IS NOT NULL)
            OR
            (status <> 'completed' AND completed_at IS NULL)
        ),

    CONSTRAINT academic_tasks_user_id_id_unique
        UNIQUE (user_id, id)
);

CREATE INDEX academic_tasks_user_due_idx
ON public.academic_tasks (user_id, due_at);

CREATE INDEX academic_tasks_user_status_due_idx
ON public.academic_tasks (user_id, status, due_at);

CREATE INDEX academic_tasks_user_subject_idx
ON public.academic_tasks (user_id, subject_id);

-- Automatically manage completion timestamps.
CREATE OR REPLACE FUNCTION public.set_task_completion_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
    IF NEW.status = 'completed' THEN
        IF TG_OP = 'INSERT' THEN
            NEW.completed_at := COALESCE(NEW.completed_at, NOW());
        ELSIF OLD.status IS DISTINCT FROM 'completed' THEN
            NEW.completed_at := COALESCE(NEW.completed_at, NOW());
        END IF;
    ELSE
        NEW.completed_at := NULL;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER academic_task_completion_timestamp
BEFORE INSERT OR UPDATE OF status, completed_at
ON public.academic_tasks
FOR EACH ROW
EXECUTE FUNCTION public.set_task_completion_timestamp();

-- ============================================================
-- 5. STUDY_SESSIONS
-- Sessions can be linked to a task or be independent.
--
-- Deleting an academic task automatically deletes
-- all study sessions linked to that task.
--
-- Independent sessions require their own title.
-- ============================================================

CREATE TABLE public.study_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES auth.users(id) ON DELETE CASCADE,

    task_id UUID,

    title TEXT,

    start_at TIMESTAMPTZ NOT NULL,
    end_at TIMESTAMPTZ NOT NULL,

    status TEXT NOT NULL DEFAULT 'planned'
        CHECK (
            status IN (
                'planned',
                'completed',
                'cancelled'
            )
        ),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT study_session_time_check
        CHECK (end_at > start_at),

    CONSTRAINT independent_session_title_check
        CHECK (
            task_id IS NOT NULL
            OR (
                title IS NOT NULL
                AND LENGTH(BTRIM(title)) > 0
            )
        ),

    -- Ensures linked tasks belong to the same student.
    -- Deleting a task deletes its linked study sessions.
    CONSTRAINT study_session_task_owner_fk
        FOREIGN KEY (user_id, task_id)
        REFERENCES public.academic_tasks (user_id, id)
        ON DELETE CASCADE
);

CREATE INDEX study_sessions_user_start_idx
ON public.study_sessions (user_id, start_at);

CREATE INDEX study_sessions_user_task_idx
ON public.study_sessions (user_id, task_id);

-- ============================================================
-- 6. AUTOMATIC UPDATED_AT TIMESTAMPS
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER profiles_updated_at
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER subjects_updated_at
BEFORE UPDATE ON public.subjects
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER class_sessions_updated_at
BEFORE UPDATE ON public.class_sessions
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER academic_tasks_updated_at
BEFORE UPDATE ON public.academic_tasks
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER study_sessions_updated_at
BEFORE UPDATE ON public.study_sessions
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- 7. AUTOMATIC PROFILE CREATION
-- Create a profile when a Supabase Auth user registers.
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    INSERT INTO public.profiles (
        user_id,
        display_name
    )
    VALUES (
        NEW.id,
        COALESCE(
            NULLIF(
                BTRIM(NEW.raw_user_meta_data ->> 'display_name'),
                ''
            ),
            NULLIF(
                SPLIT_PART(COALESCE(NEW.email, ''), '@', 1),
                ''
            ),
            'Student'
        )
    )
    ON CONFLICT (user_id) DO NOTHING;

    RETURN NEW;
END;
$$;

CREATE TRIGGER on_open_schedule_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- 8. ROW LEVEL SECURITY
-- Each student can access only their own records.
-- ============================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.class_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.academic_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_sessions ENABLE ROW LEVEL SECURITY;

-- Remove any default anonymous table access.
REVOKE ALL ON TABLE
    public.profiles,
    public.subjects,
    public.class_sessions,
    public.academic_tasks,
    public.study_sessions
FROM anon;

-- Authenticated users need these permissions.
GRANT USAGE ON SCHEMA public TO authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
    public.profiles,
    public.subjects,
    public.class_sessions,
    public.academic_tasks,
    public.study_sessions
TO authenticated;

-- PROFILE POLICIES

CREATE POLICY profiles_owner_access
ON public.profiles
FOR ALL
TO authenticated
USING ((SELECT auth.uid()) = user_id)
WITH CHECK ((SELECT auth.uid()) = user_id);

-- SUBJECT POLICIES

CREATE POLICY subjects_owner_access
ON public.subjects
FOR ALL
TO authenticated
USING ((SELECT auth.uid()) = user_id)
WITH CHECK ((SELECT auth.uid()) = user_id);

-- CLASS SESSION POLICIES

CREATE POLICY class_sessions_owner_access
ON public.class_sessions
FOR ALL
TO authenticated
USING ((SELECT auth.uid()) = user_id)
WITH CHECK ((SELECT auth.uid()) = user_id);

-- ACADEMIC TASK POLICIES

CREATE POLICY academic_tasks_owner_access
ON public.academic_tasks
FOR ALL
TO authenticated
USING ((SELECT auth.uid()) = user_id)
WITH CHECK ((SELECT auth.uid()) = user_id);

-- STUDY SESSION POLICIES

CREATE POLICY study_sessions_owner_access
ON public.study_sessions
FOR ALL
TO authenticated
USING ((SELECT auth.uid()) = user_id)
WITH CHECK ((SELECT auth.uid()) = user_id);

COMMIT;

-- ============================================================
-- END OF OPEN SCHEDULE INITIAL SCHEMA
-- ============================================================
