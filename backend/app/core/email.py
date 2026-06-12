import smtplib
import logging
from datetime import datetime
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from app.core.config import settings

logger = logging.getLogger(__name__)

def send_otp_email(to_email: str, otp_code: str, subject: str = "Verify your CricUP account") -> bool:
    """
    Delivers a branded verification OTP email via Brevo SMTP.
    If credentials are not configured, logs a warning and prints OTP to console if not in production.
    Does not expose OTP value in logs or stdout when APP_ENV is 'production'.
    """
    is_production = settings.APP_ENV == "production"

    # If SMTP credentials are not configured, perform console fallback in non-production
    if not settings.BREVO_SMTP_USER or not settings.BREVO_SMTP_PASSWORD:
        logger.warning(f"Brevo SMTP credentials are not configured. Email to {to_email} NOT sent.")
        if not is_production:
            print(f"[EMAIL SERVICE WARNING] Brevo credentials missing. OTP for {to_email} is: {otp_code}")
        return False

    try:
        # Create message container
        msg = MIMEMultipart('alternative')
        msg['Subject'] = subject
        msg['From'] = f"CricUP <{settings.BREVO_FROM_EMAIL}>"
        msg['To'] = to_email

        # HTML branded template
        current_year = datetime.now().year
        html_content = f"""
        <html>
          <body style="font-family: Arial, sans-serif; background-color: #0b0f19; padding: 20px; margin: 0; color: #ffffff;">
            <div style="max-width: 600px; margin: 0 auto; background-color: #111827; border-radius: 16px; overflow: hidden; border: 1px solid #1f2937;">
              <!-- Header -->
              <div style="background-color: #00e676; padding: 30px; text-align: center;">
                <h1 style="color: #000000; margin: 0; font-size: 32px; font-weight: 900; letter-spacing: -1px;">Cric<span style="color: #ffffff;">UP</span></h1>
              </div>
              
              <!-- Content -->
              <div style="padding: 40px 30px; line-height: 1.6; color: #d1d5db;">
                <h2 style="margin-top: 0; color: #ffffff; font-size: 22px; font-weight: 800;">Verify your CricUP account</h2>
                <p style="font-size: 16px; color: #9ca3af;">Use the following 6-digit verification code to complete your authorization or reset your password:</p>
                
                <div style="text-align: center; margin: 30px 0;">
                  <span style="display: inline-block; background-color: #1f2937; padding: 15px 35px; font-size: 38px; font-weight: 800; letter-spacing: 6px; color: #00e676; border-radius: 8px; border: 1px solid #374151;">{otp_code}</span>
                </div>
                
                <p style="font-size: 14px; color: #9ca3af;">This code expires in <strong style="color: #ffffff;">10 minutes</strong>.</p>
                <p style="font-size: 14px; color: #ef4444; font-weight: bold; margin-bottom: 0;">Do not share this code with anyone.</p>
              </div>
              
              <!-- Footer -->
              <div style="background-color: #0f172a; padding: 20px; text-align: center; border-top: 1px solid #1f2937;">
                <p style="font-size: 12px; color: #6b7280; margin: 0;">&copy; {current_year} CricUP. All rights reserved.</p>
              </div>
            </div>
          </body>
        </html>
        """
        
        # Record the MIME type
        part = MIMEText(html_content, 'html')
        msg.attach(part)
        
        # Connect to SMTP server and send
        logger.info(f"Connecting to Brevo SMTP server to send email to {to_email}...")
        server = smtplib.SMTP(settings.BREVO_SMTP_HOST, settings.BREVO_SMTP_PORT, timeout=10)
        server.starttls()
        server.login(settings.BREVO_SMTP_USER, settings.BREVO_SMTP_PASSWORD)
        server.sendmail(settings.BREVO_FROM_EMAIL, to_email, msg.as_string())
        server.quit()
        
        logger.info(f"Verification email successfully sent to {to_email}")
        
        # In non-production environments, print verification details for ease of local testing
        if not is_production:
            print(f"[EMAIL SERVICE SUCCESS] Real OTP sent via Brevo to {to_email}. Code is: {otp_code}")
            
        return True
    except Exception as e:
        logger.error(f"Failed to send email to {to_email}: {str(e)}")
        # Print fallback in console in development mode if connection failed
        if not is_production:
            print(f"[EMAIL SERVICE ERROR] Brevo API/SMTP connection failed. Fallback OTP for {to_email} is: {otp_code}")
        return False
