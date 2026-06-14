import logging
import httpx
from datetime import datetime
from app.core.config import settings

logger = logging.getLogger(__name__)

def _send_via_api(to_email: str, subject: str, html_content: str) -> bool:
    url = "https://api.brevo.com/v3/smtp/email"
    headers = {
        "api-key": settings.BREVO_API_KEY,
        "Content-Type": "application/json",
        "accept": "application/json"
    }
    payload = {
        "sender": {
            "name": settings.BREVO_FROM_NAME,
            "email": settings.BREVO_FROM_EMAIL
        },
        "to": [
            {
                "email": to_email
            }
        ],
        "subject": subject,
        "htmlContent": html_content
    }
    
    print("[EMAIL API REQUEST STARTED]")
    logger.info("[EMAIL API REQUEST STARTED]")
    
    # Check if credentials are not configured in local environment
    is_production = settings.APP_ENV == "production"
    is_missing_credentials = (
        not settings.BREVO_API_KEY 
        or settings.BREVO_API_KEY == "uH9TnpaUep3an3eFqx"
        or "ethereal" in settings.BREVO_FROM_EMAIL
    )
    
    if is_missing_credentials and not is_production:
        logger.warning("Brevo API Key not configured. Fallback console output.")
        print(f"[EMAIL SERVICE WARNING] Brevo API Key missing. Email to {to_email} with subject '{subject}' NOT sent via API.")
        return True
        
    try:
        with httpx.Client(timeout=15.0) as client:
            response = client.post(url, headers=headers, json=payload)
            
            print(f"[EMAIL API RESPONSE STATUS] {response.status_code}")
            logger.info(f"[EMAIL API RESPONSE STATUS] {response.status_code}")
            
            if response.status_code in [200, 201, 202]:
                print("[EMAIL API SUCCESS]")
                logger.info("[EMAIL API SUCCESS]")
                return True
            else:
                print("[EMAIL API FAILURE]")
                logger.error(f"[EMAIL API FAILURE] Status: {response.status_code}, Body: {response.text}")
                return False
                
    except Exception as e:
        print("[EMAIL API FAILURE]")
        logger.error(f"[EMAIL API FAILURE] Error: {str(e)}")
        return False

def send_verification_otp(to_email: str, otp_code: str) -> bool:
    """
    Delivers a verification OTP email using Brevo Transactional Email REST API.
    """
    subject = "Verify your CricUP account"
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
            <p style="font-size: 16px; color: #9ca3af;">Use the following 6-digit verification code to complete your authorization:</p>
            
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
    return _send_via_api(to_email, subject, html_content)

def send_password_reset_otp(to_email: str, otp_code: str) -> bool:
    """
    Delivers a password reset OTP email using Brevo Transactional Email REST API.
    """
    subject = "Reset your CricUP password"
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
            <h2 style="margin-top: 0; color: #ffffff; font-size: 22px; font-weight: 800;">Reset your CricUP password</h2>
            <p style="font-size: 16px; color: #9ca3af;">Use the following 6-digit verification code to reset your password:</p>
            
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
    return _send_via_api(to_email, subject, html_content)
