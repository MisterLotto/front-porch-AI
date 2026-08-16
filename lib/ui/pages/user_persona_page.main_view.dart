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

part of 'user_persona_page.dart';

/// The persona list landing view for [_UserPersonaPageState]: the hero
/// header for the active persona plus the "All Personas" grid section.
/// Extracted verbatim from the inline _buildMainView/_buildHeroHeader;
/// direct state access preserves behavior. AppColors + warm-porch accents.
extension _UserPersonaMainView on _UserPersonaPageState {
  // ── Main View ──────────────────────────────────────────────────────────

  Widget _buildMainView({Key? key}) {
    return Consumer<UserPersonaService>(
      key: key,
      builder: (context, service, child) {
        if (service.personas.isEmpty) {
          return _buildEmptyState(context);
        }

        final defaultPersona = service.defaultPersona;
        final accentColor = PersonaColors.getColorForPersona(defaultPersona.id);

        return CustomScrollView(
          slivers: [
            // Hero header
            SliverToBoxAdapter(
              child: _buildHeroHeader(defaultPersona, accentColor, service),
            ),

            // Section label
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.porchAmberOf(context),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'All Personas (${service.personas.length})',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary(context),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Persona grid
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 340,
                  childAspectRatio: 1.35,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final persona = service.personas[index];
                  final isDefault = persona.id == defaultPersona.id;
                  return _buildPersonaCard(context, persona, isDefault, service);
                }, childCount: service.personas.length),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Hero Header ────────────────────────────────────────────────────────

  Widget _buildHeroHeader(
    UserPersona defaultPersona,
    Color accentColor,
    UserPersonaService service,
  ) {
    return AnimatedBuilder(
      animation: _headerGlowAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accentColor.withValues(
                  alpha: 0.08 + _headerGlowAnimation.value * 0.06,
                ),
                AppColors.resolve(
                  context,
                  const Color(0xFF1E293B),
                  AppColors.lightCard,
                ).withValues(alpha: 0.9),
                AppColors.resolve(
                  context,
                  const Color(0xFF0F172A),
                  AppColors.lightBackground,
                ).withValues(alpha: 0.95),
              ],
            ),
            border: Border.all(
              color: accentColor.withValues(
                alpha: 0.15 + _headerGlowAnimation.value * 0.1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.06),
                blurRadius: 30,
                spreadRadius: -8,
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar with glow
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(
                        alpha: 0.25 + _headerGlowAnimation.value * 0.15,
                      ),
                      blurRadius: 24,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: PersonaColors.buildPersonaAvatar(
                  avatarPath: defaultPersona.avatarPath,
                  personaId: defaultPersona.id,
                  radius: 44,
                  iconSize: 36,
                ),
              ),
              const SizedBox(width: 24),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            defaultPersona.displayLabel,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary(context),
                              letterSpacing: -0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _buildDefaultBadge(accentColor),
                      ],
                    ),
                    if (defaultPersona.title.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        defaultPersona.name,
                        style: TextStyle(
                          fontSize: 14,
                          color: accentColor.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (defaultPersona.persona.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        defaultPersona.persona,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary(context),
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    // Stats chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildStatChip(
                          context,
                          Icons.people_outline,
                          '${service.personas.length} persona${service.personas.length != 1 ? 's' : ''}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Edit button
              IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  color: accentColor.withValues(alpha: 0.7),
                ),
                tooltip: 'Edit active persona',
                onPressed: () => _startEditing(defaultPersona),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDefaultBadge(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.1)],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 6, color: color),
          const SizedBox(width: 4),
          Text(
            'Default',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.resolve(
          context,
          Colors.white.withValues(alpha: 0.05),
          Colors.black.withValues(alpha: 0.04),
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.resolve(
            context,
            Colors.white.withValues(alpha: 0.06),
            AppColors.lightBorder.withValues(alpha: 0.6),
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textTertiary(context)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary(context),
            ),
          ),
        ],
      ),
    );
  }
}
