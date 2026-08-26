// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This file is part of Front Porch AI.
//
// Front Porch AI is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Front Porch AI is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with Front Porch AI. If not, see <https://www.gnu.org/licenses/>.

/// Vite ports the desktop web server will reflect as credentialed CORS /
/// WebSocket origins. Production SPA is same-origin (no CORS). Arbitrary
/// localhost ports must not be reflected — a page on `:9999` would otherwise
/// ride the session cookie.
const Set<int> kViteDevPorts = {5173, 5174, 4173};

/// True when [origin] is the Vite dev server on loopback (`localhost` or
/// `127.0.0.1`) at a known Vite port. Scheme may be http or https.
bool isAllowedViteDevOrigin(String origin) {
  final uri = Uri.tryParse(origin);
  if (uri == null) return false;
  if (uri.host != 'localhost' && uri.host != '127.0.0.1') return false;
  return kViteDevPorts.contains(uri.port);
}
