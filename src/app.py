import os
import psycopg2
from flask import Flask, jsonify, request
import socket

app = Flask(__name__)

# Konfiguracja pobierana z Docker Compose
DB_HOST = os.getenv('DB_HOST', 'pgpool')
DB_PORT = os.getenv('DB_PORT', '9999')
DB_USER = os.getenv('DB_USER', 'primary')
DB_PASS = os.getenv('DB_PASS', 'pw')
DB_NAME = os.getenv('DB_NAME', 'primary')

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST, port=DB_PORT, 
        user=DB_USER, password=DB_PASS, dbname=DB_NAME
    )

@app.route('/')
def home():
    return jsonify({
        "message": "System Liczników Wody",
        "container_id": socket.gethostname(),
        "db_connected_to": DB_HOST,
        "status": "Aplikacja działa i łączy się z PgPool"
    })

# METODA GET - do wyświetlania odczytów (to naprawi błąd 404)
@app.route('/readings/<int:meter_id>', methods=['GET'])
def get_readings(meter_id):
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        # Nazwa tabeli musi być 'reading' (zgodnie z Twoim SQL)
        cur.execute('SELECT reading_time, value_m3 FROM reading WHERE meter_id = %s ORDER BY reading_time DESC', (meter_id,))
        rows = cur.fetchall()
        cur.close()
        conn.close()
        return jsonify(rows)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# METODA POST - do dodawania nowych danych
@app.route('/add_reading', methods=['POST'])
def add_reading():
    data = request.json
    meter_id = data.get('meter_id')
    value = data.get('value')
    
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        # Nazwa tabeli: reading, kolumny: meter_id, value_m3, reading_time
        cur.execute('INSERT INTO reading (meter_id, value_m3, reading_time) VALUES (%s, %s, NOW())', (meter_id, value))
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({"status": "Odczyt zapisany pomyślnie!"}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)