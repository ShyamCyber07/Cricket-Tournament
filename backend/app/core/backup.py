import asyncio
import os
import sqlite3
from datetime import datetime
import logging
from app.core.config import settings

logger = logging.getLogger("app.backup")

async def daily_sqlite_backup_loop():
    # Only run backup if the database is SQLite
    db_url = settings.DATABASE_URL
    if not db_url.startswith("sqlite"):
        logger.info("Database is not SQLite. Skipping backup background task.")
        return
        
    # Extract database file path
    db_path = db_url.replace("sqlite:///", "")
    if not db_path:
        db_path = "cricket.db"
        
    backup_dir = os.path.join(os.getcwd(), "backups")
    os.makedirs(backup_dir, exist_ok=True)
    
    logger.info("SQLite backup background task initialized.")
    
    while True:
        try:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            backup_filename = f"cricket_backup_{timestamp}.db"
            backup_path = os.path.join(backup_dir, backup_filename)
            
            if os.path.exists(db_path):
                # Safely copy using sqlite3 backup API to avoid write locks and corruption
                src_conn = sqlite3.connect(db_path)
                dest_conn = sqlite3.connect(backup_path)
                with dest_conn:
                    src_conn.backup(dest_conn)
                src_conn.close()
                dest_conn.close()
                logger.info(f"SQLite backup created successfully at: {backup_path}")
                
                # Keep only last 7 daily backups
                backups = sorted(
                    [os.path.join(backup_dir, f) for f in os.listdir(backup_dir) if f.startswith("cricket_backup_") and f.endswith(".db")],
                    key=os.path.getmtime
                )
                while len(backups) > 7:
                    oldest = backups.pop(0)
                    try:
                        os.remove(oldest)
                        logger.info(f"Removed old backup: {oldest}")
                    except Exception as e:
                        logger.error(f"Failed to remove old backup {oldest}: {e}")
            else:
                logger.warning(f"SQLite database file not found at {db_path}, skipping backup.")
        except Exception as e:
            logger.error(f"Error during SQLite backup: {e}")
            
        # Run daily (86400 seconds)
        await asyncio.sleep(86400)
