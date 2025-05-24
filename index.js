// index.js

const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const dotenv = require('dotenv');

// Load environment variables from .env file
dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;
const DB_PATH = process.env.DB_PATH || './db/sigma.db';

// Middleware to parse JSON bodies
app.use(express.json());

// Initialize SQLite database
let db = new sqlite3.Database(DB_PATH, (err) => {
    if (err) {
        console.error(`Error connecting to database: ${err.message}`);
    } else {
        console.log(`Connected to the SQLite database at ${DB_PATH}`);
        // You might want to create a default table if it doesn't exist for testing
        // db.run("CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT, email TEXT)");
    }
});

// Helper function to handle database queries
function runQuery(sql, params = []) {
    return new Promise((resolve, reject) => {
        // Determine if it's a SELECT query
        if (sql.trim().toUpperCase().startsWith('SELECT')) {
            db.all(sql, params, (err, rows) => {
                if (err) {
                    reject(err);
                } else {
                    resolve(rows);
                }
            });
        } else {
            // For INSERT, UPDATE, DELETE, CREATE, etc.
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

// Routes

// Root endpoint for a simple check
app.get('/', (req, res) => {
    res.send('Welcome to Sigma-DB! Send raw SQL queries to /sql');
});

// Endpoint to handle raw SQL requests
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

// Start the server
app.listen(PORT, () => {
    console.log(`Sigma-DB server running on http://localhost:${PORT}`);
    console.log(`Database file: ${DB_PATH}`);
});

// Graceful shutdown
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