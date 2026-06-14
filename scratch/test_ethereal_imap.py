import imaplib
import email
import re

def test_imap():
    user = "nafa6ilszojywomn@ethereal.email"
    password = "uH9TnpaUep3an3eFqx"
    host = "imap.ethereal.email"
    
    print("Connecting to Ethereal IMAP...")
    try:
        mail = imaplib.IMAP4_SSL(host, 993)
        mail.login(user, password)
        mail.select("inbox")
        status, data = mail.search(None, "ALL")
        mail_ids = data[0].split()
        print(f"Connection success! Found {len(mail_ids)} messages in Ethereal inbox.")
        
        for num in mail_ids:
            status, data = mail.fetch(num, "(RFC822)")
            raw_email = data[0][1]
            msg = email.message_from_bytes(raw_email)
            print("Subject:", msg["Subject"])
            print("From:", msg["From"])
            body = ""
            if msg.is_multipart():
                for part in msg.walk():
                    if part.get_content_type() == "text/plain":
                        body = part.get_payload(decode=True).decode()
            else:
                body = msg.get_payload(decode=True).decode()
            print("Body snippet:", body[:100])
        mail.logout()
    except Exception as e:
        print("IMAP Error:", e)

if __name__ == "__main__":
    test_imap()
