import bcrypt

hashed_pwd = b"$2b$12$kXHad0SLRVQxDgz9D/t2O.JBVfFj5wBeg0IQK954o3WBVTk83SaYq"
print("Verification of Password123:", bcrypt.checkpw(b"Password123", hashed_pwd))
print("Verification of Password123!:", bcrypt.checkpw(b"Password123!", hashed_pwd))
