# Codex Prompt: Add Sable Design System

Implement the Sable design system in this SwiftUI iPadOS app.

Copy the files from `SableDesignSystem/` into the app target, preferably under:

```text
<app-target>/DesignSystem/Sable/
```

Then adapt the existing screens to use the design system.

Rules:

- The app is named **Sable**.
- Sable is a coloring app, not a drawing app.
- Remove visible copy that says drawing, new artwork, brush studio, or canvas as a persistent navigation item.
- Use collapsed navigation on Home, Library, and My Work.
- Use no app-wide sidebar on the coloring screen.
- Use `SableColor`, `SableFont`, `SableArtworkCard`, `SableFilterChip`, `SableProgressBar`, `SableCollapsedNav`, and `SableColorDock` wherever applicable.
- Use local placeholder thumbnails from `SableColoringThumbnail` if real assets are unavailable.
- Keep text density low and preserve the brutalist/pop look.
- Run the build after integration and fix compile errors.

Acceptance criteria:

- The app builds.
- The four pages use shared Sable tokens/components.
- Sable branding appears consistently.
- Library and My Work have retracted navigation.
- The coloring screen is calm and minimal, with a large central coloring page and compact bottom color dock.
