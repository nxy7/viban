# Feature: Card Details URL Routing

## Overview

When opening a card's details side panel, the URL should update to reflect the currently viewed card. This enables deep linking to specific cards and proper browser navigation (back/forward buttons).

**Current behavior:**
```
https://localhost:8000/board/ea09560b-a3a6-48c4-bb57-9cf76de32a84
```

**Desired behavior:**
```
https://localhost:8000/board/ea09560b-a3a6-48c4-bb57-9cf76de32a84/card/:cardId
```

## User Stories

1. **Deep Linking**: As a user, I can share a link directly to a specific card so colleagues can see the card details immediately.
2. **Browser History**: As a user, I can use browser back/forward buttons to navigate between card views.
3. **Bookmark Cards**: As a user, I can bookmark a specific card's URL to quickly access it later.
4. **Refresh Preservation**: As a user, when I refresh the page with a card URL, the side panel opens to that card.

## Technical Design

### Router Configuration

Update the SolidJS router to support nested card routes:

```tsx
// frontend/src/App.tsx or routes configuration

import { Router, Route } from "@solidjs/router";

<Router>
  <Route path="/board/:boardId" component={BoardPage}>
    <Route path="/" component={BoardView} />
    <Route path="/card/:cardId" component={BoardView} />
  </Route>
</Router>
```

### Board Page Component

The BoardPage component should read the cardId from URL params and control the side panel:

```tsx
// frontend/src/pages/BoardPage.tsx

import { useParams, useNavigate } from "@solidjs/router";
import { createEffect, createSignal, Show } from "solid-js";

export function BoardPage() {
  const params = useParams<{ boardId: string; cardId?: string }>();
  const navigate = useNavigate();

  // Derive selected card from URL
  const selectedCardId = () => params.cardId || null;

  // Open card details - navigate to card URL
  const openCardDetails = (cardId: string) => {
    navigate(`/board/${params.boardId}/card/${cardId}`);
  };

  // Close card details - navigate back to board URL
  const closeCardDetails = () => {
    navigate(`/board/${params.boardId}`);
  };

  return (
    <div class="flex h-screen">
      {/* Main board area */}
      <div class="flex-1">
        <KanbanBoard
          boardId={params.boardId}
          onCardClick={openCardDetails}
        />
      </div>

      {/* Side panel - shown when cardId is in URL */}
      <Show when={selectedCardId()}>
        <CardDetailsSidePanel
          cardId={selectedCardId()!}
          onClose={closeCardDetails}
        />
      </Show>
    </div>
  );
}
```

### Task Card Click Handler

Update task cards to navigate instead of setting local state:

```tsx
// frontend/src/components/TaskCard.tsx

import { useNavigate, useParams } from "@solidjs/router";

export function TaskCard(props: { task: Task }) {
  const params = useParams<{ boardId: string }>();
  const navigate = useNavigate();

  const handleClick = () => {
    navigate(`/board/${params.boardId}/card/${props.task.id}`);
  };

  return (
    <div
      onClick={handleClick}
      class="cursor-pointer ..."
    >
      {/* Card content */}
    </div>
  );
}
```

### Side Panel with URL Awareness

The side panel should handle invalid card IDs gracefully:

```tsx
// frontend/src/components/CardDetailsSidePanel.tsx

import { createResource, Show, createEffect } from "solid-js";
import { useNavigate, useParams } from "@solidjs/router";

interface Props {
  cardId: string;
  onClose: () => void;
}

export function CardDetailsSidePanel(props: Props) {
  const params = useParams<{ boardId: string }>();
  const navigate = useNavigate();

  // Fetch card data
  const [card, { refetch }] = createResource(
    () => props.cardId,
    fetchCard
  );

  // Handle card not found - redirect to board
  createEffect(() => {
    if (card.error || (card.state === "ready" && !card())) {
      // Card doesn't exist, navigate back to board
      navigate(`/board/${params.boardId}`, { replace: true });
    }
  });

  // Handle Escape key
  createEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        props.onClose();
      }
    };
    document.addEventListener("keydown", handleKeyDown);
    return () => document.removeEventListener("keydown", handleKeyDown);
  });

  return (
    <Show when={card()} fallback={<SidePanelSkeleton />}>
      <div class="w-96 border-l border-zinc-700 bg-zinc-900 h-full overflow-y-auto">
        {/* Header with close button */}
        <div class="flex items-center justify-between p-4 border-b border-zinc-700">
          <h2 class="font-semibold truncate">{card()!.title}</h2>
          <button onClick={props.onClose} class="text-zinc-400 hover:text-white">
            <XIcon class="w-5 h-5" />
          </button>
        </div>

        {/* Card details content */}
        <div class="p-4">
          {/* ... card details ... */}
        </div>
      </div>
    </Show>
  );
}
```

### Browser History Behavior

Using `navigate()` will automatically add entries to browser history. For the close action, we have two options:

**Option A: Push new history entry (default)**
```tsx
const closeCardDetails = () => {
  navigate(`/board/${params.boardId}`);
};
// User can press back to reopen the card
```

**Option B: Replace history entry**
```tsx
const closeCardDetails = () => {
  navigate(`/board/${params.boardId}`, { replace: true });
};
// Closing doesn't add history entry
```

Recommend Option A as it matches user expectations for "back" button behavior.

### URL Validation

Ensure the card belongs to the current board:

```tsx
// In CardDetailsSidePanel or a guard
createEffect(() => {
  const cardData = card();
  if (cardData && cardData.column?.board_id !== params.boardId) {
    // Card exists but belongs to different board
    navigate(`/board/${params.boardId}`, { replace: true });
  }
});
```

## Implementation Steps

### Phase 1: Router Setup
1. Update router configuration to support `/board/:boardId/card/:cardId` route
2. Ensure both routes render the same BoardPage component
3. Test that URL changes work without full page reload

### Phase 2: Navigation Integration
1. Update BoardPage to read cardId from params
2. Replace local selectedCard state with URL-derived state
3. Update openCardDetails to use navigate()
4. Update closeCardDetails to use navigate()

### Phase 3: Task Card Updates
1. Update TaskCard click handler to navigate
2. Remove any prop drilling for onCardClick if using navigate directly
3. Test that clicking cards updates URL

### Phase 4: Side Panel Updates
1. Update CardDetailsSidePanel to handle card not found
2. Add redirect logic for invalid card IDs
3. Ensure loading states work correctly

### Phase 5: Polish
1. Test browser back/forward navigation
2. Test direct URL access (copy/paste URL)
3. Test page refresh with card URL
4. Add proper loading states during navigation

## Success Criteria

- [ ] Clicking a card updates URL to `/board/:boardId/card/:cardId`
- [ ] Closing side panel updates URL to `/board/:boardId`
- [ ] Browser back button reopens previously viewed card
- [ ] Browser forward button works after going back
- [ ] Direct URL access opens the correct card
- [ ] Page refresh with card URL shows the card
- [ ] Invalid card ID redirects to board
- [ ] Card from wrong board redirects to board
- [ ] Escape key closes panel and updates URL

## Edge Cases

1. **Card Deleted While Viewing**: If a card is deleted (by another user via Electric sync), detect the change and close the panel with redirect.

2. **Board Access Revoked**: If user loses access to board while viewing card, handle gracefully.

3. **Multiple Tabs**: Opening same card in multiple tabs should work independently.

4. **Mobile**: Side panel behavior may differ on mobile - consider full-screen modal instead.

## Future Enhancements

1. **Query Parameters for View State**: Add ?edit=true for edit mode, ?tab=comments for specific tab
2. **Card Preview on Hover**: Show card preview when hovering links with card URLs
3. **Breadcrumbs**: Show navigation path (Board > Column > Card)
