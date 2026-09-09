-- Automatically executed by the official postgres image on first startup
-- (files in /docker-entrypoint-initdb.d/ run once, only when the data
-- directory is empty).

CREATE TABLE IF NOT EXISTS todos (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO todos (title, content) VALUES
    ('Set up the server', 'Provision the Ubuntu VM and harden SSH'),
    ('Deploy the stack', 'Bring up Nginx, Flask, and Postgres with Docker Compose'),
    ('Write the runbook', 'Document setup, verification, and restore steps in README.md');
