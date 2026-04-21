// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Tests for Relationship tier/progress calculations extracted from ChatService.
// These are pure mathematical functions critical for the Realism Engine's
// short-term and long-term bond tracking.

import 'package:flutter_test/flutter_test.dart';

/// Minimal stub that replicates the tier calculation and progress logic
/// from ChatService. This enables unit testing without the full service.
class _RelationshipStub {
  int _affectionScore = 0;
  int _relationshipTier = 0;
  int _longTermScore = 0;
  int _longTermTier = 0;

  int get affectionScore => _affectionScore;
  int get relationshipTier => _relationshipTier;
  int get longTermScore => _longTermScore;
  int get longTermTier => _longTermTier;

  /// Mirrors ChatService._calculateTier (line 728).
  int calculateTier(int score) {
    final absScore = score.abs();
    if (absScore < 10) return 0;
    if (absScore < 25) return score > 0 ? 1 : -1;
    if (absScore < 45) return score > 0 ? 2 : -2;
    if (absScore < 70) return score > 0 ? 3 : -3;
    if (absScore < 100) return score > 0 ? 4 : -4;
    return score > 0 ? 5 : -5;
  }

  /// Mirrors ChatService.shortTermProgressTarget (line 675).
  int get shortTermProgressTarget {
    final absScore = _affectionScore.abs();
    if (absScore < 10) return 10;
    if (absScore < 25) return 25;
    if (absScore < 45) return 45;
    if (absScore < 70) return 70;
    if (absScore < 100) return 100;
    return 150;
  }

  /// Mirrors ChatService.shortTermProgressBase (line 685).
  int get shortTermProgressBase {
    final absScore = _affectionScore.abs();
    if (absScore < 10) return 0;
    if (absScore < 25) return 10;
    if (absScore < 45) return 25;
    if (absScore < 70) return 45;
    if (absScore < 100) return 70;
    return 100;
  }

  /// Mirrors ChatService.shortTermProgressPercent (line 695).
  double get shortTermProgressPercent {
    final current = _affectionScore.abs() - shortTermProgressBase;
    final total = shortTermProgressTarget - shortTermProgressBase;
    return (current / total).clamp(0.0, 1.0);
  }

  /// Mirrors ChatService.longTermProgressTarget (line 701).
  int get longTermProgressTarget {
    final absScore = _longTermScore.abs();
    if (absScore < 10) return 10;
    if (absScore < 25) return 25;
    if (absScore < 45) return 45;
    if (absScore < 70) return 70;
    if (absScore < 100) return 100;
    return 150;
  }

  /// Mirrors ChatService.longTermProgressBase (line 711).
  int get longTermProgressBase {
    final absScore = _longTermScore.abs();
    if (absScore < 10) return 0;
    if (absScore < 25) return 10;
    if (absScore < 45) return 25;
    if (absScore < 70) return 45;
    if (absScore < 100) return 70;
    return 100;
  }

  /// Mirrors ChatService.longTermProgressPercent (line 721).
  double get longTermProgressPercent {
    final current = _longTermScore.abs() - longTermProgressBase;
    final total = longTermProgressTarget - longTermProgressBase;
    return (current / total).clamp(0.0, 1.0);
  }

  void setScores({int? affection, int? longTerm}) {
    if (affection != null) {
      _affectionScore = affection;
      _relationshipTier = calculateTier(affection);
    }
    if (longTerm != null) {
      _longTermScore = longTerm;
      _longTermTier = calculateTier(longTerm);
    }
    // Always recalculate both tiers when any score changes
    if (affection != null) {
      _longTermTier = calculateTier(_longTermScore);
    }
    if (longTerm != null) {
      _relationshipTier = calculateTier(_affectionScore);
    }
  }
}

void main() {
  // ─── Tier Calculation ──────────────────────────────────────────────

  group('calculateTier', () {
    test('score 0 returns tier 0', () {
      final stub = _RelationshipStub();
      expect(stub.calculateTier(0), 0);
    });

    test('score 9 returns tier 0', () {
      final stub = _RelationshipStub();
      expect(stub.calculateTier(9), 0);
      expect(stub.calculateTier(-9), 0);
    });

    test('score 10 returns tier 1', () {
      final stub = _RelationshipStub();
      expect(stub.calculateTier(10), 1);
      expect(stub.calculateTier(-10), -1);
    });

    test('score 24 returns tier 1', () {
      final stub = _RelationshipStub();
      expect(stub.calculateTier(24), 1);
      expect(stub.calculateTier(-24), -1);
    });

    test('score 25 returns tier 2', () {
      final stub = _RelationshipStub();
      expect(stub.calculateTier(25), 2);
      expect(stub.calculateTier(-25), -2);
    });

    test('score 44 returns tier 2', () {
      final stub = _RelationshipStub();
      expect(stub.calculateTier(44), 2);
      expect(stub.calculateTier(-44), -2);
    });

    test('score 45 returns tier 3', () {
      final stub = _RelationshipStub();
      expect(stub.calculateTier(45), 3);
      expect(stub.calculateTier(-45), -3);
    });

    test('score 69 returns tier 3', () {
      final stub = _RelationshipStub();
      expect(stub.calculateTier(69), 3);
      expect(stub.calculateTier(-69), -3);
    });

    test('score 70 returns tier 4', () {
      final stub = _RelationshipStub();
      expect(stub.calculateTier(70), 4);
      expect(stub.calculateTier(-70), -4);
    });

    test('score 99 returns tier 4', () {
      final stub = _RelationshipStub();
      expect(stub.calculateTier(99), 4);
      expect(stub.calculateTier(-99), -4);
    });

    test('score 100 returns tier 5', () {
      final stub = _RelationshipStub();
      expect(stub.calculateTier(100), 5);
      expect(stub.calculateTier(-100), -5);
    });

    test('score 150 returns tier 5', () {
      final stub = _RelationshipStub();
      expect(stub.calculateTier(150), 5);
      expect(stub.calculateTier(-150), -5);
    });

    test('score 999 returns tier 5', () {
      final stub = _RelationshipStub();
      expect(stub.calculateTier(999), 5);
      expect(stub.calculateTier(-999), -5);
    });
  });

  // ─── Short-Term Progress Target ────────────────────────────────────

  group('shortTermProgressTarget', () {
    test('target is 10 for score 0-9', () {
      final stub = _RelationshipStub();
      stub.setScores(affection: 0);
      expect(stub.shortTermProgressTarget, 10);

      stub.setScores(affection: 9);
      expect(stub.shortTermProgressTarget, 10);
    });

    test('target is 25 for score 10-24', () {
      final stub = _RelationshipStub();
      stub.setScores(affection: 10);
      expect(stub.shortTermProgressTarget, 25);

      stub.setScores(affection: 24);
      expect(stub.shortTermProgressTarget, 25);
    });

    test('target is 45 for score 25-44', () {
      final stub = _RelationshipStub();
      stub.setScores(affection: 25);
      expect(stub.shortTermProgressTarget, 45);

      stub.setScores(affection: 44);
      expect(stub.shortTermProgressTarget, 45);
    });

    test('target is 70 for score 45-69', () {
      final stub = _RelationshipStub();
      stub.setScores(affection: 45);
      expect(stub.shortTermProgressTarget, 70);

      stub.setScores(affection: 69);
      expect(stub.shortTermProgressTarget, 70);
    });

    test('target is 100 for score 70-99', () {
      final stub = _RelationshipStub();
      stub.setScores(affection: 70);
      expect(stub.shortTermProgressTarget, 100);

      stub.setScores(affection: 99);
      expect(stub.shortTermProgressTarget, 100);
    });

    test('target is 150 for score 100+', () {
      final stub = _RelationshipStub();
      stub.setScores(affection: 100);
      expect(stub.shortTermProgressTarget, 150);

      stub.setScores(affection: 150);
      expect(stub.shortTermProgressTarget, 150);
    });

    test('uses absolute value of score', () {
      final stub = _RelationshipStub();
      stub.setScores(affection: -30);
      expect(stub.shortTermProgressTarget, 45);

      stub.setScores(affection: 30);
      expect(stub.shortTermProgressTarget, 45);
    });
  });

  // ─── Short-Term Progress Base ──────────────────────────────────────

  group('shortTermProgressBase', () {
    test('base is 0 for score 0-9', () {
      final stub = _RelationshipStub();
      stub.setScores(affection: 0);
      expect(stub.shortTermProgressBase, 0);
    });

    test('base is 10 for score 10-24', () {
      final stub = _RelationshipStub();
      stub.setScores(affection: 10);
      expect(stub.shortTermProgressBase, 10);
    });

    test('base is 25 for score 25-44', () {
      final stub = _RelationshipStub();
      stub.setScores(affection: 25);
      expect(stub.shortTermProgressBase, 25);
    });

    test('base is 45 for score 45-69', () {
      final stub = _RelationshipStub();
      stub.setScores(affection: 45);
      expect(stub.shortTermProgressBase, 45);
    });

    test('base is 70 for score 70-99', () {
      final stub = _RelationshipStub();
      stub.setScores(affection: 70);
      expect(stub.shortTermProgressBase, 70);
    });

    test('base is 100 for score 100+', () {
      final stub = _RelationshipStub();
      stub.setScores(affection: 100);
      expect(stub.shortTermProgressBase, 100);
    });
  });

  // ─── Short-Term Progress Percent ───────────────────────────────────

  group('shortTermProgressPercent', () {
    test('0% at score 0', () {
      final stub = _RelationshipStub();
      stub.setScores(affection: 0);
      expect(stub.shortTermProgressPercent, 0.0);
    });

    test('90% at score 9 (near tier boundary)', () {
      final stub = _RelationshipStub();
      stub.setScores(affection: 9);
      // base=0, target=10, current=9-0=9, total=10-0=10
      expect(stub.shortTermProgressPercent, 0.9);
    });

    test('0% at score 10 (tier boundary — progress resets)', () {
      final stub = _RelationshipStub();
      stub.setScores(affection: 10);
      // base=10, target=25, current=10-10=0, total=25-10=15
      expect(stub.shortTermProgressPercent, 0.0);
    });

    test('50% at score 17 (midpoint of 10-25)', () {
      final stub = _RelationshipStub();
      stub.setScores(affection: 17);
      // base=10, target=25, current=17-10=7, total=25-10=15
      expect(stub.shortTermProgressPercent, 7/15);
    });

    test('100% at score 150', () {
      final stub = _RelationshipStub();
      stub.setScores(affection: 150);
      expect(stub.shortTermProgressPercent, 1.0);
    });

    test('100% at score -150', () {
      final stub = _RelationshipStub();
      stub.setScores(affection: -150);
      expect(stub.shortTermProgressPercent, 1.0);
    });

    test('uses absolute value', () {
      final stub = _RelationshipStub();
      stub.setScores(affection: 50);
      final positiveProgress = stub.shortTermProgressPercent;

      stub.setScores(affection: -50);
      final negativeProgress = stub.shortTermProgressPercent;

      expect(positiveProgress, negativeProgress,
          reason: 'progress should be the same for positive and negative scores');
    });

    test('progress never exceeds 1.0', () {
      final stub = _RelationshipStub();
      stub.setScores(affection: 200);
      expect(stub.shortTermProgressPercent, lessThanOrEqualTo(1.0));
    });

    test('progress never goes below 0.0', () {
      final stub = _RelationshipStub();
      stub.setScores(affection: -200);
      expect(stub.shortTermProgressPercent, greaterThanOrEqualTo(0.0));
    });

    test('progress resets at tier boundaries', () {
      final stub = _RelationshipStub();
      // At score 24 (end of tier 1): progress should be high within tier
      stub.setScores(affection: 24);
      final progressAt24 = stub.shortTermProgressPercent;
      // base=10, target=25, current=24-10=14, total=25-10=15
      expect(progressAt24, 14/15);

      // At score 25 (start of tier 2): progress resets to 0
      stub.setScores(affection: 25);
      expect(stub.shortTermProgressPercent, 0.0,
          reason: 'progress resets to 0 at tier boundary');
    });
  });

  // ─── Long-Term Progress ────────────────────────────────────────────

  group('longTermProgressPercent', () {
    test('0% at score 0', () {
      final stub = _RelationshipStub();
      stub.setScores(longTerm: 0);
      expect(stub.longTermProgressPercent, 0.0);
    });

    test('100% at score 150', () {
      final stub = _RelationshipStub();
      stub.setScores(longTerm: 150);
      expect(stub.longTermProgressPercent, 1.0);
    });

    test('uses absolute value', () {
      final stub = _RelationshipStub();
      stub.setScores(longTerm: 30);
      final positiveProgress = stub.longTermProgressPercent;

      stub.setScores(longTerm: -30);
      final negativeProgress = stub.longTermProgressPercent;

      expect(positiveProgress, negativeProgress);
    });

    test('progress never exceeds 1.0', () {
      final stub = _RelationshipStub();
      stub.setScores(longTerm: 200);
      expect(stub.longTermProgressPercent, lessThanOrEqualTo(1.0));
    });

    test('progress never goes below 0.0', () {
      final stub = _RelationshipStub();
      stub.setScores(longTerm: -200);
      expect(stub.longTermProgressPercent, greaterThanOrEqualTo(0.0));
    });

    test('progress resets at tier boundaries', () {
      final stub = _RelationshipStub();
      stub.setScores(longTerm: 24);
      final progressAt24 = stub.longTermProgressPercent;
      expect(progressAt24, 14/15);

      stub.setScores(longTerm: 25);
      expect(stub.longTermProgressPercent, 0.0,
          reason: 'progress resets to 0 at tier boundary');
    });
  });

  // ─── Tier Consistency ──────────────────────────────────────────────

  group('tier consistency', () {
    test('tier 0 corresponds to progress 0% at score 0', () {
      final stub = _RelationshipStub();
      stub.setScores(affection: 0);
      expect(stub.relationshipTier, 0);
      expect(stub.shortTermProgressPercent, 0.0);
    });

    test('tier 5 at score 100 has progress 0% (tier boundary)', () {
      final stub = _RelationshipStub();
      stub._affectionScore = 100;
      stub._relationshipTier = stub.calculateTier(100);
      expect(stub.relationshipTier, 5);
      expect(stub.shortTermProgressPercent, 0.0,
          reason: 'progress resets at tier boundary');
    });

    test('tier -5 at score -100 has progress 0% (tier boundary)', () {
      final stub = _RelationshipStub();
      stub._affectionScore = -100;
      stub._relationshipTier = stub.calculateTier(-100);
      expect(stub.relationshipTier, -5);
      expect(stub.shortTermProgressPercent, 0.0,
          reason: 'progress resets at tier boundary');
    });

    test('progress increases within tier boundaries', () {
      final stub = _RelationshipStub();
      // Within tier 1 (10-24): progress should increase
      stub.setScores(affection: 10);
      final p10 = stub.shortTermProgressPercent; // 0.0
      stub.setScores(affection: 17);
      final p17 = stub.shortTermProgressPercent; // 7/15 ≈ 0.47
      stub.setScores(affection: 24);
      final p24 = stub.shortTermProgressPercent; // 14/15 ≈ 0.93

      expect(p10, lessThan(p17));
      expect(p17, lessThan(p24));
    });
  });
}
