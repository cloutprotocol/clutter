import sqlite3
from pathlib import Path

class Database:
    def __init__(self):
        db_path = Path.home() / ".file_organizer.db"
        self.conn = sqlite3.connect(str(db_path))
        self.cursor = self.conn.cursor()
        self.init_database()

    def init_database(self):
        self.cursor.execute("""
            CREATE TABLE IF NOT EXISTS files (
                id INTEGER PRIMARY KEY,
                original_path TEXT,
                new_path TEXT,
                filename TEXT,
                category TEXT,
                subcategory TEXT,
                size INTEGER,
                date_processed TIMESTAMP,
                hash TEXT,
                metadata TEXT
            )
        """)
        self.conn.commit()

    # Add other database methods as needed 