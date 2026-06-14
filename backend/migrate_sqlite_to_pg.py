import argparse
import sys
import uuid
from datetime import datetime, date
from sqlalchemy import create_engine, MetaData, Table, text, select, Boolean, Date, DateTime
from sqlalchemy.dialects.postgresql import UUID

def convert_value(val, col_type):
    if val is None:
        return None
    
    # Get class name of the column type
    type_name = col_type.__class__.__name__
    
    if type_name == 'UUID':
        if isinstance(val, str):
            try:
                return uuid.UUID(val)
            except ValueError:
                pass
        return val
        
    if type_name == 'Boolean':
        if isinstance(val, int):
            return bool(val)
        if isinstance(val, str):
            return val.lower() in ('true', '1', 't', 'y', 'yes')
        return bool(val)
        
    if type_name == 'Date':
        if isinstance(val, str):
            try:
                return datetime.strptime(val.split()[0], "%Y-%m-%d").date()
            except ValueError:
                pass
        return val
        
    if type_name == 'DateTime':
        if isinstance(val, str):
            val_clean = val.replace('Z', '').replace('T', ' ')
            for fmt in ("%Y-%m-%d %H:%M:%S.%f", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d"):
                try:
                    return datetime.strptime(val_clean, fmt)
                except ValueError:
                    continue
        return val
        
    return val

def table_exists_in_sqlite(sq_conn, name):
    res = sq_conn.execute(
        text("SELECT name FROM sqlite_master WHERE type='table' AND name=:name"),
        {"name": name}
    ).fetchone()
    return res is not None

def migrate(sqlite_url: str, pg_url: str):
    print("--- Starting Database Migration: SQLite -> PostgreSQL ---")
    print(f"Source SQLite: {sqlite_url}")
    print(f"Target PostgreSQL: {pg_url}")
    
    # Create engines
    try:
        sqlite_engine = create_engine(sqlite_url)
        pg_engine = create_engine(pg_url)
        
        # Test connections
        with sqlite_engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        with pg_engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        print("Successfully connected to both databases.")
    except Exception as e:
        print(f"Error connecting to database engines: {e}", file=sys.stderr)
        sys.exit(1)

    # Reflect PostgreSQL metadata only
    try:
        pg_meta = MetaData()
        pg_meta.reflect(bind=pg_engine)
        print("Successfully reflected PostgreSQL table schemas.")
    except Exception as e:
        print(f"PostgreSQL Schema reflection failed: {e}", file=sys.stderr)
        sys.exit(1)

    # Topological table list to load dependencies correctly
    tables_order = [
        "users",
        "players",
        "teams",
        "team_players",
        "tournaments",
        "tournament_teams",
        "matches",
        "match_squads",
        "innings",
        "balls",
        "refresh_tokens"
    ]
    
    # Connect to PostgreSQL and execute migration
    try:
        with pg_engine.begin() as pg_conn:
            # 1. Disable constraints/triggers for the session to prevent order/cycle errors
            print("Temporarily disabling PostgreSQL triggers and constraints...")
            pg_conn.execute(text("SET session_replication_role = 'replica';"))
            
            # 2. Iterate and copy tables
            for table_name in tables_order:
                if table_name not in pg_meta.tables:
                    print(f"Table '{table_name}' not found in PostgreSQL metadata. Make sure migrations are run on PostgreSQL first.")
                    sys.exit(1)
                
                pg_table = pg_meta.tables[table_name]
                
                # Retrieve rows from SQLite using raw SQL
                with sqlite_engine.connect() as sq_conn:
                    if not table_exists_in_sqlite(sq_conn, table_name):
                        print(f"Table '{table_name}' not found in SQLite, skipping.")
                        continue
                    rows = sq_conn.execute(text(f"SELECT * FROM {table_name}")).mappings().all()
                
                if not rows:
                    print(f"Table '{table_name}': 0 records found in SQLite. Skipping import.")
                    continue
                
                print(f"Table '{table_name}': Migrating {len(rows)} records...")
                
                # Delete existing records in target to avoid primary key conflicts
                pg_conn.execute(pg_table.delete())
                
                # Map column values into a list of dictionaries with type conversions
                insert_data = []
                for row in rows:
                    row_dict = dict(row)
                    clean_row = {}
                    for col in pg_table.columns:
                        if col.name in row_dict:
                            clean_row[col.name] = convert_value(row_dict[col.name], col.type)
                    insert_data.append(clean_row)
                
                # Bulk insert into PostgreSQL
                pg_conn.execute(pg_table.insert(), insert_data)
                print(f"Table '{table_name}': Successfully imported {len(rows)} records.")
                
            # 3. Restore replication role to default (origin)
            print("Restoring PostgreSQL constraints and triggers...")
            pg_conn.execute(text("SET session_replication_role = 'origin';"))
            
        print("\n--- Migration Completed Successfully! ---")
        
    except Exception as e:
        import traceback
        print(f"\nMigration failed: {e}", file=sys.stderr)
        traceback.print_exc(file=sys.stderr)
        print("Undoing transaction and exiting.", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Migrate CricUP SQLite database to PostgreSQL.")
    parser.add_argument(
        "--sqlite-url",
        default="sqlite:///./cricket.db",
        help="Source SQLite connection URL (default: sqlite:///./cricket.db)"
    )
    parser.add_argument(
        "--pg-url",
        required=True,
        help="Target PostgreSQL connection URL (e.g. postgresql://user:pass@host:port/dbname)"
    )
    
    args = parser.parse_args()
    migrate(args.sqlite_url, args.pg_url)
