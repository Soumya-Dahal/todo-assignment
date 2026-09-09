from flask import Flask, jsonify, request, render_template_string, redirect, url_for
import os

import psycopg2
import psycopg2.extras

app = Flask(__name__)

DB_HOST = os.environ.get("DB_HOST", "db")
DB_NAME = os.environ.get("POSTGRES_DB", "appdb")
DB_USER = os.environ.get("POSTGRES_USER", "appuser")
DB_PASSWORD = os.environ.get("POSTGRES_PASSWORD", "apppassword")


def get_conn():
    return psycopg2.connect(
        host=DB_HOST, dbname=DB_NAME, user=DB_USER, password=DB_PASSWORD,
        connect_timeout=3,
    )


PAGE = """
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>Todo App</title>
  <style>
    body { font-family: sans-serif; max-width: 600px; margin: 40px auto; padding: 0 16px; }
    h1 { margin-bottom: 4px; }
    .meta { color: #666; font-size: 0.85em; margin-bottom: 24px; }
    form { display: flex; flex-direction: column; gap: 8px; margin-bottom: 24px; }
    input, textarea { padding: 8px; font-size: 1em; }
    button { padding: 8px; font-size: 1em; cursor: pointer; }
    ul { list-style: none; padding: 0; }
    li { border: 1px solid #ddd; border-radius: 6px; padding: 12px; margin-bottom: 10px; }
    li .title { font-weight: bold; }
    li .content { color: #333; margin: 6px 0; }
    li form { flex-direction: row; margin: 0; }
    .delete-btn { background: #e55; color: white; border: none; border-radius: 4px; padding: 4px 10px; }
  </style>
</head>
<body>
  <h1>Todo List</h1>
  <div class="meta">Backend: {{ hostname }} | DB connected: {{ db_connected }}</div>

  <form method="post" action="{{ url_for('add_todo') }}">
    <input type="text" name="title" placeholder="Title" required>
    <textarea name="content" placeholder="Content" rows="2"></textarea>
    <button type="submit">Add Todo</button>
  </form>

  <ul>
  {% for todo in todos %}
    <li>
      <div class="title">#{{ todo.id }} {{ todo.title }}</div>
      <div class="content">{{ todo.content or "" }}</div>
      <form method="post" action="{{ url_for('delete_todo', todo_id=todo.id) }}">
        <button class="delete-btn" type="submit">Delete</button>
      </form>
    </li>
  {% else %}
    <li>No todos yet.</li>
  {% endfor %}
  </ul>
</body>
</html>
"""


def db_connected():
    try:
        conn = get_conn()
        conn.close()
        return True
    except Exception:
        return False


@app.route("/")
def index():
    todos = []
    connected = db_connected()
    if connected:
        conn = get_conn()
        with conn, conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("SELECT id, title, content FROM todos ORDER BY id")
            todos = cur.fetchall()
        conn.close()
    return render_template_string(
        PAGE, todos=todos, hostname=os.environ.get("HOSTNAME", "app"),
        db_connected=connected,
    )


@app.route("/todos/add", methods=["POST"])
def add_todo():
    title = request.form.get("title", "").strip()
    content = request.form.get("content", "").strip()
    if title:
        conn = get_conn()
        with conn, conn.cursor() as cur:
            cur.execute(
                "INSERT INTO todos (title, content) VALUES (%s, %s)",
                (title, content),
            )
        conn.close()
    return redirect(url_for("index"))


@app.route("/todos/<int:todo_id>/delete", methods=["POST"])
def delete_todo(todo_id):
    conn = get_conn()
    with conn, conn.cursor() as cur:
        cur.execute("DELETE FROM todos WHERE id = %s", (todo_id,))
    conn.close()
    return redirect(url_for("index"))


# ---- Simple JSON API (handy for curl-based verification / screenshots) ----

@app.route("/api/todos", methods=["GET"])
def api_list_todos():
    conn = get_conn()
    with conn, conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute("SELECT id, title, content FROM todos ORDER BY id")
        todos = cur.fetchall()
    conn.close()
    return jsonify(todos)


@app.route("/api/todos", methods=["POST"])
def api_add_todo():
    data = request.get_json(force=True, silent=True) or {}
    title = (data.get("title") or "").strip()
    content = (data.get("content") or "").strip()
    if not title:
        return jsonify(error="title is required"), 400
    conn = get_conn()
    with conn, conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute(
            "INSERT INTO todos (title, content) VALUES (%s, %s) RETURNING id, title, content",
            (title, content),
        )
        row = cur.fetchone()
    conn.close()
    return jsonify(row), 201


@app.route("/health")
def health():
    return jsonify(status="ok"), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
