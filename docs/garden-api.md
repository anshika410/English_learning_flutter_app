# Garden API — Android Developer Reference

## Overview

The Garden is the student's visual progress map. Each CEFR level (A0→C1) is a
separate "garden" with its own theme. A garden contains units (steps), and each
unit contains skills. Skills have three states: **locked**, **emerging**, or **owned**.

When a student is placed at a higher level (e.g. B2), all lower-level gardens
(A0, A1, A2, B1) are automatically fully bloomed — every skill shows as `owned`.

---

## Endpoint

```
GET /users/me/garden
Authorization: Bearer <token>
```

### Optional query parameter

| Param   | Type   | Default         | Description                                      |
|---------|--------|-----------------|--------------------------------------------------|
| `level` | string | user's current level | View a specific level's garden (e.g. `?level=A1`). For levels below the user's current level, all skills return as `owned`. |

### Examples

```bash
# Current level garden (no param)
GET /users/me/garden

# View A1 garden (for a B2 user — all owned)
GET /users/me/garden?level=A1

# View current B2 garden explicitly
GET /users/me/garden?level=B2
```

---

## Response

```json
{
  "level": "B2",
  "recommended_topic": "What do you think about social media?",
  "placement_garden": {
    "stage": "bloom",
    "level": "B2",
    "confidence": "high"
  },
  "units": [
    {
      "unit": 1,
      "name": "Choosing words with more precision and feeling",
      "focus": "Moving from words that work to words that feel right.",
      "skills": [
        {
          "id": "U1-VOC-01",
          "strand": "VOC",
          "text": "I can use a wider range of descriptive words to make my ideas more interesting.",
          "status": "owned",
          "sightings": 3,
          "last_tested_at": "2026-07-14",
          "evidence": [
            {
              "evidence": "fascinating topic, widespread superstition",
              "confidence": 0.85,
              "prompted": false,
              "topic": "Science, superstition, and belief in modern India",
              "created_at": "2026-07-13T20:12:07+00:00"
            }
          ]
        }
      ]
    }
  ]
}
```

---

## Field Reference

### Top-level fields

| Field | Type | Description |
|-------|------|-------------|
| `level` | string | The level being shown (`A0`–`C1`) |
| `recommended_topic` | string | A suggested conversation starter based on the student's next skill target |
| `placement_garden` | object \| null | Placement badge info. `null` if student hasn't been placed yet |
| `units` | array | The units (steps) for this level, in order 1–5 |

### `placement_garden`

| Field | Type | Description |
|-------|------|-------------|
| `stage` | string | `"soil"` (no placement), `"seed"` (low confidence), `"bloom"` (high/medium confidence) |
| `level` | string | The level they were placed at |
| `confidence` | string | `"high"`, `"medium"`, or `"low"` |

### `units[]`

| Field | Type | Description |
|-------|------|-------------|
| `unit` | int | Unit number (1–5) |
| `name` | string | Unit display name |
| `focus` | string | Short description of what this unit is about |
| `skills` | array | Skills in this unit |

### `units[].skills[]`

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Skill ID, e.g. `U1-VOC-01` |
| `strand` | string | `VOC` (vocabulary), `GRA` (grammar), or `FLU` (fluency) |
| `text` | string | "I can…" skill description shown to the student |
| `status` | string | `"locked"`, `"emerging"`, or `"owned"` |
| `sightings` | int | How many times this skill has been seen at qualifying confidence |
| `last_tested_at` | string \| null | Date last seen, `YYYY-MM-DD` format |
| `evidence` | array | Up to 3 real quotes from the student's speech that demonstrate this skill |

### `evidence[]`

| Field | Type | Description |
|-------|------|-------------|
| `evidence` | string | Verbatim quote from what the student said |
| `confidence` | float | 0.0–1.0 — how strongly this demonstrates the skill |
| `prompted` | bool | `true` = Zoe set it up; `false` = student said it spontaneously |
| `topic` | string | The conversation topic this was recorded under |
| `created_at` | string | ISO datetime when this evidence was recorded |

---

## Skill Status — What to Show

| Status | Plant stage | Garden visual |
|--------|-------------|---------------|
| `locked` | Bare soil | No plant |
| `emerging` | Sprout / growing | Small plant (sightings 0 = sprout, ≥1 = growing) |
| `owned` | Full bloom | Fully bloomed flower |

For **sightings** within `emerging`: use it to distinguish sprout vs growing plant:
- `sightings == 0` → sprout stage
- `sightings >= 1` → growing stage
- `status == owned` → always bloom (ignore sightings)

---

## Level Switcher (Garden Dropdown)

The student can browse previous gardens. Use the `?level=` param:

1. Fetch `GET /users/me/garden` (no param) → get current level + `level` field
2. Build dropdown from: `A0 → A1 → A2 → B1 → B2 → C1`, up to and including the current level
3. When user picks a previous level, call `GET /users/me/garden?level=A1`
4. All skills in previous levels return as `owned` — render them all as fully bloomed
5. The "next" level (one above current) can be shown as locked/fogged if desired

### Garden names per level

| Level | Garden name |
|-------|-------------|
| A0 | Dawn Glade |
| A1 | Morning Meadow |
| A2 | Midday Grove |
| B1 | Golden Orchard |
| B2 | Twilight Valley |
| C1 | Starlight Summit |

---

## Auth

All garden endpoints require a valid JWT in the `Authorization` header:

```
Authorization: Bearer <access_token>
```

Get the token from `POST /auth/google` (Google Sign-In) or `POST /auth/magic-link/verify`.

---

## Refresh After Session

After a conversation session ends, call `GET /users/me/garden` again (no param) to
get updated skill states. The backend runs session analysis which may have moved
skills from `locked → emerging` or `emerging → owned`. Always refresh after a session
to show the student any garden growth.

---

## Live API Docs

Interactive Swagger UI: [https://ella.navgurukul.org/api/docs](https://ella.navgurukul.org/api/docs)
