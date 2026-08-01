// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Round creator avatar: the profile picture when one is set, the amber serif
// monogram otherwise. Shared by the account page, creator pages, and the
// following list (parity with the desktop's StoopCreatorAvatar).

import { stoop } from '../../stoop/stoopApi';

export function StoopCreatorAvatar({
  assetId,
  name,
  size = 64,
}: {
  assetId?: string | null;
  name: string;
  size?: number;
}) {
  const style = { width: size, height: size, fontSize: size * 0.4 };
  if (assetId) {
    return (
      <span className="stoop-creator-ava" style={style}>
        <img src={stoop.assetUrl(assetId)} alt="" loading="lazy" />
      </span>
    );
  }
  return (
    <span className="stoop-creator-ava stoop-creator-mono" style={style}>
      {(name || '?').charAt(0).toUpperCase()}
    </span>
  );
}
