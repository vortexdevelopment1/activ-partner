# Signed agreement email setup

Finish sends from **no-reply@activ.co.in** via MSG91 to the saved partner email.
Replies go to support@activ.live. The signed PDF is attached directly as base64.

Open MSG91 → Email → Templates → Create Template → HTML & Text Editor.
Suggested name: `partneragreementsigned`.

Subject: **Your electronically signed ACTIV Partnership Agreement**

Add variables with MSG91's **Add Variable** control, retaining these exact names:
`partnerName`, `venueName`, `signedAt`, `supportEmail`. Use the editor's inserted
placeholder syntax if it differs from the example below.

```html
<div style="font-family:Arial,sans-serif;color:#222;line-height:1.6;">
  <h2>Your signed partnership agreement</h2>
  <p>Hello {{partnerName}},</p>
  <p>You electronically signed the ACTIV Partnership Agreement for
     <strong>{{venueName}}</strong> on <strong>{{signedAt}}</strong>.</p>
  <p>A copy of your signed partnership agreement is attached for your records.</p>
  <p>We will contact you with updates about your venue review.</p>
  <p>For any questions, contact {{supportEmail}}.</p>
  <p>ACTIV Partner Team</p>
</div>
```

Save and submit for approval. Copy its actual template ID to `activ-backend/.env`:

```dotenv
MSG91_AGREEMENT_TEMPLATE_ID=your_actual_approved_template_id
```

Keep the existing MSG91 auth key, sender and domain configuration. The agreement
sender is no-reply@activ.co.in; the sender/domain must be authorized in MSG91.
Agreement emails are temporarily bypassed by default. Finish still saves the
signature and submits the venue for admin review. Once the template is ready,
set `SIGNED_AGREEMENT_EMAIL_ENABLED=true` alongside the template ID.
Restart the backend, then retry Finish. Gmail SMTP credentials are not used.
Submissions completed during the bypass will not automatically send emails later.

References:
- [Template creation](https://msg91.com/help/transactional-email/how-to-create-a-transactional-email-template-with-api-integration-detail/)
- [Email API and base64 attachments](https://msg91.com/help/email/how-to-send-the-crqid-via-email-api)
