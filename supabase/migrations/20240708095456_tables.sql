drop table if exists user_boards;
drop table if exists cards;
drop table if exists lists;
drop table if exists boards;
drop table if exists users;
drop table if exists notifications;

-- Create users table
create table
  users (
    id TEXT PRIMARY KEY,
    username TEXT,
    first_name TEXT,
    email TEXT,
    avatar_url TEXT,
    push_token TEXT
  );

-- Create boards table
create table boards (
  id bigint generated by default as identity primary key,
  creator text NOT NULL REFERENCES users (id),
  title text default 'Untitled Board',
  background text default '#126CB3',
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  last_edit timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Many to many table for user <-> boards relationship
create table user_boards (
  id bigint generated by default as identity primary key,
  user_id text NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  board_id bigint references boards ON DELETE CASCADE
);

-- Create lists table
create table lists (
  id bigint generated by default as identity primary key,
  board_id bigint references boards ON DELETE CASCADE not null,
  title text default '',
  position int not null default 0,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create Cards table
create table cards (
  id bigint generated by default as identity primary key,
  list_id bigint references lists ON DELETE CASCADE not null,
  board_id bigint references boards ON DELETE CASCADE not null,
  position int not null default 0,
  title text default '',
  description text check (char_length(description) > 0),
  assigned_to text REFERENCES users (id),
  done boolean default false,
  image_url text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

--create Notifications table
create table notifications (
  id bigint generated by default as identity primary key,
  user_id text NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  body text NOT NULL,
  card_id bigint REFERENCES cards (id) ON DELETE CASCADE,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Make sure deleted records are included in realtime
alter table cards replica identity full;
alter table lists replica identity full;

alter publication supabase_realtime add table cards;
alter publication supabase_realtime add table lists;

-- Function to get JWT user id
CREATE OR REPLACE FUNCTION requesting_user_id()
RETURNS TEXT AS $$
    SELECT NULLIF(
        current_setting('request.jwt.claims', true)::json->>'sub',
        ''
    )::text;
$$ LANGUAGE SQL STABLE;

-- Function to get all user boards
create or replace function get_boards_for_authenticated_user()
returns setof bigint
language sql
security definer
set search_path = ''
stable
as $$
    select board_id
    from public.user_boards
    where user_id = public.requesting_user_id()
$$;

-- inserts a row into user_boards
create or replace function public.handle_board_added()
returns trigger
language plpgsql
security definer
as $$
begin
  insert into public.user_boards (board_id, user_id)
  values (new.id, new.creator);
  return new;
end;
$$;

-- trigger the function every time a board is created
create trigger on_board_created
  after insert on boards
  for each row execute procedure public.handle_board_added();

-- notifications row level security
alter table notifications enable row level security;

-- boards row level security
alter table boards enable row level security;

-- Policies
create policy "Users can create boards" on boards for
  insert to authenticated with CHECK (true);

create policy "Users can view their boards" on boards for
    select using (
      id in (
        select get_boards_for_authenticated_user()
      )
    );

create policy "Users can update their boards" on boards for
    update using (
      id in (
        select get_boards_for_authenticated_user()
      )
    );

create policy "Users can delete their created boards" on boards for
    delete using ((requesting_user_id()) = creator);

-- user_boards row level security
alter table user_boards enable row level security;

create policy "Users can add their boards" on user_boards for
    insert to authenticated with check (true);

create policy "Users can view boards"
on user_boards
to public
using (
  true
);

create policy "Users can delete their boards" on user_boards for
    delete using ((requesting_user_id()) = user_id);

-- lists row level security
alter table lists enable row level security;

-- Policies
create policy "Users can edit lists if they are part of the board" on lists for
    all using (
      board_id in (
        select get_boards_for_authenticated_user()
      )
    );

-- cards row level security
alter table cards enable row level security;

-- Policies
create policy "Users can edit cards if they are part of the board" on cards for
    all using (
      board_id in (
        select get_boards_for_authenticated_user()
      )
    );

-- users row level security
alter table users enable row level security;

-- Policies
create policy "Users can view other users data"
on users
to authenticated
using (
  true
);

create policy "Users can update their own user" on users for
    update using (
      id = requesting_user_id()
    );

-- Search function
CREATE OR REPLACE FUNCTION public.search_users(search varchar)
RETURNS SETOF users
LANGUAGE plpgsql
AS $$
	begin
		return query
			SELECT *
			FROM users u
			WHERE search % ANY(STRING_TO_ARRAY(u.email, ' '));
	end;
$$;

-- Use Postgres to create a bucket.
insert into storage.buckets
  (id, name)
values
  ('files', 'files');

-- Protect the storage bucket.
create policy "Protect storage access" on storage.objects for all to public using (
  bucket_id = 'files'
  and (storage.foldername (name))[1]::bigint in (
    select
      get_boards_for_authenticated_user ()
  )
);

-- Create trigger function for notifications
create or replace function notify_user ()
returns trigger
language plpgsql
security definer
as $$
begin
  if new.assigned_to <> old.assigned_to then
    insert into notifications (user_id, body, card_id)
    values (new.assigned_to, 'You have been assigned to a card!', new.id);
  end if;
  return new;
end;
$$;

-- trigger the function every time a board is created
create trigger on_card_assigned
  before update on cards
  for each row execute procedure notify_user();

