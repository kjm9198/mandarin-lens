# Optional vocabulary review

This is a small interval scheduler, not SM-2 or a clinically/educationally validated retention model. It operates only when you choose to review a word. New words are immediately due. Reveal the meaning, then choose:

- Again: review in ten minutes; reset the interval to zero.
- Good: first review in one day; subsequent interval doubles.
- Easy: first review in three days; subsequent interval triples, with a three-day minimum.

Intervals are capped at 365 days. Each review stores a due date, interval and review count locally. The advanced filter identifies intervals of at least 21 days; it does not establish that the word has been mastered. No notifications or browsing reminders are scheduled.
