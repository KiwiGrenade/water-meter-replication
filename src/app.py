import os
import psycopg2
from flask import Flask, jsonify, request, render_template_string, redirect, url_for
import socket

app = Flask(__name__)

DB_CONFIG = {
    "host": os.getenv('DB_HOST', 'pgpool'),
    "port": os.getenv('DB_PORT', '9999'),
    "user": os.getenv('DB_USER', 'primary'),
    "pass": os.getenv('DB_PASS', 'pw'),
    "name": os.getenv('DB_NAME', 'primary')
}

def get_db_connection():
    return psycopg2.connect(
        host=DB_CONFIG["host"], port=DB_CONFIG["port"],
        user=DB_CONFIG["user"], password=DB_CONFIG["pass"], dbname=DB_CONFIG["name"]
    )

HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>System Liczników Wody</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css">
    <style>
        body { background-color: #f8f9fa; }
        .stats-card { background: white; border-radius: 15px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); padding: 20px; margin-bottom: 20px; }
        .node-info { background: #2c3e50; color: white; padding: 10px; border-radius: 5px; font-family: monospace; }
        .container-highlight { color: #00d1b2; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container py-5">
        <header class="text-center mb-5">
            <h1 class="display-4">💧 System Liczników Wody</h1>
            <div class="node-info mt-3">
                Obsłużone przez kontener: <span class="container-highlight">{{ container_id }}</span> | 
                Baza: <span class="text-info">{{ db_host }}</span>
            </div>
        </header>

        <div class="row">
            <div class="col-md-6">
                <div class="stats-card text-center">
                    <h3>Statystyki Systemu</h3>
                    <div class="row mt-4">
                        <div class="col-6">
                            <h2 class="text-primary">{{ m_count }}</h2>
                            <p class="text-muted">Liczników</p>
                        </div>
                        <div class="col-6">
                            <h2 class="text-success">{{ r_count }}</h2>
                            <p class="text-muted">Odczytów</p>
                        </div>
                    </div>
                    <hr>
                    <h5>Ostatnie 5 odczytów:</h5>
                    <ul class="list-group list-group-flush text-start">
                        {% for r in last_readings %}
                        <li class="list-group-item">
                            Licznik #{{ r[0] }}: <strong>{{ r[2] }} m³</strong> <small class="text-muted float-end">{{ r[1].strftime('%Y-%m-%d %H:%M') }}</small>
                        </li>
                        {% endfor %}
                    </ul>
                </div>
            </div>

            <div class="col-md-6">
                <div class="stats-card">
                    <h3>Dodaj Nowy Odczyt</h3>
                    <form action="/web_add" method="POST" class="mt-4">
                        <div class="mb-3">
                            <label class="form-label">Wybierz Licznik (ID)</label>
                            <select name="meter_id" class="form-select">
                                {% for m in meters %}
                                <option value="{{ m[0] }}">Licznik #{{ m[0] }} ({{ m[1] }})</option>
                                {% endfor %}
                            </select>
                        </div>
                        <div class="mb-3">
                            <label class="form-label">Wartość (m³)</label>
                            <input type="number" step="0.001" name="value" class="form-control" required placeholder="np. 125.450">
                        </div>
                        <button type="submit" class="btn btn-primary w-100">Zapisz Odczyt do Bazy</button>
                    </form>
                    <p class="mt-3 small text-muted text-center">
                        Uwaga: Zapis trafia do <b>Primary</b>, odczyt statystyk z <b>Repliki</b> (via PgPool).
                    </p>
                </div>
            </div>
        </div>
    </div>
</body>
</html>
"""

@app.route('/')
def dashboard():
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        # 1. Liczba liczników
        cur.execute('SELECT COUNT(*) FROM meter')
        m_count = cur.fetchone()[0]
        
        # 2. Liczba odczytów
        cur.execute('SELECT COUNT(*) FROM reading')
        r_count = cur.fetchone()[0]

        # 3. Lista liczników do selecta
        cur.execute('SELECT id, meter_number FROM meter')
        meters = cur.fetchall()

        # 4. Ostatnie 5 odczytów
        cur.execute('SELECT meter_id, reading_time, value_m3 FROM reading ORDER BY reading_time DESC LIMIT 5')
        last_readings = cur.fetchall()

        cur.close()
        conn.close()

        return render_template_string(
            HTML_TEMPLATE,
            container_id=socket.gethostname(),
            db_host=DB_CONFIG['host'],
            m_count=m_count,
            r_count=r_count,
            meters=meters,
            last_readings=last_readings
        )
    except Exception as e:
        return f"Błąd bazy danych: {str(e)}", 500

@app.route('/web_add', methods=['POST'])
def web_add():
    meter_id = request.form.get('meter_id')
    value = request.form.get('value')
    
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute('INSERT INTO reading (meter_id, value_m3, reading_time) VALUES (%s, %s, NOW())', (meter_id, value))
        conn.commit()
        cur.close()
        conn.close()
        return redirect(url_for('dashboard'))
    except Exception as e:
        return f"Błąd zapisu: {str(e)}", 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)