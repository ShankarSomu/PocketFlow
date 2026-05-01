"""
prepare_training_data.py

Reads  : test/SMS Training Data Current.csv  (real unmasked SMS data)
Writes : test/sms_training_labeled.csv        (balanced, labeled, ready for training)

Balancing strategy:
  - balance     : cap at MAX_PER_CLASS (real data is 66% balance — too dominant)
  - debit       : cap at MAX_PER_CLASS
  - non_financial: cap at MAX_PER_CLASS
  - credit      : keep all real + augment with synthetic to reach TARGET_MINORITY
  - transfer    : keep all real + augment with synthetic to reach TARGET_MINORITY
  - reminder    : keep all real + augment with synthetic to reach TARGET_MINORITY

Final target distribution (approximate):
  balance        ~1,500
  debit          ~1,500
  non_financial  ~500
  credit         ~500
  transfer       ~500
  reminder       ~500
  ─────────────────────
  Total          ~5,000

Usage:
    python test/prepare_training_data.py
"""

import csv
import re
import os
import random
from collections import defaultdict, Counter

random.seed(42)

INPUT_FILE  = os.path.join(os.path.dirname(__file__), "SMS Training Data Current.csv")
OUTPUT_FILE = os.path.join(os.path.dirname(__file__), "sms_training_balanced.csv")

MAX_PER_CLASS    = 1500   # cap for dominant classes
TARGET_MINORITY  = 500    # target for minority classes after augmentation

# ── Labeling rules (priority order, first match wins) ─────────────────────────

RULES = [
    # non_financial
    (re.compile(
        r'(split your rent|free up your cash flow|'
        r'text\s+[\'"]?stop[\'"]?\s+to\s+(quit|cancel|opt)|'
        r'reply\s+stop|opt.out|msg&data rates|'
        r'finish application|download|install the app|'
        r'click here|tap here|visit us at|'
        r'otp|one.time.password|verification code|do not share)',
        re.I
    ), "non_financial"),

    # reminder
    (re.compile(
        r'(due date|payment due|bill due|minimum.*due|'
        r'pay by|overdue|late fee|'
        r'autopay scheduled|upcoming payment|recurring payment|'
        r'will be (charged|debited|processed|deducted)|'
        r'scheduled (for|on)|'
        r'your payment is due|'
        r'statement.*available|paperless statement)',
        re.I
    ), "reminder"),

    # balance
    (re.compile(
        r'(available balance|total balance|current balance|'
        r'bal(ance)?\s+(is|of\s+\$|plus pending)|'
        r'has a balance of|'
        r'exceeded.*amount set|exceeded.*alert|'
        r'credit limit|available limit|outstanding balance|'
        r'avl\s+bal)',
        re.I
    ), "balance"),

    # transfer
    (re.compile(
        r'(money transfer.*deducted|'
        r'transferred to|transfer from|'
        r'zelle (sent|received|transfer)|'
        r'wire transfer|'
        r'sent to|received from.*account)',
        re.I
    ), "transfer"),

    # credit
    (re.compile(
        r'(direct deposit.*credited|'
        r'credited\s+\d|'
        r'deposited|'
        r'refund|cashback|'
        r'salary|'
        r'credit of|amount credited|'
        r'added to your account|'
        r'received \$)',
        re.I
    ), "credit"),

    # debit
    (re.compile(
        r'(transaction was made at|'
        r'payment posted|'
        r'a \$[\d,]+\.?\d*\s+(transaction|charge|payment)|'
        r'debited|deducted|'
        r'spent|withdrawn|'
        r'charged|'
        r'purchase at|'
        r'used at)',
        re.I
    ), "debit"),
]

def label(text: str) -> str:
    for pattern, lbl in RULES:
        if pattern.search(text):
            return lbl
    if re.search(r'\$[\d,]+', text):
        return "debit"
    return "non_financial"

# ── Synthetic augmentation templates ──────────────────────────────────────────
# Real-looking US bank SMS messages for minority classes.
# Each template is a lambda so amounts/dates/accounts are randomised per call.

def _amt(lo=5, hi=2000):
    v = round(random.uniform(lo, hi), 2)
    return f"{v:,.2f}"

def _acct():
    return str(random.randint(1000, 9999))

def _date():
    months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
    m = random.choice(months)
    d = random.randint(1, 28)
    y = random.choice([2025, 2026])
    return f"{m} {d:02d}, {y}"

def _ref():
    return "".join(random.choices("0123456789", k=12))

CREDIT_TEMPLATES = [
    lambda: f"BofA: Direct deposit of ${_amt(500,4000)} credited {_date()} to account - {_acct()}. STOP to end account texts",
    lambda: f"Chase: A deposit of ${_amt(100,3000)} has been credited to your account ending {_acct()} on {_date()}.",
    lambda: f"Wells Fargo: ${_amt(200,5000)} direct deposit received on {_date()} for account ending in {_acct()}.",
    lambda: f"Citi Alert: A refund of ${_amt(5,200)} has been credited to your card ending in {_acct()}. View at citi.com/citimobileapp",
    lambda: f"Capital One: A payment of ${_amt(20,500)} was credited to your account ending {_acct()} on {_date()}.",
    lambda: f"Discover: Cashback bonus of ${_amt(5,50)} has been credited to your account ending {_acct()}.",
    lambda: f"Chase: Your Zelle payment of ${_amt(50,1000)} from a contact was deposited to account ending {_acct()}.",
    lambda: f"BofA: A refund of ${_amt(10,300)} from AMAZON has been credited to your account ending {_acct()}.",
    lambda: f"Wells Fargo: Payroll deposit of ${_amt(800,4000)} credited to checking account ending {_acct()} on {_date()}.",
    lambda: f"US Bank: Direct deposit of ${_amt(500,3000)} received on {_date()}. Account ending {_acct()}.",
    lambda: f"Ally Bank: ${_amt(100,2000)} deposited to your savings account ending {_acct()} on {_date()}.",
    lambda: f"USAA: A deposit of ${_amt(200,3000)} was credited to your account ending {_acct()} on {_date()}.",
    lambda: f"PNC Bank: Direct deposit of ${_amt(500,4000)} credited on {_date()} to account ending {_acct()}.",
    lambda: f"TD Bank: Your paycheck of ${_amt(800,5000)} was deposited to account ending {_acct()} on {_date()}.",
    lambda: f"Citi Alert: A credit of ${_amt(10,500)} has been applied to your account ending {_acct()}.",
]

TRANSFER_TEMPLATES = [
    lambda: f"BofA: Money transfer of ${_amt(50,2000)} for account - {_acct()} was deducted on {_date()}. STOP to end account texts",
    lambda: f"Chase: You sent ${_amt(20,1000)} via Zelle to a contact on {_date()}. Ref: {_ref()}",
    lambda: f"Wells Fargo: A wire transfer of ${_amt(500,5000)} was sent from your account ending {_acct()} on {_date()}.",
    lambda: f"Zelle: You sent ${_amt(20,500)} to a contact. It will be available shortly.",
    lambda: f"Chase: ${_amt(50,2000)} was transferred from your checking account ending {_acct()} to savings on {_date()}.",
    lambda: f"BofA: Transfer of ${_amt(100,3000)} from account ending {_acct()} to account ending {_acct()} completed on {_date()}.",
    lambda: f"Wells Fargo: You sent ${_amt(50,1000)} to a contact via Zelle on {_date()}.",
    lambda: f"Capital One: A transfer of ${_amt(100,2000)} was made from your account ending {_acct()} on {_date()}.",
    lambda: f"Citi Alert: A transfer of ${_amt(200,5000)} was sent from your account ending {_acct()} on {_date()}.",
    lambda: f"US Bank: Wire transfer of ${_amt(1000,10000)} sent from account ending {_acct()} on {_date()}. Ref: {_ref()}",
    lambda: f"Chase: Zelle payment of ${_amt(20,500)} received from a contact on {_date()}.",
    lambda: f"BofA: ${_amt(50,1000)} transferred to external account on {_date()}. Ref: {_ref()}",
    lambda: f"Ally Bank: Transfer of ${_amt(100,2000)} from checking to savings completed on {_date()}.",
    lambda: f"USAA: You sent ${_amt(50,500)} via Zelle on {_date()}. Funds available immediately.",
]

REMINDER_TEMPLATES = [
    lambda: f"Chase: Your credit card payment of ${_amt(20,500)} is due on {_date()}. Pay now at chase.com",
    lambda: f"Citi Alert: Your minimum payment of ${_amt(25,200)} is due by {_date()}. Pay at citi.com/citimobileapp",
    lambda: f"Capital One: Your payment of ${_amt(20,500)} is due on {_date()}. Msg & data rates may apply.",
    lambda: f"Discover: Your bill of ${_amt(30,600)} is due on {_date()}. Pay at discover.com",
    lambda: f"Wells Fargo: Autopay of ${_amt(50,1000)} scheduled for {_date()} from account ending {_acct()}.",
    lambda: f"BofA: Your credit card payment of ${_amt(25,500)} will be processed on {_date()}.",
    lambda: f"Allstate: ${_amt(50,300)} for your policy will be processed on {_date()}. View at allstate.com",
    lambda: f"PG&E: Recurring payment for Acct#******{_acct()}-8 for ${_amt(30,200)} scheduled for {_date()}.",
    lambda: f"Comcast: Your bill of ${_amt(50,200)} is due on {_date()}. Pay at xfinity.com",
    lambda: f"Verizon: Your payment of ${_amt(50,200)} is due on {_date()}. Pay at verizon.com",
    lambda: f"Chase: Autopay of ${_amt(20,500)} will be charged to your account ending {_acct()} on {_date()}.",
    lambda: f"Citi Alert: Upcoming payment of ${_amt(25,300)} scheduled for {_date()} for account ending {_acct()}.",
    lambda: f"Capital One: Autopay scheduled for ${_amt(20,400)} on {_date()} from account ending {_acct()}.",
    lambda: f"American Express: Your payment of ${_amt(50,1000)} is due by {_date()}. Pay at americanexpress.com",
    lambda: f"US Bank: Your minimum payment of ${_amt(25,200)} is due on {_date()}. Pay at usbank.com",
    lambda: f"Discover: Autopay of ${_amt(30,500)} will be processed on {_date()} from account ending {_acct()}.",
]

SYNTHETIC = {
    "credit":   CREDIT_TEMPLATES,
    "transfer": TRANSFER_TEMPLATES,
    "reminder": REMINDER_TEMPLATES,
}

def generate_synthetic(lbl: str, count: int) -> list[dict]:
    templates = SYNTHETIC[lbl]
    rows = []
    for _ in range(count):
        text = random.choice(templates)()
        rows.append({"text": text, "label": lbl})
    return rows

# ── Main ───────────────────────────────────────────────────────────────────────

def main():
    print(f"Reading {INPUT_FILE} ...")

    # 1. Load and label all real data
    by_label: dict[str, list[str]] = defaultdict(list)
    with open(INPUT_FILE, encoding="utf-8") as f:
        for row in csv.DictReader(f):
            text = (row.get("sms_text") or "").strip()
            if not text:
                continue
            by_label[label(text)].append(text)

    print(f"  Real data label counts:")
    for lbl, texts in sorted(by_label.items(), key=lambda x: -len(x[1])):
        print(f"    {lbl:<16} {len(texts):>5}")

    # 2. Build balanced dataset
    rows_out: list[dict] = []

    # Dominant classes — cap
    for lbl in ["balance", "debit", "non_financial"]:
        texts = by_label.get(lbl, [])
        random.shuffle(texts)
        cap = MAX_PER_CLASS if lbl in ["balance", "debit"] else min(MAX_PER_CLASS, len(texts))
        for t in texts[:cap]:
            rows_out.append({"text": t, "label": lbl})

    # Minority classes — keep all real + augment to target
    for lbl in ["credit", "transfer", "reminder"]:
        real = by_label.get(lbl, [])
        for t in real:
            rows_out.append({"text": t, "label": lbl})
        needed = max(0, TARGET_MINORITY - len(real))
        if needed > 0:
            rows_out.extend(generate_synthetic(lbl, needed))

    # 3. Shuffle final dataset
    random.shuffle(rows_out)

    # 4. Print final distribution
    final_counts: Counter = Counter(r["label"] for r in rows_out)
    total = len(rows_out)
    print(f"\nFinal balanced distribution ({total} total):")
    for lbl, count in final_counts.most_common():
        print(f"  {lbl:<16} {count:>5}  ({count/total*100:.1f}%)")

    # 5. Write output
    print(f"\nWriting {OUTPUT_FILE} ...")
    with open(OUTPUT_FILE, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["text", "label"])
        writer.writeheader()
        writer.writerows(rows_out)

    print(f"Done. {total} rows → {OUTPUT_FILE}")

if __name__ == "__main__":
    main()
