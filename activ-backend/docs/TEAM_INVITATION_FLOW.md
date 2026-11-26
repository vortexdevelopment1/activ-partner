# Partner team invitations

Partners use **Manage Team → New Member** to enter a name, mobile number,
designation, and booking-management permission. Team invites are sent by SMS.

All team management endpoints require a partner JWT and scope records to that
partner. Designations such as “manager” do not grant additional permissions.

- POST /team creates the member and attempts SMS after the account is saved.
- PATCH /team/:id updates member details and permissions. Partners may change
  a phone number only for an account created through team management.
- POST /team/:id/invite resends an invitation for an owned member who has yet
  to join. Resends are limited to once per minute and generate a fresh password.
- GET /team lists members and their last SMS invitation status.
- DELETE /team/:id removes access and invalidates the member’s team tokens.

Each invite generates an eight-character alphanumeric password. The API stores
its bcrypt hash and passes the password to MSG91 after the transaction commits.
The API never returns the password. Members can also sign in with a phone OTP.

The invitation result uses invitationDelivery.smsSent. Invite Sent means MSG91
accepted the request. Invite Pending means acceptance was unconfirmed. The
member becomes Active after a successful sign-in.

The MSG91 configuration uses MSG91_AUTHKEY and MSG91_TEAM_INVITE_TEMPLATE_ID.
For the invite SMS, var1 is the ten-digit mobile number and var2 is the
temporary password. SMS failures can be retried using the resend endpoint.
