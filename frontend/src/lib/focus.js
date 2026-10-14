import { useEffect, useRef, useState } from 'react';
import { useLocation } from 'react-router';

/**
 * Opening a notification (bell item or popup button) navigates with state { focus: <time> }. Once the page shows the record,
 * it scrolls to it and highlights it for a moment, so the click always visibly lands somewhere, even when that request
 * was already on screen.
 * ready: true once the record the notification points at is rendered. Returns { ref, flash } for that record's card.
 */
export function useNotificationFocus(ready) {
  const location = useLocation();
  const key = location.state?.focus ?? null;
  const ref = useRef(null);
  const handled = useRef(null);
  const [flash, setFlash] = useState(false);

  useEffect(() => {
    if (!key || !ready || handled.current === key || !ref.current) return;
    handled.current = key;
    ref.current.scrollIntoView({ behavior: 'smooth', block: 'start' });
    setFlash(true);
  }, [key, ready]);

  useEffect(() => {
    if (!flash) return undefined;
    const t = setTimeout(() => setFlash(false), 1800);
    return () => clearTimeout(t);
  }, [flash]);

  return { ref, flash };
}
