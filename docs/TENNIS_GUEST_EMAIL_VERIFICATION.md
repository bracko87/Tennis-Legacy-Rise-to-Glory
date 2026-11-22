# Tennis Legacy – Guest conversion email delivery and redirect checklist

The guest registration frontend requests the official Supabase email-change verification via `supabase.auth.updateUser({email}, {emailRedirectTo})`. It does not send an independent email. The app can confirm that Supabase accepted an API request, but **cannot claim that a message was delivered**.

## One-time Supabase Auth configuration to verify

Project: Tennis Legacy (`cwfznmroiqcyhfkfcrow`).

1. Open **Authentication → Providers → Email**. Make sure **Confirm email** is enabled if every email-linked guest must verify mailbox ownership. Review **Secure email change** behaviour. Do not turn off account confirmation just to make the UI advance.
2. Open **Authentication → URL Configuration**. Keep the existing Site URL and all existing allowed redirect URLs. Ensure **`https://tennislegacygame.com/guest/register`** is explicitly allowed for the email change confirmation and Google identity linking callbacks. Preserve any existing password-reset redirects.
3. Open **Authentication → Email Templates → Change Email Address**. Configure the subject and template below; this is the message used by `updateUser({email})`, *not* the Sign Up confirmation template.
4. Under **Authentication → SMTP Settings**, verify a production-capable sender, a verified sending domain, and delivery logs. The default service can have email quotas and restrictions. Verify SPF/DKIM with the sending provider. Do not assume successful Auth API response equals inbox delivery.
5. Test using an existing **designated guest test account** and a mailbox not already assigned to another Tennis Legacy account. Ask for verification once, inspect inbox/spam and SMTP logs, click the link **in the same browser**, ensure the same auth user ID is retained, set a password, confirm the redirect to the original player and preserved progress. Test a Google account already used on a different game account; it must show a clear error rather than merging careers.

## Subject

Confirm your Tennis Legacy account email

## Change Email Address template (HTML)

```html
<!doctype html>
<html lang="en">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1"></head>
<body style="margin:0;padding:24px;background:#f4f7fa;color:#142235;font-family:Arial,Helvetica,sans-serif">
  <table role="presentation" cellpadding="0" cellspacing="0" style="width:100%;max-width:560px;margin:auto;background:#ffffff;border:1px solid #dce5ec;border-radius:12px">
    <tr><td style="padding:28px 30px 10px">
      <p style="margin:0;color:#0b5ea8;font-size:12px;font-weight:bold;letter-spacing:1px">TENNIS LEGACY · RISE TO GLORY</p>
      <h1 style="font-size:25px;line-height:1.25;margin:18px 0 12px;color:#142235">Save your tennis career</h1>
      <p style="font-size:15px;line-height:1.6">Confirm this email address to finish converting your Guest Player to a permanent Tennis Legacy account. Your player, tournaments, equipment and progress stay with the same career.</p>
      <p style="margin:28px 0"><a href="{{ .ConfirmationURL }}" style="display:inline-block;background:#1678c8;color:#fff;padding:14px 24px;border-radius:7px;text-decoration:none;font-weight:bold">Verify my email address</a></p>
      <p style="font-size:13px;line-height:1.5;color:#536c80">Open the link in the same browser where you played as a guest. After verification, return to Tennis Legacy to finish setting your password.</p>
      <p style="font-size:12px;line-height:1.5;color:#536c80;word-break:break-all">If the button does not work, open this URL: {{ .ConfirmationURL }}</p>
    </td></tr>
    <tr><td style="padding:18px 30px;border-top:1px solid #e6edf1;font-size:12px;color:#718696">You received this because someone requested to link this email address to a Tennis Legacy account. If this wasn't you, ignore this message.</td></tr>
  </table>
</body>
</html>
```

## Frontend behaviour

- On an email update request, check the server-reported conversion state. If immediately linked, proceed directly to the password step; don't claim an email was sent.
- Otherwise, show a pending verification panel with the requested address, resend and change-address buttons; preserve it across a refresh in the same browser.
- OAuth callback failures, including Google identity already linked elsewhere, must be shown rather than discarded.
- After permanent conversion, display a success message and redirect to the original game career.
- Real email sending, callback completion and delivered mail must still be verified through an actual mailbox and the email provider; no test was sent by this document.

Status: template and checklist prepared; changing the project-level Auth/SMTP dashboard settings is not supported through the connected Supabase tools, so it is **not claimed to be applied**.
