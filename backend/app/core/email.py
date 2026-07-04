import os
import resend
from dotenv import load_dotenv

load_dotenv()

resend.api_key = os.environ.get("RESEND_API_KEY")
SENDER_EMAIL = os.environ.get("RESEND_SENDER_EMAIL", "Ella <hello@ella.navgurukul.org>")

def send_magic_link_email(to_email: str, token: str):
    if not resend.api_key:
        print(f"Warning: RESEND_API_KEY not set. Would have sent magic link to {to_email} with token {token}")
        return

    # In production, this should be the actual frontend or backend domain.
    backend_url = os.environ.get("BACKEND_URL", "http://localhost:8000").rstrip("/")
    magic_url = f"{backend_url}/auth/magic-link/verify?token={token}"

    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8">
    <style>
      body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f9fafb; margin: 0; padding: 0; }}
      .container {{ max-width: 500px; margin: 40px auto; background-color: #ffffff; border-radius: 12px; padding: 40px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05); }}
      .logo {{ font-size: 28px; font-weight: 800; color: #111827; text-align: center; margin-bottom: 24px; letter-spacing: -0.5px; }}
      .title {{ font-size: 20px; font-weight: 600; color: #111827; margin-bottom: 16px; text-align: center; }}
      .text {{ font-size: 16px; color: #4b5563; line-height: 1.5; margin-bottom: 32px; text-align: center; }}
      .button-container {{ text-align: center; margin-bottom: 32px; }}
      .button {{ display: inline-block; background-color: #4f46e5; color: #ffffff !important; font-weight: 600; font-size: 16px; text-decoration: none; padding: 14px 28px; border-radius: 8px; box-shadow: 0 2px 4px rgba(79, 70, 229, 0.3); }}
      .footer {{ font-size: 13px; color: #9ca3af; text-align: center; line-height: 1.5; border-top: 1px solid #f3f4f6; padding-top: 24px; }}
      .footer-link {{ color: #6b7280; text-decoration: underline; word-break: break-all; margin-top: 8px; display: inline-block; }}
    </style>
    </head>
    <body>
      <div class="container">
        <div class="logo">Ella</div>
        <div class="title">Log in to your account</div>
        <div class="text">Click the button below to securely log into your Ella account. This magic link will expire shortly.</div>
        <div class="button-container">
          <a href="{magic_url}" class="button">Log In to Ella</a>
        </div>
        <div class="footer">
          If you did not request this email, you can safely ignore it.<br><br>
          Or copy and paste this link into your browser:<br>
          <a href="{magic_url}" class="footer-link">{magic_url}</a>
        </div>
      </div>
    </body>
    </html>
    """

    try:
        r = resend.Emails.send({
            "from": SENDER_EMAIL,

            "to": to_email,
            "subject": "Log in to Ella",
            "html": html_content
        })
        print(f"Sent email to {to_email}: {r}")
    except Exception as e:
        print(f"Failed to send email: {e}")
