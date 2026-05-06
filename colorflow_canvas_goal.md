# ColorFlow Canvas Rebuild Goal

You are Codex acting as the technical orchestrator and reviewer.

Project path:
/Users/prateekranka/Cowork/ColorFlow

Objective:
Rebuild the missing Canvas product surface on top of the new architecture. The old canvas layer has been removed, and Canvas is currently the biggest missing product surface. Your role is to understand the current architecture, produce an implementation plan, delegate the actual code changes to opencode via computer use, then review the implementation thoroughly before considering the task complete.

Important workflow:
1. Codex should NOT directly implement large changes itself unless absolutely necessary.
2. Codex should inspect the repository, understand the new architecture, identify the intended patterns, and write a precise implementation brief for opencode.
3. opencode should perform the implementation through computer use.
4. Codex should then review the resulting diff, run relevant checks/tests/builds, identify issues, and ask opencode to fix them if needed.
5. Repeat review/fix cycles until the Canvas surface is integrated cleanly.

High-level product goal:
Recreate the Canvas experience in ColorFlow using the new architecture, without reviving deprecated patterns from the old removed canvas layer.

The Canvas surface should support the core coloring app experience:
- Open a coloring page/artwork from the library or current app flow.
- Display the selected artwork/template in a canvas/editor screen.
- Support pan and zoom in a way that feels natural on iPad.
- Support tap-to-fill or the current intended coloring interaction if the new architecture has a different abstraction for tools/actions.
- Preserve or connect to the app’s existing data model for artwork, pages, palettes, colors, progress, and saved work.
- Show a clean, premium UI consistent with the current ColorFlow/Sable design language.
- Include a usable toolbar/surface for color selection and main canvas actions.
- Support saving/restoring progress where the new architecture expects it.
- Handle loading, empty, and error states gracefully.
- Avoid tightly coupling UI directly to persistence or rendering internals if the new architecture uses services/stores/view models.
- Keep the implementation testable and maintainable.

Step 1 — Repository discovery:
Inspect the project structure before making any plan. Identify:
- App framework and entry points.
- Navigation/routing system.
- New architecture patterns: feature modules, stores, services, repositories, view models, reducers, or equivalent.
- Existing Library, Explore, Home, Artwork, Palette, or Project models.
- Existing image/rendering utilities.
- Any references to removed canvas APIs or TODOs.
- Existing tests/build scripts/lint scripts.
- iPad-specific layout conventions.
- Design system components and colors.

Search for terms like:
- Canvas
- Coloring
- Artwork
- Page
- Palette
- Fill
- Tool
- Editor
- Drawing
- Progress
- Library
- Sable
- ColorFlow
- TODO
- FIXME

Step 2 — Architecture summary:
Before delegating implementation, produce a short architecture summary covering:
- What the new architecture appears to be.
- Where Canvas should live.
- What existing models/services should be reused.
- What should NOT be reintroduced from the old layer.
- The likely navigation path into Canvas.
- Any uncertainty that must be resolved by code inspection.

Step 3 — Implementation brief for opencode:
Create a detailed brief for opencode to implement the Canvas surface. The brief should include:
- Exact files/directories to create or modify.
- Components/screens/views to add.
- State/store/view model changes.
- Navigation integration.
- Data flow.
- Rendering approach.
- Gesture handling.
- Color/palette integration.
- Save/progress integration.
- Loading/error/empty states.
- Tests to add or update.
- Build/lint/test commands to run.

Treat opencode as the implementation agent. Give it clear step-by-step instructions, but allow it to inspect files and adapt to the actual architecture.

Step 4 — Implementation requirements:
The implementation should follow these constraints:

Architecture:
- Use the new architecture’s established patterns.
- Do not resurrect the removed old canvas layer wholesale.
- Do not create a one-off architecture just for Canvas.
- Prefer small focused components over one large screen file.
- Keep rendering, interaction state, persistence, and UI controls separated if the architecture supports that.
- Use existing shared components, theme tokens, and design system primitives.

Product/UI:
- Canvas should feel like the main product surface, not a placeholder.
- It should work well on iPad layouts.
- Keep controls accessible but not cluttered.
- Use the app’s warm premium design language.
- Prefer a focused full-screen editing experience.
- Include a color palette strip or tray.
- Include obvious actions such as back, undo/redo if supported, reset/clear if supported, save/done if supported.
- If undo/redo is not yet available architecturally, leave clean extension points rather than hacking it in.

Canvas behavior:
- Load the selected coloring page/artwork.
- Render the artwork/template.
- Allow user interaction with the artwork according to the app’s available fill/coloring model.
- Support pan/zoom gestures.
- Keep color selection state separate from artwork state.
- Save progress through the existing persistence path if available.
- Restore previously saved progress when reopening.
- If full tap-to-fill infrastructure is not currently present, implement the best compatible vertical slice and leave explicit TODOs only where the underlying architecture is missing.

Quality:
- No dead code.
- No large commented-out blocks.
- No fake/mock-only implementation unless the rest of the app currently uses mock data.
- No hardcoded sample artwork except as a graceful fallback for development, clearly isolated.
- No broken navigation.
- No TypeScript/Swift/etc. compile errors.
- No lint errors where linting exists.
- Add tests where practical.

Step 5 — Review process:
After opencode implements the changes, Codex must:
- Inspect the full diff.
- Check whether the implementation follows the new architecture.
- Run the relevant build/test/lint commands.
- Verify there are no obvious runtime integration gaps.
- Verify Canvas can be reached from the appropriate app flow.
- Verify state/data flow is coherent.
- Verify styling matches the existing app.
- Identify any regressions or architecture violations.

If issues are found, Codex should send opencode a focused fix request. Do not accept the implementation until the main Canvas flow is usable and aligned with the architecture.

Step 6 — Definition of done:
The task is complete only when:
- Canvas/editor surface exists again.
- A user can navigate to Canvas from the app’s product flow.
- A selected artwork/page can be displayed.
- User can select colors and interact with the canvas in the intended way, or the best currently possible vertical slice is implemented cleanly.
- Pan/zoom or equivalent canvas navigation works.
- Progress save/restore is connected where the architecture supports it.
- The UI matches the app’s design language.
- Build passes.
- Tests/lint pass where available.
- Codex has reviewed the implementation and documented remaining limitations, if any.

Expected final Codex output:
Return:
1. A short summary of what was implemented.
2. Files changed.
3. Commands run and results.
4. Any limitations or follow-up tasks.
5. A final review verdict: approved or needs follow-up.

Begin by inspecting /Users/prateekranka/Cowork/ColorFlow and mapping the architecture before delegating anything to opencode.
