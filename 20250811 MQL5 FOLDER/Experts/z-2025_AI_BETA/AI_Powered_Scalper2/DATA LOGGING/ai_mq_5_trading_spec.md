# AI-Integrated MQ5 Trading System with Time-Series Data Logging

## 1. Overview

This system combines MetaTrader 5 (MT5) with an AI prediction engine and a time-series database. The MQ5 Expert Advisor (EA) sends real-time tick and bar data to a Python bridge, which logs it to a database and queries an AI model for trading decisions.

---

## 2. Components

### 2.1 MetaTrader 5 EA (MQL5)

- Collects tick and bar data
- Sends data via socket (TCP or ZeroMQ) to Python
- Receives AI prediction response
- Executes trades based on AI signals

### 2.2 Python Bridge

- Receives incoming data from EA
- Writes tick/bar data to TimescaleDB or InfluxDB
- Feeds data to AI model
- Sends trading decision back to EA

### 2.3 Time-Series Database

- Stores tick and bar data
- Stores AI predictions (optional)

### 2.4 AI Model

- Can be local (PyTorch/TensorFlow) or cloud (e.g. DeepSeek API)
- Inference performed in Python
- Returns signal, TP, SL, confidence

---

## 3. System Architecture

- MT5 runs natively on Windows
- Python Bridge runs in Windows or WSL
- DB (TimescaleDB/InfluxDB) runs in WSL
- AI model runs in WSL (for Linux compatibility and package management)

---

## 4. WSL Setup

```powershell
wsl --install
```

Inside Ubuntu:

```bash
sudo apt update && sudo apt upgrade
```

---

## 5. TimescaleDB Setup

```bash
# Add repo
sudo apt install -y gnupg curl ca-certificates lsb-release
curl -sSL https://packagecloud.io/timescale/timescaledb/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/timescale.gpg

echo "deb [signed-by=/usr/share/keyrings/timescale.gpg] https://packagecloud.io/timescaledb/debian/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/timescaledb.list

# Install TimescaleDB
sudo apt update
sudo apt install -y timescaledb-postgresql-15

# Tune and restart
sudo timescaledb-tune
sudo systemctl restart postgresql
```

```sql
-- Create DB
sudo -u postgres psql
CREATE DATABASE forex_ai;
\c forex_ai
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Create tables
CREATE TABLE tick_data (
  time TIMESTAMPTZ NOT NULL,
  symbol TEXT,
  bid DOUBLE PRECISION,
  ask DOUBLE PRECISION,
  last DOUBLE PRECISION,
  volume DOUBLE PRECISION
);

CREATE TABLE bar_data (
  time TIMESTAMPTZ NOT NULL,
  symbol TEXT,
  timeframe TEXT,
  open DOUBLE PRECISION,
  high DOUBLE PRECISION,
  low DOUBLE PRECISION,
  close DOUBLE PRECISION,
  volume DOUBLE PRECISION
);

-- Convert to hypertables
SELECT create_hypertable('tick_data', 'time');
SELECT create_hypertable('bar_data', 'time');
```

---

## 6. Python Bridge Setup

### Install Python dependencies (in WSL or native)

```bash
pip install psycopg2 influxdb-client pyzmq pandas flask
```

### Sample `bridge.py`

```python
import json, socket
from datetime import datetime
import psycopg2

conn = psycopg2.connect("dbname=forex_ai user=postgres")
cur = conn.cursor()

HOST, PORT = "localhost", 9000
s = socket.socket()
s.bind((HOST, PORT))
s.listen(5)

while True:
    client, _ = s.accept()
    raw = client.recv(4096).decode()
    data = json.loads(raw)

    if data['type'] == 'tick':
        cur.execute("""
        INSERT INTO tick_data (time, symbol, bid, ask, last, volume)
        VALUES (%s, %s, %s, %s, %s, %s)
        """, (
            data['time'], data['symbol'], data['bid'],
            data['ask'], data['last'], data['volume']
        ))
    elif data['type'] == 'bar':
        cur.execute("""
        INSERT INTO bar_data (time, symbol, timeframe, open, high, low, close, volume)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """, (
            data['time'], data['symbol'], data['timeframe'],
            data['open'], data['high'], data['low'],
            data['close'], data['volume']
        ))

    conn.commit()
    # Dummy AI signal
    response = {"signal": "BUY", "tp": 1.0850, "sl": 1.0830}
    client.send(json.dumps(response).encode())
    client.close()
```

---

## 7. MQL5 Socket Example

```mql5
#include <WinSock2.mqh>
SOCKET sock;
int init() {
   WSADATA wsa;
   WSAStartup(MAKEWORD(2, 2), wsa);
   sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
   sockaddr_in server;
   server.sin_family = AF_INET;
   server.sin_port = htons(9000);
   server.sin_addr.s_addr = inet_addr("127.0.0.1");
   connect(sock, server);
   return(INIT_SUCCEEDED);
}

void OnTick() {
   string json = "{\"type\":\"tick\",\"symbol\":\"EURUSD\",\"time\":\"2025-07-06T12:00:01Z\",\"bid\":1.0842,\"ask\":1.0843,\"last\":1.08425,\"volume\":0.5}";
   send(sock, json, StringLen(json), 0);
   char buffer[512];
   int r = recv(sock, buffer, 512, 0);
   if (r > 0) {
     Print(CharArrayToString(buffer));
   }
}
```

---

## 8. Optional Enhancements

- Use ZeroMQ for faster message handling
- Store AI decisions in a third table
- Create Flask REST API instead of sockets
- Add batch inserts or async processing
- Add retraining pipeline from DB-stored data

---

## 9. Monitoring Tools

- **pgAdmin / DBeaver**: View DB records
- **Jupyter**: Analyze AI model + logs
- **Grafana**: Visualize tick flow (InfluxDB only)

---

## 10. Final Notes

This architecture gives you:

- Real-time logging
- Central audit trail
- AI traceability
- Future model re-trainability

It supports multiple AI versions, interpretable signal generation, and long-term scaling into production systems.

