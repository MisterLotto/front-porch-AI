// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Interactive image crop modal — the web mirror of the desktop ImageCropDialog
// (lib/ui/dialogs/image_crop_dialog.dart), reworked 2026-08-14 alongside the
// desktop blank-slate rewrite: the "Zoom Out (Pad Canvas)" button is gone —
// the crop box may now be dragged PAST the image edges instead, and the
// overhang is filled with the stage background on save, exactly as previewed.
// The whole image is always visible; there is no zoom state to get out of
// sync with the saved result. Returns the cropped region as a PNG Blob.
// Presentation-only; all colors come from CSS tokens in styles.css. Reused
// for avatar / expression-image uploads (AvatarManager).

import { useEffect, useRef, useState } from 'react';
import type { PointerEvent as RPointerEvent } from 'react';

interface Box {
  x: number;
  y: number;
  w: number;
  h: number;
}
interface Size {
  w: number;
  h: number;
}
type Mode = 'move' | 'nw' | 'ne' | 'sw' | 'se';

const MIN = 24; // smallest crop box, in displayed pixels
// Fill margin around the displayed image (px) — the room the crop box has to
// extend past the edges. Mirrors the wrap's CSS padding; keep in sync with
// .crop-wrap in styles.css.
const INSET = 44;

/** Apply a pointer delta to the start box for the given drag mode, clamped so
 *  the box keeps a minimum size and stays inside the visible stage [world]
 *  (image + fill margin — the box MAY overhang the image). */
function resize(start: Box, mode: Mode, dx: number, dy: number, world: Size): Box {
  if (mode === 'move') {
    const x = Math.max(0, Math.min(start.x + dx, world.w - start.w));
    const y = Math.max(0, Math.min(start.y + dy, world.h - start.h));
    return { x, y, w: start.w, h: start.h };
  }
  let l = start.x;
  let t = start.y;
  let r = start.x + start.w;
  let b = start.y + start.h;
  if (mode === 'nw' || mode === 'sw') l = start.x + dx;
  if (mode === 'ne' || mode === 'se') r = start.x + start.w + dx;
  if (mode === 'nw' || mode === 'ne') t = start.y + dy;
  if (mode === 'sw' || mode === 'se') b = start.y + start.h + dy;
  l = Math.max(0, Math.min(l, r - MIN));
  t = Math.max(0, Math.min(t, b - MIN));
  r = Math.max(l + MIN, Math.min(r, world.w));
  b = Math.max(t + MIN, Math.min(b, world.h));
  return { x: l, y: t, w: r - l, h: b - t };
}

export function ImageCropModal({
  file,
  onCancel,
  onCropped,
}: {
  file: File;
  onCancel: () => void;
  onCropped: (blob: Blob) => void;
}) {
  const [src, setSrc] = useState('');
  const [nat, setNat] = useState<Size>({ w: 0, h: 0 });
  const [disp, setDisp] = useState<Size>({ w: 0, h: 0 });
  const [crop, setCrop] = useState<Box>({ x: 0, y: 0, w: 0, h: 0 });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const imgRef = useRef<HTMLImageElement>(null);
  const drag = useRef<{ mode: Mode; sx: number; sy: number; box: Box } | null>(null);

  // Load the picked file as an object URL; revoke on change/unmount.
  useEffect(() => {
    const url = URL.createObjectURL(file);
    setSrc(url);
    return () => URL.revokeObjectURL(url);
  }, [file]);

  // Close on Escape, matching the desktop dialog's close affordance.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onCancel();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onCancel]);

  const onImgLoad = () => {
    const el = imgRef.current;
    if (!el) return;
    const dw = el.clientWidth;
    const dh = el.clientHeight;
    setNat({ w: el.naturalWidth, h: el.naturalHeight });
    setDisp({ w: dw, h: dh });
    // Box coordinates are relative to the padded wrap; the image sits at
    // (INSET, INSET). Start as the full image.
    setCrop({ x: INSET, y: INSET, w: dw, h: dh });
  };

  const start = (e: RPointerEvent<HTMLElement>, mode: Mode) => {
    e.stopPropagation();
    e.preventDefault();
    drag.current = { mode, sx: e.clientX, sy: e.clientY, box: crop };
    e.currentTarget.setPointerCapture(e.pointerId);
  };
  const onMove = (e: RPointerEvent<HTMLElement>) => {
    const d = drag.current;
    if (!d) return;
    const world = { w: disp.w + 2 * INSET, h: disp.h + 2 * INSET };
    setCrop(resize(d.box, d.mode, e.clientX - d.sx, e.clientY - d.sy, world));
  };
  const onEnd = (e: RPointerEvent<HTMLElement>) => {
    if (!drag.current) return;
    e.currentTarget.releasePointerCapture(e.pointerId);
    drag.current = null;
  };

  const reset = () => {
    if (disp.w > 0) setCrop({ x: INSET, y: INSET, w: disp.w, h: disp.h });
  };

  const save = () => {
    const el = imgRef.current;
    if (!el || busy || disp.w === 0) return;
    setBusy(true);
    setError('');
    const sx = nat.w / disp.w;
    const sy = nat.h / disp.h;
    // Crop origin in natural pixels, relative to the image (may be negative
    // or exceed the image — that overhang becomes fill).
    const cx = (crop.x - INSET) * sx;
    const cy = (crop.y - INSET) * sy;
    const outW = Math.max(1, Math.round(crop.w * sx));
    const outH = Math.max(1, Math.round(crop.h * sy));
    const canvas = document.createElement('canvas');
    canvas.width = outW;
    canvas.height = outH;
    const ctx = canvas.getContext('2d');
    if (!ctx) {
      setError('Crop failed.');
      setBusy(false);
      return;
    }
    // Fill first — same token the stage previews behind the image.
    const bg =
      getComputedStyle(document.documentElement).getPropertyValue('--bg').trim() || '#0f172a';
    ctx.fillStyle = bg;
    ctx.fillRect(0, 0, outW, outH);
    // Draw only the image∩crop intersection at its offset — negative source
    // coordinates into drawImage behave inconsistently across browsers.
    const ix0 = Math.max(0, cx);
    const iy0 = Math.max(0, cy);
    const ix1 = Math.min(nat.w, cx + outW);
    const iy1 = Math.min(nat.h, cy + outH);
    if (ix1 > ix0 && iy1 > iy0) {
      ctx.drawImage(
        el,
        ix0,
        iy0,
        ix1 - ix0,
        iy1 - iy0,
        Math.round(ix0 - cx),
        Math.round(iy0 - cy),
        Math.round(ix1 - ix0),
        Math.round(iy1 - iy0),
      );
    }
    canvas.toBlob((blob) => {
      if (blob) {
        onCropped(blob);
      } else {
        setError('Crop failed.');
        setBusy(false);
      }
    }, 'image/png');
  };

  return (
    <div className="drawer-backdrop center" onClick={onCancel}>
      <div className="modal crop-modal" onClick={(e) => e.stopPropagation()}>
        <div className="crop-modal-head">
          <span>Crop image</span>
          <button type="button" className="icon-btn" title="Close" onClick={onCancel}>
            ✕
          </button>
        </div>
        <p className="muted crop-hint">
          Drag to reposition, pull a corner to resize — past the picture's edges to add
          background around it.
        </p>
        <div className="crop-stage">
          <div className="crop-wrap">
            <img ref={imgRef} className="crop-img" src={src} alt="" onLoad={onImgLoad} draggable={false} />
            {disp.w > 0 && (
              <div
                className="crop-box"
                style={{ left: crop.x, top: crop.y, width: crop.w, height: crop.h }}
                onPointerDown={(e) => start(e, 'move')}
                onPointerMove={onMove}
                onPointerUp={onEnd}
              >
                {(['nw', 'ne', 'sw', 'se'] as Mode[]).map((m) => (
                  <span
                    key={m}
                    className={`crop-handle ${m}`}
                    onPointerDown={(e) => start(e, m)}
                    onPointerMove={onMove}
                    onPointerUp={onEnd}
                  />
                ))}
              </div>
            )}
          </div>
        </div>
        {error && <p className="error">{error}</p>}
        <div className="crop-actions">
          <button type="button" className="ghost" disabled={busy} onClick={reset}>
            ↺ Reset
          </button>
          <span className="spacer" />
          <button type="button" className="ghost" disabled={busy} onClick={onCancel}>
            Cancel
          </button>
          <button type="button" className="primary" disabled={busy} onClick={save}>
            {busy ? 'Cropping…' : 'Crop & Save'}
          </button>
        </div>
      </div>
    </div>
  );
}
