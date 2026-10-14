# ActivProduct Backend — API Reference

> **Base URL (staging):** `https://staging-be.activ.co.in/api/v1`
> **Auth:** All protected routes require `Authorization: Bearer <jwt_token>`
> **Global response shape:**
> ```json
> { "success": true, "statusCode": 200, "message": "...", "data": {}, "timestamp": "" }
> ```

---

## Auth — `/api/v1/auth`

| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| POST | `/auth/partner/register` | None | Register new partner |
| POST | `/auth/partner/login` | None | Partner login → JWT |
| POST | `/auth/admin/login` | None | Admin login → JWT |

---

## Partners — `/api/v1/partners`

| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| POST | `/partners` | Admin | Create partner |
| GET | `/partners` | Admin | List all partners (paginated) |
| GET | `/partners/profile` | Partner JWT | Get own profile |
| GET | `/partners/:id` | Admin | Get partner by ID |
| PATCH | `/partners/avatar` | Partner JWT | Upload / update avatar (multipart) |
| PATCH | `/partners/legal` | Partner JWT | Update Aadhaar / PAN / GST docs directly |
| PATCH | `/partners/profile` | Partner JWT | Update own profile |
| PATCH | `/partners/:id` | Admin | Update any partner |
| PATCH | `/partners/:id/verify` | Admin | Mark partner as verified |
| PATCH | `/partners/:id/toggle-status` | Admin | Toggle active status |
| DELETE | `/partners/account` | Partner JWT | Delete own account |
| DELETE | `/partners/:id` | Admin | Delete partner by ID |

### GST Verification Flow — `/api/v1/partners/gst-verification`

> Partner submits GST details → saved as **pending** → Admin approves/rejects → On approve, data is written to the `partners` table and the request is deleted.

| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| POST | `/partners/gst-verification` | Partner JWT | Submit GST number, name, doc (multipart/form-data) |
| GET | `/partners/gst-verification/my` | Partner JWT | View own latest request + status |
| GET | `/partners/gst-verification` | Admin | List all requests (paginated, filter by `?status=`) |
| GET | `/partners/gst-verification/:id` | Admin | Get single request by ID |
| PATCH | `/partners/gst-verification/:id/approve` | Admin | Approve → writes to partner row + deletes request |
| PATCH | `/partners/gst-verification/:id/reject` | Admin | Reject → `status=rejected` + `adminNotes` |

**POST payload (multipart/form-data):**
| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `gstNumber` | string | ✅ | Must match GST format regex |
| `gstName` | string | ✅ | Registered business name on GST |
| `gstDoc` | file | ❌ | JPG / JPEG / PNG / PDF, max 10 MB |

**Status values:** `pending` · `approved` · `rejected`

**Business rules:**
- A partner with an existing `pending` request cannot submit another — returns `409 Conflict`
- Approve/Reject actions only work on `pending` requests — returns `400` otherwise
- On **approve**: `gstNumber`, `gstName`, `gstinDocUrl` written to `partners` row, request row deleted
- On **reject**: row kept with `status = rejected`, partner can then resubmit

---

## Users — `/api/v1/users`

| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| POST | `/users` | Admin | Create user |
| GET | `/users` | Admin | List all users (paginated) |
| GET | `/users/:id` | Admin | Get user by ID |
| PATCH | `/users/:id` | Admin | Update user |
| DELETE | `/users/:id` | Admin | Delete user |

---

## Categories — `/api/v1/categories`

| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| POST | `/categories` | Admin | Create category (multipart — image upload) |
| GET | `/categories` | None | List all categories (public) |
| GET | `/categories/:id` | None | Get category by ID (public) |
| PATCH | `/categories/:id` | Admin | Update category |
| DELETE | `/categories/:id` | Admin | Delete category |

---

## Venues — `/api/v1/venues`

| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| POST | `/venues` | Partner JWT | Create venue (status = pending) |
| GET | `/venues` | None | List all approved venues (public) |
| GET | `/venues/my` | Partner JWT | Partner's own venues |
| GET | `/venues/:id` | None | Get venue details (public) |
| PATCH | `/venues/:id` | Partner JWT | Update own venue |
| PATCH | `/venues/:id/approve` | Admin | Approve venue |
| PATCH | `/venues/:id/reject` | Admin | Reject venue (with reason) |
| DELETE | `/venues/:id` | Partner JWT / Admin | Delete venue |
| POST | `/venues/:id/images` | Partner JWT | Upload venue images |
| DELETE | `/venues/:id/images/:imageId` | Partner JWT | Delete venue image |
| POST | `/venues/:id/services` | Partner JWT | Add service to venue |
| PATCH | `/venues/:id/services/:serviceId` | Partner JWT | Update service |
| DELETE | `/venues/:id/services/:serviceId` | Partner JWT | Delete service |

### Venue Update Requests — `/api/v1/venues/update-requests`

> Partner submits changes → saved as **pending** → Admin approves/rejects → On approve, changes applied to `venues` table and request deleted.

| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| POST | `/venues/:id/update-request` | Partner JWT | Submit venue info update request |
| GET | `/venues/update-requests/my` | Partner JWT | View own requests (all statuses) |
| GET | `/venues/update-requests` | Admin | All requests (paginated, filter by `?status=`) |
| GET | `/venues/update-requests/:requestId` | Admin | Get single request |
| PATCH | `/venues/update-requests/:requestId/approve` | Admin | Approve → apply to venue + delete request |
| PATCH | `/venues/update-requests/:requestId/reject` | Admin | Reject → `status=rejected` + `adminNotes` |

**POST payload (JSON — all fields optional, at least one should be provided):**
| Field | Type | Notes |
|-------|------|-------|
| `name` | string | Venue name |
| `description` | string | Venue description |
| `address` | string | Street address |
| `city` | string | City |
| `state` | string | State |
| `zipCode` | string | PIN / ZIP code |
| `flatBuilding` | string | Flat / building details |
| `latitude` | number | GPS latitude |
| `longitude` | number | GPS longitude |
| `locationUrl` | string | Google Maps link |

**Status values:** `pending` · `approved` · `rejected`

**Business rules:**
- Partner can only submit for their own venue — returns `403` otherwise
- A venue with an existing `pending` request cannot have another submitted — returns `409 Conflict`
- Approve/Reject only work on `pending` requests — returns `400` otherwise
- On **approve**: only the submitted fields are written to the `venues` row; unset fields are left unchanged. Request row is deleted
- On **reject**: row kept with `status = rejected`; partner can resubmit

---

## Bookings — `/api/v1/bookings`

| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| POST | `/bookings` | User JWT | Create booking |
| GET | `/bookings` | Admin | List all bookings (paginated, filter by `?status=`) |
| GET | `/bookings/my-bookings` | User JWT | Own bookings |
| GET | `/bookings/venue/:venueId` | Partner / Admin | Bookings for a venue |
| GET | `/bookings/stats` | Admin / Partner | Booking statistics |
| GET | `/bookings/reference/:reference` | Any JWT | Get by reference number |
| GET | `/bookings/:id` | Any JWT | Get by ID |
| PATCH | `/bookings/:id/cancel` | Any JWT | Cancel booking |
| PATCH | `/bookings/:id/confirm` | Admin / Partner | Confirm booking |
| PATCH | `/bookings/:id/complete` | Admin / Partner | Mark as completed |

---

## Payments — `/api/v1/payments`

| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| POST | `/payments/create-order` | User JWT | Create Razorpay order |
| POST | `/payments/verify` | User JWT | Verify payment signature |

---

## Legal — `/api/v1/legal`

> Content types: `terms_and_conditions` · `privacy_policy` · `partner_agreement`

| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| PUT | `/legal/:type` | Admin | Create or update legal content |
| GET | `/legal` | None | Get all legal content (public) |
| GET | `/legal/:type` | None | Get content by type (public) |

---

## Support — `/api/v1/support`

### Callback Requests

| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| POST | `/support/callback` | Partner JWT | Submit callback request |
| GET | `/support/callback` | Admin | List all (paginated, filter by `?status=`) |
| GET | `/support/callback/:id` | Admin | Get single request |
| PATCH | `/support/callback/:id` | Admin | Update status / adminNotes |
| DELETE | `/support/callback/:id` | Admin | Delete request |

**POST payload (JSON):**
| Field | Type | Required |
|-------|------|----------|
| `partnerName` | string | ✅ |
| `email` | string (email) | ✅ |
| `phone` | string | ✅ |
| `venueName` | string | ✅ |
| `city` | string | ✅ |
| `callbackDate` | string (YYYY-MM-DD) | ✅ |
| `callbackTime` | string (e.g. "10:00 AM") | ✅ |
| `query` | string | ✅ |

### Email Support

| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| POST | `/support/email` | Partner JWT | Submit support email + optional attachment |
| GET | `/support/email` | Admin | List all (paginated, filter by `?status=`) |
| GET | `/support/email/:id` | Admin | Get single email |
| PATCH | `/support/email/:id` | Admin | Update status / adminNotes |
| DELETE | `/support/email/:id` | Admin | Delete email |

**POST payload (multipart/form-data):**
| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `subject` | string | ✅ | |
| `message` | string | ✅ | |
| `attachment` | file | ❌ | JPG / JPEG / PNG / PDF, max 10 MB |

**Status values (both support types):** `pending` · `in_progress` · `contacted` · `resolved` · `closed`

---

## FAQs — `/api/v1/faqs`

| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| GET | `/faqs/public` | **None** | All active FAQs (for partner app) |
| POST | `/faqs` | Admin | Create FAQ |
| GET | `/faqs` | Admin | List all (paginated + search) |
| GET | `/faqs/:id` | Admin | Get FAQ by ID |
| PATCH | `/faqs/:id` | Admin | Update FAQ |
| DELETE | `/faqs/:id` | Admin | Delete FAQ |

---

## Location — `/api/v1/location`

| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| GET | `/location/states` | None | List all states |
| GET | `/location/cities` | None | List cities by state |

---

## Team — `/api/v1/team`

| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| POST | `/team` | Partner JWT | Add team member |
| GET | `/team` | Partner JWT | List own team members |
| PATCH | `/team/:id` | Partner JWT | Update team member |
| DELETE | `/team/:id` | Partner JWT | Remove team member |

---

## Bank Accounts — `/api/v1/bank-accounts`

| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| POST | `/bank-accounts` | Partner JWT | Add bank account |
| GET | `/bank-accounts` | Partner JWT | Get own bank account |
| PATCH | `/bank-accounts/:id` | Partner JWT | Update bank account |

---

## Commission — `/api/v1/commission`

| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| GET | `/commission` | Admin | View commission settings |
| PATCH | `/commission` | Admin | Update commission rate |

---

## Questions — `/api/v1/questions`

| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| POST | `/questions` | Admin | Create question |
| GET | `/questions` | Admin | List all questions |
| GET | `/questions/category/:categoryId` | None | Questions by category (public) |
| PATCH | `/questions/:id` | Admin | Update question |
| DELETE | `/questions/:id` | Admin | Delete question |

---

*Last updated: 2026-06-07*
