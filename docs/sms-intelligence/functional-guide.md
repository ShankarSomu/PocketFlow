# SMS Intelligence Layer — Functional Guide

> **Audience**: Product, QA, and feature contributors  
> **Version**: 6.0.0 (Phase 6 — Replay / Audit)

---

## What Does the SMS Intelligence Layer Do?

PocketFlow automatically processes incoming SMS messages to detect and record
financial transactions — without requiring the user to enter anything manually.

The layer consists of six components ("phases") that work together to:

1. **Ingest** every financial SMS and prevent duplicate processing.
2. **Recognise patterns** across messages from the same sender template.
3. **Self-improve** by pushing learned patterns into the active classifier.
4. **Score confidence** using multiple independent signals.
5. **Guard against anomalies** such as message floods or stale knowledge.
6. **Record decisions** so the pipeline can be audited or replayed.

---

## End-to-End User Journey

```
User receives SMS: "Rs.5,000 debited from HDFC A/c xx1234 at Amazon"
         │
         ▼
App wakes in background (SMS permission granted)
         │
         ▼
Privacy gate: is this a financial SMS? ─── No ──► silently dropped
         │ Yes
         ▼
Already seen? (duplicate check) ─────────── Yes ─► skipped, no duplicate entry
         │ No
         ▼
Classify: transaction / balance / OTP / promo / unknown-financial
         │
         ▼
Extract: ₹5,000 debit, account xx1234, merchant "Amazon"
         │
         ▼
Match to known account in PocketFlow ────── No match ─► flag for review
         │ Matched
         ▼
Score confidence (0–1 composite score)
         │
         ▼
Check for anomalies (burst, stale data, divergence, dispute)
         │
         ▼
Create transaction in app
         │
         ▼
User sees: "Amazon - ₹5,000 debit — HDFC xx1234" in Transactions screen
```

---

## Phase-by-Phase Functional Description

### Phase 1 — SMS Ledger

Every SMS that passes the privacy gate is written to an immutable log
(`sms_events`). This guarantees:

- **No duplicates** — the same message arriving twice is detected immediately
  via a content hash and discarded before any processing.
- **Auditability** — every raw message is preserved with its original text,
  sender, and timestamp.
- **Status tracking** — the event transitions from `pending` → `processed` /
  `skipped` / `duplicate` as the pipeline progresses.

### Phase 2 — Cluster Memory

Messages from the same sender template (e.g. all HDFC debit alerts) are
grouped into a *cluster* keyed on a template hash. The template hash is
computed from the token-masked message body, so "Rs.1500 debited" and
"Rs.2000 debited" land in the same cluster.

Each cluster tracks:

| Property | Meaning |
|----------|---------|
| `status` | `learning` → `known` / `disputed` |
| `confidence` | 0–1 probability this template represents a financial transaction |
| `match_count` | total messages seen for this template |
| `confirmed_count` | how many led to confirmed transactions |

Status meanings:

| Status | What it means |
|--------|---------------|
| `learning` | Fewer than 3 messages seen; system is still figuring out the pattern |
| `known` | High confidence (≥ 0.8, confirmed ≥ 3 times) — template is reliably financial |
| `disputed` | Mixed outcomes — system is uncertain; all messages need review |

### Phase 3 — Propagation

When a cluster becomes `known`, its knowledge is automatically pushed into
the live classifier so *future* messages from the same template are handled
faster and more accurately:

- The sender address is added to the **sender allow-list** (`sms_keywords`).
- The template hash is cached in **pattern cache** (`sms_pattern_cache`).
- The **signal weights** for that transaction type are reinforced.

If a cluster later deteriorates (drops back to `disputed`), those entries are
soft-deactivated automatically.

### Phase 4 — Probability Engine

Rather than relying on a single confidence score, Phase 4 combines four
independent signals into a composite probability:

| Signal | What it captures |
|--------|-----------------|
| **Sender prior** | Is this sender registered in the allow-list? |
| **Cluster posterior** | How confident is the cluster for this template? |
| **Signal score** | How confident was the rule-based classifier? |
| **Account score** | Was a matching account found in PocketFlow? |

The three components are weighted and summed:

```
score = 0.20 × senderPrior
      + 0.55 × (clusterPosterior × 0.5 + signalScore × 0.5)
      + 0.25 × accountScore
```

Decision thresholds:

| Score | Interpretation | Action |
|-------|---------------|--------|
| ≥ 0.85 | High confidence | Transaction auto-created, no review flag |
| 0.70 – 0.85 | Medium confidence | Transaction created, review optional |
| < 0.70 | Low confidence | Transaction created, **flagged for user review** |

### Phase 5 — Stability Guard

Even a high probability score can be misleading in edge cases. The Stability
Guard checks four adversarial conditions after Phase 4:

| Threat | When it fires | What happens |
|--------|--------------|--------------|
| **Temporal Burst** | > 20 messages/day AND cluster is < 2 days old | Likely a test flood or fraudulent activity; force review |
| **Confidence Divergence** | Composite score differs from cluster confidence by > 0.35 | Signals have drifted apart; force review |
| **Frequent Dispute** | Cluster is `disputed` with ≥ 5 messages | Persistent ambiguity; force review |
| **Stale Knowledge** | `known` cluster not seen for > 90 days | Pattern may be outdated; force review |

Any detected threat sets `needsReview = true` regardless of the probability
score. The threat name is surfaced in the transaction detail view.

### Phase 6 — Replay / Audit

Every transaction created by the Phase 4/5 path writes a snapshot of all
signals to `sms_audit_log`. This record is immutable and never modified.

**What's captured per transaction:**

- Whether the sender was in the allow-list
- Whether the pattern cache matched
- All four probability signal components and the final composite score
- The dominant signal label (`derived_from`)
- The stability threat name
- Whether the transaction needed review
- The pipeline version that produced this decision

**Why this matters:**

- **Debugging**: when a transaction is mis-classified, the audit record shows
  exactly which signal caused the low/high score.
- **Replay**: after improving the pipeline, all historical messages can be
  re-scored and compared to archived decisions.
- **Health metrics**: `countByThreat('temporalBurst', from: weekAgo)` and
  `countNeedsReview(from: weekAgo)` power any operations dashboard.

---

## Review Queue

A transaction is flagged `requiresUserAction = true` when any of the
following apply:

- Composite probability < 0.70
- No matching account was found in PocketFlow
- Any Phase 5 stability threat was detected

Flagged transactions appear in the review queue on the Transactions screen
where the user can confirm, edit, or discard them.

---

## Sender Allow-List & Pattern Cache

The allow-list (`sms_keywords`) and pattern cache (`sms_pattern_cache`) are
the "hot path" that make known-good senders very fast to classify. They are
populated in two ways:

1. **Manual seed**: bank sender addresses are seeded at first launch.
2. **Automatic propagation**: when a cluster transitions to `known` (Phase 3),
   its sender and template hash are added automatically.

Both tables have an `is_active` flag. Deactivating a sender or pattern does
not delete it — the history is preserved for audit purposes.

---

## Frequently Asked Questions

**Q: Why is a transaction from my bank flagged for review?**  
A: Most likely the cluster is still in `learning` status (fewer than 3 prior
messages), the composite probability dropped below 0.70, or the sender is not
yet in the allow-list. Once the system sees a few more messages from the same
template it will become `known` and auto-accept future transactions.

**Q: Why was a duplicate SMS silently dropped?**  
A: The content hash (`SHA-256` of raw body + sender) matched an existing
`sms_events` row. This is intentional — retries and forwarded copies of the
same message should not create duplicate transactions.

**Q: Why did a transaction appear with `temporalBurst` in the review reason?**  
A: More than 20 messages per day arrived from a brand-new template (< 2 days
old). This pattern is consistent with a test send or spoofed message flood,
so the system forces review until the cluster matures.

**Q: Can I replay past SMS messages through a new pipeline version?**  
A: Yes. Query `SmsAuditRepository.queryByDateRange(from, to)` to get archived
signal snapshots, re-fetch the original bodies from `sms_events`, and run
them through the updated pipeline. Use the `pipeline_version` field to
identify which records were produced by the old logic.

**Q: How much storage does the audit log use?**  
A: Each record is approximately 200 bytes. At 50 financial SMS per day the
log grows ~3.5 MB per year. No automatic pruning is implemented.
