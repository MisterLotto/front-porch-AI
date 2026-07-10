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

/// Pure prompt data for Expression Packs: which emotions a pack covers and
/// the diffusion-friendly facial-expression phrase appended per emotion.
/// Every label here is a lowercase `EmotionLabels.all` value, stored verbatim
/// as the avatar label so the runtime expression matcher
/// (`a.label?.toLowerCase() == label`) finds it exactly.
library;

/// The 8-emotion starter set (all reachable by both classifiers).
const List<String> kCuratedExpressionSet = [
  'neutral',
  'joy',
  'sadness',
  'anger',
  'fear',
  'surprise',
  'love',
  'embarrassment',
];

/// The full 28-emotion set: EmotionLabels.all minus 'affection' and
/// 'anticipation' (unreachable by the ONNX classifier, which only emits the
/// GoEmotions-28 labels).
const List<String> kFullExpressionSet = [
  'admiration',
  'amusement',
  'anger',
  'annoyance',
  'approval',
  'caring',
  'confusion',
  'curiosity',
  'desire',
  'disappointment',
  'disapproval',
  'disgust',
  'embarrassment',
  'excitement',
  'fear',
  'gratitude',
  'grief',
  'joy',
  'love',
  'nervousness',
  'optimism',
  'pride',
  'realization',
  'relief',
  'remorse',
  'sadness',
  'surprise',
  'neutral',
];

/// Diffusion-friendly facial-expression phrase per emotion
/// (keys == [kFullExpressionSet] exactly). Short comma-tag style describing
/// the FACE, usable in both natural-language and booru-tag prompts — inner
/// states are translated into visible facial cues a model can actually draw.
const Map<String, String> kExpressionModifiers = {
  'admiration': 'admiring gaze, sparkling wide eyes, soft impressed smile',
  'amusement': 'amused grin, crinkled eyes, holding back laughter',
  'anger': 'furious glare, furrowed brow, clenched jaw, bared teeth',
  'annoyance': 'annoyed scowl, narrowed eyes, pursed lips, twitching eyebrow',
  'approval': 'approving warm smile, relaxed eyes, satisfied nod',
  'caring': 'gentle caring smile, soft warm eyes, tender expression',
  'confusion': 'puzzled expression, furrowed brow, head tilted, questioning look',
  'curiosity': 'curious look, one raised eyebrow, bright inquisitive eyes, slight head tilt',
  'desire': 'sultry half-lidded eyes, parted lips, flushed cheeks, longing gaze',
  'disappointment': 'disappointed frown, downcast eyes, deflated expression',
  'disapproval': 'disapproving frown, narrowed judging eyes, tight pressed lips',
  'disgust': 'disgusted grimace, wrinkled nose, curled upper lip, recoiling',
  'embarrassment': 'deep blush, averted eyes, bashful cringing smile',
  'excitement': 'excited wide grin, shining eager eyes, raised eyebrows',
  'fear': 'terrified wide eyes, pale face, trembling parted lips',
  'gratitude': 'grateful heartfelt smile, moved teary eyes, hand over heart',
  'grief': 'anguished expression, tears streaming down face, devastated',
  'joy': 'beaming smile, bright happy eyes, joyful expression',
  'love': 'loving adoring gaze, soft dreamy smile, gentle blush, warm eyes',
  'nervousness': 'nervous strained smile, darting anxious eyes, biting lip, sweat on brow',
  'optimism': 'hopeful bright smile, uplifted gaze, confident warm expression',
  'pride': 'proud smirk, chin raised high, confident gleaming eyes',
  'realization': 'eyes widening in sudden understanding, parted lips, dawning look',
  'relief': 'relieved exhale, eyes closed softly, relaxed easing smile',
  'remorse': 'remorseful downcast eyes, sorrowful frown, guilty lowered head',
  'sadness': 'sad teary eyes, downturned mouth, melancholy expression',
  'surprise': 'shocked wide eyes, raised eyebrows, mouth open in surprise',
  'neutral': 'calm neutral expression, relaxed face',
};

/// Framing suffix appended once to the base prompt by the pack launcher.
const String kExpressionFraming =
    'close-up portrait, head and shoulders, looking at viewer';
