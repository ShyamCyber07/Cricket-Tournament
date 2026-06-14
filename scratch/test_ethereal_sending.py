import smtplib
import imaplib
import email
from email.mime.text import MIMEText

def test_flow():
    # SMTP Settings
    smtp_host = "smtp.ethereal.email"
    smtp_port = 587
    user = "nafa6ilszojywomn@ethereal.email"
    password = "uH9TnpaUep3an3eFqx"
    
    # Recipient
    to_email = "cricup_e2e_test_random_999@example.com"
    
    # Send email
    print("Sending test email to:", to_email)
    msg = MIMEText("This is a test email with code: 123456")
    msg["Subject"] = "Test Subject"
    msg["From"] = f"CricUP <{user}>"
    msg["To"] = to_email
    
    try:
        server = smtplib.SMTP(smtp_host, smtp_port, timeout=10)
        server.starttls()
        server.login(user, password)
        server.sendmail(user, to_email, msg.as_string())
        server.quit()
        print("SMTP Send Success!")
    except Exception as e:
        print("SMTP Error:", e)
        return
        
    # Check IMAP
    print("Checking IMAP for sent email...")
    try:
        mail = imaplib.IMAP4_SSL("imap.ethereal.email", 993)
        mail.login(user, password)
        mail.select("inbox")
        status, data = mail.search(None, "ALL")
        mail_ids = data[0].split()
        print(f"Found {len(mail_ids)} messages in inbox.")
        
        for num in mail_ids:
            status, data = mail.fetch(num, "(RFC822)")
            raw_email = data[0][1]
            parsed_msg = email.message_from_bytes(raw_email)
            print("Message in Inbox:")
            print("  Subject:", parsed_msg["Subject"])
            print("  To:", parsed_msg["To"])
            print("  From:", parsed_msg["From"])
        mail.logout()
    except Exception as e:
        print("IMAP Error:", e)

if __name__ == "__main__":
    test_flow()
