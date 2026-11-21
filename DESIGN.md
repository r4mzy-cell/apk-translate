# DESIGN.md

> Design direction for this project. Fill this in before building UI. This file gives the design its **soul** — identity, personality, palette, typography, mood. antislop is a filter that applies on top of this.

---

## Product Identity

**Product name:** TranslateID

**One-sentence description:** Offline English↔Indonesian translator with formal/slang toggle, camera OCR, conversation mode, and screen translation overlays.

**Target audience:** Personal use + sharing with friends; travelers, language learners, expats in Indonesia.

**Core value proposition:** Zero internet, zero tracking, zero ads, full offline.

---

## Brand Personality

**Keywords (3-5):** practical, trustworthy, minimal, local-first

**Tone of voice:** helpful, concise, respectful

**Visual personality (e.g., technical, warm, bold, calm, playful):** calm, functional, teal accent

---

## Palette

**Primary color (hex):** `#00897B` (Teal 700)

**Secondary color (hex):** `#26A69A` (Teal 400)

**Accent color (hex):** `#FF9800` (Orange 500)

**Neutral base (white/black/grey scale):** Material 3 grey scales (surface, onSurface, surfaceVariant, outline, etc.)

> Max 2-3 core colors + 1 accent (R-29). Neutral colors don't count as core.

---

## Typography

**Sans-serif font family:** `Inter` (via Google Fonts) / system default (Roboto on Android)

**Monospace font family:** `JetBrains Mono`

**Reason for these choices:** Readability for bilingual text, developer-friendly, system default ensures performance and consistency.

> Choose typeface based on brand character, not AI default (R-06).

---

## Visual Language / Mood

**Visual references (links or descriptions):** Material 3 design system, clean card-based layouts, teal accent on neutral backgrounds.

**Mood board direction:** Calm, utilitarian, focused on text clarity. No decorative gradients or heavy shadows.

**Energy level (1-3):** 2 (Balanced)

**Rhythm level (1-3):** 2 (Balanced)

**Motion level (1-3):** 1 (Calm)

> Dials: ENERGY / RHYTHM / MOTION — see Part 3 of antislop.md

---

## Dial Declaration (Optional)

If you want to set dials explicitly:

```
Dial: ENERGY 2 / RHYTHM 2 / MOTION 1
```

Where each is 1 (Calm), 2 (Balanced), or 3 (Bold).

---

## Component Direction (Optional)

**Button style:** Filled teal (#00897B), rounded 12dp, Material 3 elevation, no outline. Text: white, 14sp, medium.

**Card style:** Elevated 2dp, rounded 16dp, surface color, subtle shadow. Internal padding 16dp.

**Form style:** Outlined input fields, dense (vertical padding 8dp), teal focus ring, label floats on focus. Error: red outline + helper text.

**Navigation style:** Bottom navigation bar, 5 tabs (Home, Translate, Conversation, Phrasebook, History, Settings), teal active icon, grey inactive. Top app bar only on detail pages.

**Icon style:** Material Symbols Outlined (rounded variant where available), 24dp, teal for primary actions.

---

## What This Project Is NOT

**Do not clone:** Google Translate UI (too complex), Microsoft Translator (too enterprise), generic template apps.

**Avoid these patterns:** 
- Hamburger menus (use bottom nav)
- Onboarding carousels (use contextual hints)
- Ads, analytics, tracking (strictly none)
- Internet-dependent features (everything offline-first)
- Loading skeletons on cached content

**Forbidden colors/styles:** 
- Red as primary (use only for destructive actions)
- Gradients on primary surfaces
- Heavy drop shadows (elevation 1-2 only)
- Serif fonts for body text

---

## Notes

Write any additional direction here. This is your design brief — the agent reads it as data, not commands.

- Indonesian formality distinction (Anda vs lu/gue) is a core UX differentiator — make the toggle prominent but unobtrusive.
- Screen translation overlays must be lightweight, non-intrusive, and easily dismissible.
- Camera OCR overlay should feel like a viewfinder, not a separate mode.
- Conversation mode UI mirrors messaging apps (bubbles, timestamps, speaker labels).
- All settings persist locally; no cloud sync, no accounts.