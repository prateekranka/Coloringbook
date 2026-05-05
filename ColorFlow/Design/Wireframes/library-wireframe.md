# Library Tab — Wireframe

## Layout Hierarchy

```
┌─────────────────────────────────────────────────────────┐
│  🔍 Search templates...                                 │  ← Search bar (prominent)
├─────────────────────────────────────────────────────────┤
│  [All] [Mandalas] [Animals] [Architecture] [Abstract]   │  ← Category pills
│       [Botanicals] [Lifestyle] [Popular] [New]          │    (scrollable)
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐      │
│  │ ┌─────┐ │ │ ┌─────┐ │ │ ┌─────┐ │ │ ┌─────┐ │      │
│  │ │     │ │ │ │     │ │ │ │     │ │ │ │     │ │      │  ← Adaptive grid
│  │ │ img │ │ │ │ img │ │ │ │ img │ │ │ │ img │ │      │    Min card: 180pt
│  │ │     │ │ │ │     │ │ │ │     │ │ │ │     │ │      │    Gap: 14pt
│  │ └─────┘ │ │ └─────┘ │ │ └─────┘ │ │ └─────┘ │      │
│  │ ♡ Name  │ │ ♡ Name  │ │ ♡ Name  │ │ ♡ Name  │      │  ← Name + favorite icon
│  │ ⭐ Easy │ │ ⭐ Med  │ │ ⭐ Hard │ │ ⭐ Easy │      │  ← Difficulty pill
│  └─────────┘ └─────────┘ └─────────┘ └─────────┘      │
│                                                         │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐      │
│  │ ┌─────┐ │ │ ┌─────┐ │ │ ┌─────┐ │ │ ┌─────┐ │      │
│  │ │     │ │ │ │     │ │ │ │     │ │ │ │     │ │      │
│  │ │ img │ │ │ │ img │ │ │ │ img │ │ │ │ img │ │      │
│  │ │     │ │ │ │     │ │ │ │     │ │ │ │     │ │      │
│  │ └─────┘ │ │ └─────┘ │ │ └─────┘ │ │ └─────┘ │      │
│  │ ♡ Name  │ │ ♡ Name  │ │ ♡ Name  │ │ ♡ Name  │      │
│  │ ⭐ Easy │ │ ⭐ Med  │ │ ⭐ Hard │ │ ⭐ Easy │      │
│  └─────────┘ └─────────┘ └─────────┘ └─────────┘      │
│                                                         │
├─────────────────────────────────────────────────────────┤
│  [🏠 Home]    [📚 Library]    [👤 My Work]              │  ← Tab bar
└─────────────────────────────────────────────────────────┘
```

## Card Detail

```
┌─────────────────────────┐
│ ┌─────────────────────┐ │  ← White card face
│ │                     │ │    Corner radius: Radius.md (12)
│ │                     │ │    Aspect ratio: 1:1
│ │    TEMPLATE IMAGE   │ │    Padding: 10pt inside card
│ │                     │ │
│ │                     │ │
│ └─────────────────────┘ │
│ ♡ Lotus Mandala         │  ← Name + favorite icon
│ ⭐ Easy                 │  ← Difficulty pill (colored capsule)
└─────────────────────────┘

Card shadow:
  .shadow(color: .black.opacity(0.25), radius: 4, y: 2)

Favorite icon:
  - System image: heart / heart.fill
  - Size: 14pt
  - Color: Ink.secondary (unfilled), .red (filled)
  - Tap target: 44pt (invisible)
```

## Spacing Specs

| Element | Spacing | Token |
|---------|---------|-------|
| Search bar padding | 16pt horizontal | `Spacing.xl` |
| Category bar height | 46pt | fixed |
| Category pill padding | 14pt horizontal, 12pt vertical | fixed |
| Category pill gap | 0pt (edge-to-edge) | — |
| Grid padding | 16pt all sides | `Spacing.xl` |
| Grid column gap | 14pt | fixed |
| Grid row gap | 14pt | fixed |
| Min card width | 180pt | fixed |
| Card corner radius | 12pt | `Radius.md` |
| Card image padding | 10pt inside card | fixed |
| Card shadow | radius 4, y 2, opacity 0.25 | fixed |

## Category Bar Detail

```
┌─────────────────────────────────────────────────────────┐
│  [All] [Mandalas] [Animals] [Architecture] ...          │
│   ──    ────────                                        │
│   ↑      ↑                                             │
│   │      └── Underline indicator (2pt, accent color)    │
│   └── Selected state: .bold(), accent color             │
│       Unselected: .regular(), Ink.secondary             │
└─────────────────────────────────────────────────────────┘
```

## Key Changes from Current

1. **Favorite icon**: Add heart icon to each card (tap to favorite)
2. **Category pills**: Add "Popular" and "New" filter options
3. **Card design**: Keep white card face but make image fill more of it
4. **Search**: Make more prominent (always visible, not just in nav drawer)
5. **Grid**: Same adaptive layout, tighter spacing
