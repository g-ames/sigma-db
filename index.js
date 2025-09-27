const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const dotenv = require('dotenv');
const fs = require('fs');
const https = require('https');

var privateKey = fs.readFileSync('../server.key');
var certificate = fs.readFileSync('../server.crt');

var credentials = {key: privateKey, cert: certificate};

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;
const DB_PATH = process.env.DB_PATH || './db/sigma.db';

app.use(express.json());

let db = new sqlite3.Database(DB_PATH, (err) => {
    if (err) {
        console.error(`Error connecting to database: ${err.message}`);
    } else {
        console.log(`Connected to the SQLite database at ${DB_PATH}`);
    }
});

function runQuery(sql, params = []) {
    return new Promise((resolve, reject) => {
        if (sql.trim().toUpperCase().startsWith('SELECT')) {
            db.all(sql, params, (err, rows) => {
                if (err) {
                    reject(err);
                } else {
                    resolve(rows);
                }
            });
        } else {
            db.run(sql, params, function(err) {
                if (err) {
                    reject(err);
                } else {
                    resolve({ changes: this.changes, lastID: this.lastID });
                }
            });
        }     
    });
}

app.get('/', (req, res) => {
    res.send('Welcome to Sigma-DB! Send raw SQL queries to /sql');
});

app.post('/sql', async (req, res) => {
    const { query, params } = req.body;

    if (!query) {
        return res.status(400).json({ error: 'SQL query is required in the request body.' });
    }

    console.log(`Received SQL query: ${query}`);
    if (params && params.length > 0) {
        console.log(`With parameters: ${JSON.stringify(params)}`);
    }

    try {
        const result = await runQuery(query, params);
        res.status(200).json({ success: true, data: result });
    } catch (err) {
        console.error(`Error executing SQL query: ${err.message}`);
        res.status(500).json({ success: false, error: err.message });
    }
});

https.createServer(credentials, app).listen(PORT, () => {
    console.log(`Sigma-DB server running on http://localhost:${PORT}`);
    console.log(`Database file: ${DB_PATH}`);
});

process.on('SIGINT', () => {
    db.close((err) => {
        if (err) {
            console.error(`Error closing database: ${err.message}`);
        } else {
            console.log('Database connection closed.');
        }
        process.exit(0);
    });
});