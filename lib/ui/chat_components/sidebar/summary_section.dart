// standard
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';
import 'package:front_porch_ai/ui/widgets/widgets.dart';

/// "Where we are" sidebar section — the Journal's per-chat recap.
/// Shows the Journal enable toggle, the editable recap text, pause/regenerate
/// controls, and the maintenance-pass interval. (Replaced the old Chat
/// Summary section; the full Journal card UI lands in phase 3 —
/// docs/design/journal-memory.md §8.)
class SummarySection extends StatefulWidget {
  final ChatService chatService;
  const SummarySection({super.key, required this.chatService});

  @override
  State<SummarySection> createState() => SummarySectionState();
}

class SummarySectionState extends State<SummarySection> {
  late TextEditingController _controller;
  bool _showSettings = false;
  bool _expanded = false;
  double? _dragJournalInterval;

  Color _accent(BuildContext context) => AppColors.resolve(
    context,
    const Color(0xFF26A69A), // teal accent (via resolve for light/dark)
    const Color(0xFF00796B),
  );

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.chatService.summary);
    widget.chatService.addListener(_onChatChanged);
  }

  void _onChatChanged() {
    if (_controller.text != widget.chatService.summary) {
      _controller.text = widget.chatService.summary;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.chatService.removeListener(_onChatChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storage = Provider.of<StorageService>(context);
    final enabled = storage.journalEnabled;
    final accent = _accent(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with enable toggle
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_more : Icons.chevron_right,
                  size: 16,
                  color: AppColors.iconSecondary(context),
                ),
                const SizedBox(width: 4),
                Icon(Icons.auto_stories, size: 14, color: accent),
                const SizedBox(width: 6),
                Text(
                  'Where we are',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(context),
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                if (enabled && widget.chatService.isSummaryGenerating)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                      ),
                    ),
                  ),
                SizedBox(
                  height: 28,
                  child: FittedBox(
                    child: Switch(
                      value: enabled,
                      onChanged: (val) {
                        storage.setJournalEnabled(val);
                        if (val) setState(() => _expanded = true);
                      },
                      activeTrackColor: accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_expanded) ...[
          if (!enabled)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 20),
              child: Text(
                'The character keeps a journal of this chat — memories of '
                'what happened and how it felt, plus this recap of where '
                'things stand.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary(context),
                ),
              ),
            ),

          if (enabled) ...[
            const SizedBox(height: 8),
            // Recap text field (editable — the character reads this back)
            Padding(
              padding: const EdgeInsets.only(left: 20.0),
              child: AppTextField(
                controller: _controller,
                maxLines: 6,
                minLines: 2,
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 12,
                ),
                decoration: InputDecoration(
                  hintText:
                      'No recap yet. It will generate after enough messages...',
                  hintStyle: TextStyle(
                    color: AppColors.textTertiary(context),
                    fontSize: 12,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceContainerOf(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.borderOf(context)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.borderOf(context)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: accent),
                  ),
                  contentPadding: const EdgeInsets.all(10),
                ),
                onChanged: (val) {
                  widget.chatService.setSummary(val);
                },
              ),
            ),
            const SizedBox(height: 6),
            // Controls row
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Row(
                children: [
                  // Pause/Resume toggle
                  InkWell(
                    onTap: () => widget.chatService.setSummaryPaused(
                      !widget.chatService.summaryPaused,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.chatService.summaryPaused
                                ? Icons.play_arrow
                                : Icons.pause,
                            size: 14,
                            color: widget.chatService.summaryPaused
                                ? AppColors.resolve(
                                    context,
                                    Colors.orangeAccent,
                                    Colors.orange.shade700,
                                  )
                                : AppColors.iconSecondary(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.chatService.summaryPaused
                                ? 'Paused'
                                : 'Auto',
                            style: TextStyle(
                              fontSize: 10,
                              color: widget.chatService.summaryPaused
                                  ? AppColors.resolve(
                                      context,
                                      Colors.orangeAccent,
                                      Colors.orange.shade700,
                                    )
                                  : AppColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Settings gear toggle
                  InkWell(
                    onTap: () => setState(() => _showSettings = !_showSettings),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Icon(
                        Icons.tune,
                        size: 14,
                        color: _showSettings
                            ? accent
                            : AppColors.iconSecondary(context),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Regenerate button (runs a full Journal pass: cards + recap)
                  InkWell(
                    onTap: widget.chatService.isSummaryGenerating
                        ? null
                        : () => widget.chatService.forceSummaryUpdate(),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.refresh,
                            size: 14,
                            color: widget.chatService.isSummaryGenerating
                                ? AppColors.textTertiary(context)
                                : accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Regen',
                            style: TextStyle(
                              fontSize: 10,
                              color: widget.chatService.isSummaryGenerating
                                  ? AppColors.textTertiary(context)
                                  : accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.chatService.summaryLastIndex > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 24),
                child: Text(
                  'Last updated at message #${widget.chatService.summaryLastIndex}',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textTertiary(context),
                  ),
                ),
              ),

            // Expandable settings panel
            if (_showSettings) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerOf(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderOf(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Update Interval
                      Row(
                        children: [
                          Text(
                            'Update every',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${(_dragJournalInterval ?? storage.journalInterval.toDouble()).round()} messages',
                            style: TextStyle(
                              fontSize: 11,
                              color: accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                        ),
                        child: Slider(
                          value:
                              _dragJournalInterval ??
                              storage.journalInterval.toDouble(),
                          min: 3,
                          max: 50,
                          divisions: 47,
                          activeColor: accent,
                          inactiveColor: AppColors.borderOf(context),
                          onChanged: (val) =>
                              setState(() => _dragJournalInterval = val),
                          onChangeEnd: (val) {
                            _dragJournalInterval = null;
                            storage.setJournalInterval(val.toInt());
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 12,
                            color: Colors.amber,
                          ),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Uses your active LLM — consumes tokens on paid APIs.',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ],
    );
  }
}
