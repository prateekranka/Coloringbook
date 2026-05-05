# Home Tab — Wireframe

## Layout Hierarchy

```
┌─────────────────────────────────────────────────────────┐
│  ColorFlow                            [+] [☀️]          │  ← Nav bar (inline title)
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │                                                   │  │
│  │              FEATURED TEMPLATE                    │  │  ← Full-width hero card
│  │              (gradient overlay)                   │  │    Height: ~280pt
│  │                                                   │  │    Corner radius: Radius.xl (20)
│  │                                                   │  │
│  │   ┌─────────────────────────────────────────┐    │  │
│  │   │  "Lotus Mandala"                        │    │  │  ← Template name (white text)
│  │   │  Mandalas · Easy                        │    │  │    over gradient
│  │   │  [Start Coloring →]                     │    │  │  ← CTA button (accent pill)
│  │   └─────────────────────────────────────────┘    │  │
│  └───────────────────────────────────────────────────┘  │
│                                                         │
│  My Recent Work                                See All  │  ← Section header
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐           │    with right-aligned link
│  │        │ │        │ │        │ │   +    │           │  ← Horizontal scroll
│  │ thumb  │ │ thumb  │ │ thumb  │ │  new   │           │    Card size: 140×140
│  │        │ │        │ │        │ │        │           │    Corner radius: Radius.md (12)
│  ├────────┤ ├────────┤ ├────────┤ ├────────┤           │
│  │ Name   │ │ Name   │ │ Name   │ │ Start  │           │  ← Template name
│  │ 60%    │ │ 100%   │ │ 30%    │ │  new   │           │  ← Progress indicator
│  └────────┘ └────────┘ └────────┘ └────────┘           │
│                                                         │
│  Inspiration                                  See All   │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐           │
│  │        │ │        │ │        │ │        │           │  ← Horizontal scroll
│  │ thumb  │ │ thumb  │ │ thumb  │ │ thumb  │           │    Card size: 160×120
│  │        │ │        │ │        │ │        │           │    (4:3 aspect ratio)
│  ├────────┤ ├────────┤ ├────────┤ ├────────┤           │
│  │ Name   │ │ Name   │ │ Name   │ │ Name   │           │
│  │ ⭐ Easy│ │ ⭐ Med │ │ ⭐ Easy│ │ ⭐ Hard│           │  ← Difficulty pill
│  └────────┘ └────────┘ └────────┘ └────────┘           │
│                                                         │
│  Suggested For You                             See All  │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐           │
│  │        │ │        │ │        │ │        │           │
│  │ thumb  │ │ thumb  │ │ thumb  │ │ thumb  │           │
│  │        │ │        │ │        │ │        │           │
│  ├────────┤ ├────────┤ ├────────┤ ├────────┤           │
│  │ Name   │ │ Name   │ │ Name   │ │ Name   │           │
│  │ ⭐ Easy│ │ ⭐ Med │ │ ⭐ Hard│ │ ⭐ Easy│           │
│  └────────┘ └────────┘ └────────┘ └────────┘           │
│                                                         │
├─────────────────────────────────────────────────────────┤
│  [🏠 Home]    [📚 Library]    [👤 My Work]              │  ← Tab bar
└─────────────────────────────────────────────────────────┘
```

## Spacing Specs

| Element | Spacing | Token |
|---------|---------|-------|
| Nav bar padding | 16pt horizontal | `Spacing.xl` |
| Hero card margin | 16pt horizontal, 12pt top | `Spacing.xl`, `Spacing.lg` |
| Hero card corner radius | 20pt | `Radius.xl` |
| Hero card height | 280pt | fixed |
| Section header to content | 12pt | `Spacing.lg` |
| Card spacing in scroll | 12pt | `Spacing.lg` |
| Card corner radius | 12pt | `Radius.md` |
| Template card size | 140×140 (square) | fixed |
| Inspiration card size | 160×120 (4:3) | fixed |
| Section to section | 24pt | `Spacing.xxxl` |
| Tab bar height | 49pt (standard) | system |

## Color Tokens

| Element | Color | Token |
|---------|-------|-------|
| Background | #151210 (dark) | `Surface.background` |
| Hero gradient overlay | accent → clear (top to bottom) | `Brand.accent` at 0.3 opacity |
| Section header text | #F5EFE6 | `Ink.primary` |
| Section header link | #7AB887 | `Brand.accent` |
| Card background | #2A2520 | `Surface.elevated` |
| Template name | #F5EFE6 | `Ink.primary` |
| Difficulty pill text | green/orange/red | `State.success/warning/danger` |
| Tab bar | system | `.tabViewStyle(.automatic)`

## Key Changes from Current

1. **Hero card**: Full-width with gradient overlay (not centered box)
2. **"See All" links**: Added to each section header
3. **Recent Work**: Shows progress percentage per project
4. **Cards**: Image fills the card (no white border)
5. **Spacing**: Tighter vertical rhythm (24pt between sections, not 32+)
