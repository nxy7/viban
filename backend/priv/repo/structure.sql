--
-- PostgreSQL database dump
--

\restrict 2p4hNlbUGXDMNY5cwWLymwratvZPXpp9Rtk4hPGacr2oCDNfRcjFYRp4JlEC6gc

-- Dumped from database version 16.11
-- Dumped by pg_dump version 17.7

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: oban_job_state; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.oban_job_state AS ENUM (
    'available',
    'scheduled',
    'executing',
    'retryable',
    'completed',
    'discarded',
    'cancelled'
);


--
-- Name: oban_count_estimate(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oban_count_estimate(state text, queue text) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
  plan jsonb;
BEGIN
  EXECUTE 'EXPLAIN (FORMAT JSON)
           SELECT id
           FROM public.oban_jobs
           WHERE state = $1::public.oban_job_state
           AND queue = $2'
    INTO plan
    USING state, queue;
  RETURN plan->0->'Plan'->'Plan Rows';
END;
$_$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: boards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.boards (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text,
    inserted_at timestamp without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    updated_at timestamp without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    user_id uuid NOT NULL
);

ALTER TABLE ONLY public.boards REPLICA IDENTITY FULL;


--
-- Name: column_hooks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.column_hooks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    hook_type text NOT NULL,
    "position" bigint DEFAULT 0,
    inserted_at timestamp without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    updated_at timestamp without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    column_id uuid NOT NULL,
    hook_id character varying(255) NOT NULL,
    execute_once boolean DEFAULT false,
    hook_settings jsonb DEFAULT '{}'::jsonb,
    transparent boolean DEFAULT false NOT NULL,
    removable boolean DEFAULT true
);

ALTER TABLE ONLY public.column_hooks REPLICA IDENTITY FULL;


--
-- Name: columns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.columns (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    "position" bigint DEFAULT 0 NOT NULL,
    color text DEFAULT '#6366f1'::text,
    inserted_at timestamp without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    updated_at timestamp without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    board_id uuid NOT NULL,
    settings jsonb DEFAULT '{}'::jsonb NOT NULL
);

ALTER TABLE ONLY public.columns REPLICA IDENTITY FULL;


--
-- Name: executor_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.executor_messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    role text NOT NULL,
    content text NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    session_id uuid NOT NULL
);


--
-- Name: executor_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.executor_sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    executor_type text NOT NULL,
    prompt text NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    exit_code bigint,
    error_message text,
    working_directory text,
    started_at timestamp(0) without time zone,
    completed_at timestamp(0) without time zone,
    metadata jsonb DEFAULT '{}'::jsonb,
    inserted_at timestamp without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    updated_at timestamp without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    task_id uuid NOT NULL
);


--
-- Name: hook_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hook_executions (
    id uuid NOT NULL,
    hook_name character varying(255) NOT NULL,
    hook_id character varying(255) NOT NULL,
    status character varying(255) DEFAULT 'pending'::character varying NOT NULL,
    skip_reason character varying(255),
    error_message text,
    hook_settings jsonb DEFAULT '{}'::jsonb,
    queued_at timestamp without time zone NOT NULL,
    started_at timestamp without time zone,
    completed_at timestamp without time zone,
    triggering_column_id uuid,
    task_id uuid NOT NULL,
    column_hook_id uuid,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: hooks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hooks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    command character varying(255),
    inserted_at timestamp without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    updated_at timestamp without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    board_id uuid NOT NULL,
    hook_kind character varying(255) DEFAULT 'script'::character varying NOT NULL,
    agent_prompt text,
    agent_executor character varying(255),
    agent_auto_approve boolean DEFAULT false,
    default_execute_once boolean DEFAULT false,
    default_transparent boolean DEFAULT false
);

ALTER TABLE ONLY public.hooks REPLICA IDENTITY FULL;


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    role text NOT NULL,
    content text NOT NULL,
    status text DEFAULT 'pending'::text,
    metadata jsonb DEFAULT '{}'::jsonb,
    sequence bigint NOT NULL,
    inserted_at timestamp without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    updated_at timestamp without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    task_id uuid NOT NULL
);


--
-- Name: oban_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oban_jobs (
    id bigint NOT NULL,
    state public.oban_job_state DEFAULT 'available'::public.oban_job_state NOT NULL,
    queue text DEFAULT 'default'::text NOT NULL,
    worker text NOT NULL,
    args jsonb DEFAULT '{}'::jsonb NOT NULL,
    errors jsonb[] DEFAULT ARRAY[]::jsonb[] NOT NULL,
    attempt integer DEFAULT 0 NOT NULL,
    max_attempts integer DEFAULT 20 NOT NULL,
    inserted_at timestamp without time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    scheduled_at timestamp without time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    attempted_at timestamp without time zone,
    completed_at timestamp without time zone,
    attempted_by text[],
    discarded_at timestamp without time zone,
    priority integer DEFAULT 0 NOT NULL,
    tags text[] DEFAULT ARRAY[]::text[],
    meta jsonb DEFAULT '{}'::jsonb,
    cancelled_at timestamp without time zone,
    CONSTRAINT attempt_range CHECK (((attempt >= 0) AND (attempt <= max_attempts))),
    CONSTRAINT positive_max_attempts CHECK ((max_attempts > 0)),
    CONSTRAINT queue_length CHECK (((char_length(queue) > 0) AND (char_length(queue) < 128))),
    CONSTRAINT worker_length CHECK (((char_length(worker) > 0) AND (char_length(worker) < 128)))
);


--
-- Name: TABLE oban_jobs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.oban_jobs IS '12';


--
-- Name: oban_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.oban_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oban_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.oban_jobs_id_seq OWNED BY public.oban_jobs.id;


--
-- Name: oban_peers; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.oban_peers (
    name text NOT NULL,
    node text NOT NULL,
    started_at timestamp without time zone NOT NULL,
    expires_at timestamp without time zone NOT NULL
);


--
-- Name: repositories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.repositories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    default_branch text DEFAULT 'main'::text,
    inserted_at timestamp without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    updated_at timestamp without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    board_id uuid NOT NULL,
    provider_repo_id text,
    full_name text,
    clone_url text,
    html_url character varying(255),
    local_path character varying(255),
    clone_status character varying(255) DEFAULT 'pending'::character varying,
    clone_error character varying(255),
    provider text DEFAULT 'local'::text NOT NULL
);

ALTER TABLE ONLY public.repositories REPLICA IDENTITY FULL;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tasks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title text NOT NULL,
    description text,
    "position" double precision DEFAULT 0.0 NOT NULL,
    priority text DEFAULT 'medium'::text,
    inserted_at timestamp without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    updated_at timestamp without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    column_id uuid NOT NULL,
    worktree_path text,
    worktree_branch text,
    agent_status text DEFAULT 'idle'::text,
    agent_status_message text,
    in_progress boolean DEFAULT false,
    error_message text,
    custom_branch_name text,
    queued_at timestamp(0) without time zone,
    queue_priority bigint DEFAULT 0,
    pr_url text,
    pr_number bigint,
    pr_status text,
    parent_task_id uuid,
    is_parent boolean DEFAULT false,
    subtask_position integer DEFAULT 0,
    subtask_generation_status character varying(255),
    executed_hooks character varying(255)[] DEFAULT ARRAY[]::character varying[],
    description_images jsonb[] DEFAULT ARRAY[]::jsonb[],
    message_queue jsonb[] DEFAULT ARRAY[]::jsonb[]
);

ALTER TABLE ONLY public.tasks REPLICA IDENTITY FULL;


--
-- Name: test_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.test_messages (
    id uuid NOT NULL,
    text character varying(255) NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

ALTER TABLE ONLY public.test_messages REPLICA IDENTITY FULL;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid NOT NULL,
    provider_uid text NOT NULL,
    provider_login character varying(255) NOT NULL,
    name character varying(255),
    email character varying(255),
    avatar_url character varying(255),
    access_token character varying(255) NOT NULL,
    token_expires_at timestamp(0) without time zone,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    provider text DEFAULT 'github'::text NOT NULL
);


--
-- Name: oban_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oban_jobs ALTER COLUMN id SET DEFAULT nextval('public.oban_jobs_id_seq'::regclass);


--
-- Name: boards boards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.boards
    ADD CONSTRAINT boards_pkey PRIMARY KEY (id);


--
-- Name: column_hooks column_hooks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.column_hooks
    ADD CONSTRAINT column_hooks_pkey PRIMARY KEY (id);


--
-- Name: columns columns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.columns
    ADD CONSTRAINT columns_pkey PRIMARY KEY (id);


--
-- Name: executor_messages executor_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.executor_messages
    ADD CONSTRAINT executor_messages_pkey PRIMARY KEY (id);


--
-- Name: executor_sessions executor_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.executor_sessions
    ADD CONSTRAINT executor_sessions_pkey PRIMARY KEY (id);


--
-- Name: hook_executions hook_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hook_executions
    ADD CONSTRAINT hook_executions_pkey PRIMARY KEY (id);


--
-- Name: hooks hooks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hooks
    ADD CONSTRAINT hooks_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: oban_jobs non_negative_priority; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.oban_jobs
    ADD CONSTRAINT non_negative_priority CHECK ((priority >= 0)) NOT VALID;


--
-- Name: oban_jobs oban_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oban_jobs
    ADD CONSTRAINT oban_jobs_pkey PRIMARY KEY (id);


--
-- Name: oban_peers oban_peers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oban_peers
    ADD CONSTRAINT oban_peers_pkey PRIMARY KEY (name);


--
-- Name: repositories repositories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.repositories
    ADD CONSTRAINT repositories_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);


--
-- Name: test_messages test_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_messages
    ADD CONSTRAINT test_messages_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: boards_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX boards_user_id_index ON public.boards USING btree (user_id);


--
-- Name: column_hooks_column_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX column_hooks_column_id_index ON public.column_hooks USING btree (column_id);


--
-- Name: column_hooks_column_id_position_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX column_hooks_column_id_position_index ON public.column_hooks USING btree (column_id, "position");


--
-- Name: column_hooks_hook_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX column_hooks_hook_id_index ON public.column_hooks USING btree (hook_id);


--
-- Name: hook_executions_task_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hook_executions_task_id_index ON public.hook_executions USING btree (task_id);


--
-- Name: hook_executions_task_id_queued_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hook_executions_task_id_queued_at_index ON public.hook_executions USING btree (task_id, queued_at);


--
-- Name: hook_executions_task_id_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hook_executions_task_id_status_index ON public.hook_executions USING btree (task_id, status);


--
-- Name: messages_task_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_task_id_index ON public.messages USING btree (task_id);


--
-- Name: messages_task_id_sequence_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_task_id_sequence_index ON public.messages USING btree (task_id, sequence);


--
-- Name: oban_jobs_args_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oban_jobs_args_index ON public.oban_jobs USING gin (args);


--
-- Name: oban_jobs_meta_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oban_jobs_meta_index ON public.oban_jobs USING gin (meta);


--
-- Name: oban_jobs_state_queue_priority_scheduled_at_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oban_jobs_state_queue_priority_scheduled_at_id_index ON public.oban_jobs USING btree (state, queue, priority, scheduled_at, id);


--
-- Name: repositories_github_repo_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX repositories_github_repo_id_index ON public.repositories USING btree (provider_repo_id);


--
-- Name: repositories_unique_local_path_per_board_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX repositories_unique_local_path_per_board_index ON public.repositories USING btree (board_id, local_path);


--
-- Name: tasks_column_id_queue_priority_queued_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_column_id_queue_priority_queued_at_index ON public.tasks USING btree (column_id, queue_priority, queued_at);


--
-- Name: tasks_parent_task_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_parent_task_id_index ON public.tasks USING btree (parent_task_id);


--
-- Name: tasks_parent_task_id_subtask_position_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_parent_task_id_subtask_position_index ON public.tasks USING btree (parent_task_id, subtask_position);


--
-- Name: tasks_pr_number_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_pr_number_index ON public.tasks USING btree (pr_number);


--
-- Name: tasks_unique_worktree_path_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX tasks_unique_worktree_path_index ON public.tasks USING btree (worktree_path);


--
-- Name: users_github_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_github_id_index ON public.users USING btree (provider_uid);


--
-- Name: users_unique_provider_uid_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_unique_provider_uid_index ON public.users USING btree (provider, provider_uid);


--
-- Name: boards boards_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.boards
    ADD CONSTRAINT boards_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: column_hooks column_hooks_column_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.column_hooks
    ADD CONSTRAINT column_hooks_column_id_fkey FOREIGN KEY (column_id) REFERENCES public.columns(id);


--
-- Name: columns columns_board_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.columns
    ADD CONSTRAINT columns_board_id_fkey FOREIGN KEY (board_id) REFERENCES public.boards(id);


--
-- Name: executor_messages executor_messages_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.executor_messages
    ADD CONSTRAINT executor_messages_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.executor_sessions(id) ON DELETE CASCADE;


--
-- Name: executor_sessions executor_sessions_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.executor_sessions
    ADD CONSTRAINT executor_sessions_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: hook_executions hook_executions_column_hook_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hook_executions
    ADD CONSTRAINT hook_executions_column_hook_id_fkey FOREIGN KEY (column_hook_id) REFERENCES public.column_hooks(id) ON DELETE SET NULL;


--
-- Name: hook_executions hook_executions_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hook_executions
    ADD CONSTRAINT hook_executions_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: hooks hooks_board_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hooks
    ADD CONSTRAINT hooks_board_id_fkey FOREIGN KEY (board_id) REFERENCES public.boards(id);


--
-- Name: messages messages_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: repositories repositories_board_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.repositories
    ADD CONSTRAINT repositories_board_id_fkey FOREIGN KEY (board_id) REFERENCES public.boards(id);


--
-- Name: tasks tasks_column_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_column_id_fkey FOREIGN KEY (column_id) REFERENCES public.columns(id);


--
-- Name: tasks tasks_parent_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_parent_task_id_fkey FOREIGN KEY (parent_task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: electric_publication_default; Type: PUBLICATION; Schema: -; Owner: -
--

CREATE PUBLICATION electric_publication_default WITH (publish = 'insert, update, delete, truncate');


--
-- Name: electric_publication_default boards; Type: PUBLICATION TABLE; Schema: public; Owner: -
--

ALTER PUBLICATION electric_publication_default ADD TABLE ONLY public.boards;


--
-- Name: electric_publication_default columns; Type: PUBLICATION TABLE; Schema: public; Owner: -
--

ALTER PUBLICATION electric_publication_default ADD TABLE ONLY public.columns;


--
-- Name: electric_publication_default tasks; Type: PUBLICATION TABLE; Schema: public; Owner: -
--

ALTER PUBLICATION electric_publication_default ADD TABLE ONLY public.tasks;


--
-- PostgreSQL database dump complete
--

\unrestrict 2p4hNlbUGXDMNY5cwWLymwratvZPXpp9Rtk4hPGacr2oCDNfRcjFYRp4JlEC6gc

INSERT INTO public."schema_migrations" (version) VALUES (20241229000001);
INSERT INTO public."schema_migrations" (version) VALUES (20251229234047);
INSERT INTO public."schema_migrations" (version) VALUES (20251229234048);
INSERT INTO public."schema_migrations" (version) VALUES (20251230004230);
INSERT INTO public."schema_migrations" (version) VALUES (20251230010635);
INSERT INTO public."schema_migrations" (version) VALUES (20251230010654);
INSERT INTO public."schema_migrations" (version) VALUES (20251230080713);
INSERT INTO public."schema_migrations" (version) VALUES (20251230091900);
INSERT INTO public."schema_migrations" (version) VALUES (20251230102609);
INSERT INTO public."schema_migrations" (version) VALUES (20251230104522);
INSERT INTO public."schema_migrations" (version) VALUES (20251230104811);
INSERT INTO public."schema_migrations" (version) VALUES (20251230123133);
INSERT INTO public."schema_migrations" (version) VALUES (20251230155151);
INSERT INTO public."schema_migrations" (version) VALUES (20251230165803);
INSERT INTO public."schema_migrations" (version) VALUES (20251230201613);
INSERT INTO public."schema_migrations" (version) VALUES (20251231001451);
INSERT INTO public."schema_migrations" (version) VALUES (20251231074504);
INSERT INTO public."schema_migrations" (version) VALUES (20251231075428);
INSERT INTO public."schema_migrations" (version) VALUES (20251231090000);
INSERT INTO public."schema_migrations" (version) VALUES (20251231093000);
INSERT INTO public."schema_migrations" (version) VALUES (20251231100000);
INSERT INTO public."schema_migrations" (version) VALUES (20251231110000);
INSERT INTO public."schema_migrations" (version) VALUES (20251231140000);
INSERT INTO public."schema_migrations" (version) VALUES (20251231150000);
INSERT INTO public."schema_migrations" (version) VALUES (20251231185141);
INSERT INTO public."schema_migrations" (version) VALUES (20251231200000);
INSERT INTO public."schema_migrations" (version) VALUES (20260101000001);
INSERT INTO public."schema_migrations" (version) VALUES (20260101132041);
INSERT INTO public."schema_migrations" (version) VALUES (20260101132928);
INSERT INTO public."schema_migrations" (version) VALUES (20260101175211);
INSERT INTO public."schema_migrations" (version) VALUES (20260101182721);
INSERT INTO public."schema_migrations" (version) VALUES (20260101193410);
INSERT INTO public."schema_migrations" (version) VALUES (20260101193836);
INSERT INTO public."schema_migrations" (version) VALUES (20260101211903);
INSERT INTO public."schema_migrations" (version) VALUES (20260102124443);
INSERT INTO public."schema_migrations" (version) VALUES (20260102170832);
INSERT INTO public."schema_migrations" (version) VALUES (20260102175544);
INSERT INTO public."schema_migrations" (version) VALUES (20260103090118);
INSERT INTO public."schema_migrations" (version) VALUES (20260103092115);
INSERT INTO public."schema_migrations" (version) VALUES (20260103112736);
INSERT INTO public."schema_migrations" (version) VALUES (20260103203423);
INSERT INTO public."schema_migrations" (version) VALUES (20260103204037);
