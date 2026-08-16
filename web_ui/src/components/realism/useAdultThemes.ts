import { useEffect, useState } from 'react';
import { api } from '../../api/client';

// The install's 18+ master switch, for surfaces that show or hide adult
// controls — currently the "Intimate preferences" chip lists in the character
// editor and creator.
//
// Rides the SAME /api/settings `realism` object PorchLifeSettings already
// reads, rather than a new endpoint, so there is one server-side source of
// truth (StorageService.realismSettings.adultThemesEnabled) and the web cannot
// disagree with desktop about whether 18+ is on.
//
// Defaults FALSE while loading and on any error: the safe direction is to hide
// adult controls from someone who has not opted in, not to flash them for a
// frame. Nothing typed is lost either way — the values stay on the card, the
// same as flipping the master switch on desktop.
export function useAdultThemes(): boolean {
  const [on, setOn] = useState(false);
  useEffect(() => {
    let alive = true;
    api
      .get<{ realism?: { adultThemesEnabled?: boolean } }>('/api/settings')
      .then((s) => {
        if (alive) setOn(s.realism?.adultThemesEnabled === true);
      })
      .catch(() => {
        /* stay hidden — see above */
      });
    return () => {
      alive = false;
    };
  }, []);
  return on;
}
