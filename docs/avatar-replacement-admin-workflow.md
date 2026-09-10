# Avatar replacement admin workflow

This workflow is private. Never move a user's original/reference photo to a public bucket, Discord channel, public ticket, or public URL.

## Intake

Every submitted request creates:

- a row in `public.avatar_replacement_requests`;
- a support-queue row in `public.contact_requests`;
- a private object in `avatar-replacement-submissions/<user-id>/<request-id>/submission.<ext>`;
- an in-game confirmation notification for the player.

The web client also posts the request metadata to the existing `tennis-legacy-contact` Netlify form so the configured Tennis Legacy support email notification can use the same channel as Contact Us. The source image itself is never attached and no signed/public source-image URL is sent by the client.

## Status changes

Use service-role/admin tooling only. Normal authenticated users do not have permission to call the admin RPCs.

Mark a request as being reviewed:

```sql
select public.admin_update_avatar_replacement_status_v1(
  '<request-id>'::uuid,
  'under_review',
  'We are reviewing your request.',
  'Optional internal admin note'
);
```

When work begins:

```sql
select public.admin_update_avatar_replacement_status_v1(
  '<request-id>'::uuid,
  'preparing',
  'Your replacement avatar is being prepared.',
  null
);
```

If the request cannot be processed, use status `rejected`. The user is notified and the private source image receives an immediate deletion target. Delete the private source object as part of closing the request.

## Accessing the private reference image

The bucket `avatar-replacement-submissions` is private and has no authenticated-user read policy. View/download the source image only through authorized Supabase Storage/admin tooling or another service-role process.

Do not paste a generated signed URL into user-visible notes, email, Discord, public issue trackers, or other public/shared channels.

## Preparing the replacement

Create the replacement avatar using the reference photo and the user's recorded jersey/appearance preferences, or review the user's own submitted candidate if `submission_type = 'candidate_avatar'`.

Upload the prepared replacement image to `player-avatars` using a unique path that will remain valid as the player's `players.image_path`, for example:

`<user-id>/approved/<request-id>.webp`

Then mark it ready for user review:

```sql
select public.admin_set_avatar_replacement_review_v1(
  '<request-id>'::uuid,
  '<player-avatars-object-path>',
  'Your replacement is ready for review.',
  'Optional internal admin note'
);
```

This does **not** change the active player avatar. It only exposes the prepared replacement in the player's authenticated review UI and sends an in-game notification.

## User decision

The player can:

- **Approve & apply** — the backend verifies the prepared object, updates `players.image_path`, marks the request completed, and queues the private reference image for immediate deletion.
- **Request revision** — up to two revision requests are allowed. The current avatar remains active throughout revisions.

The previous avatar is not replaced until the user explicitly approves the prepared replacement.

## Reference-photo retention

Completed or rejected requests set `reference_delete_after` immediately. The client attempts to remove the user-owned private source copy as soon as it sees the closed status; admins should delete it immediately as part of closing a request if it still exists.

After physically deleting the object from `avatar-replacement-submissions`, record that cleanup:

```sql
select public.admin_mark_avatar_reference_deleted_v1('<request-id>'::uuid);
```

`reference_deleted_at` is then visible in the request record for audit/retention tracking.

## Supported uploads

User submissions are limited to:

- JPEG/JPG
- PNG
- WEBP
- maximum 8 MB

SVG is deliberately not accepted because it can contain active/scriptable content. The client validates image signatures before upload and the private bucket also restricts MIME types and extensions.


## Identity and avatar rules

The submitted image must show the account holder or be a generated avatar based only on the account holder's own appearance. Another real person, celebrity or public figure is not permitted. Deliberate or repeated impersonation/abuse may lead to account suspension or removal.

Final avatars should use a pure white background, front-facing passport-style head/upper-shoulder framing, and the standard Tennis Legacy face alignment. Sport jerseys or polo shirts may use the player's requested colors, but final images should not contain logos, sponsors, brand marks, text, hats, sunglasses or distracting props.

New submissions must record both an identity attestation and a limited-processing consent. The consent is limited to processing the private file for the avatar request; do not reuse the source image for unrelated purposes or publish it to community channels. Minimal request/moderation metadata may be retained for security, legal or abuse-prevention needs after the image itself is removed.
