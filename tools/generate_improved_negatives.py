"""Generate realistic non-financial SMS negatives across multiple categories for review.

Creates: tools/non_financial_sample_improved.jsonl (default 200 samples)

Categories included:
 - Delivery / logistics (Amazon/UPS/FedEx) with tracking numbers and links
 - Login / security alerts (Google/Apple/bank 2FA and alerts)
 - Merchant receipts / order confirmations (non-financial patterns)
 - App notifications (Uber/Spotify/Airbnb style)
 - Misc: appointment, delivery ETA, service alerts

Adds sender IDs, multi-line messages, emojis, light typos, shortened links, and small variations.
"""
from pathlib import Path
import random
import json
import datetime
import re
from collections import defaultdict

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'tools' / 'non_financial_sample_improved.jsonl'
OUT.parent.mkdir(parents=True, exist_ok=True)

NUM = 200
random.seed(12345)

SENDERS = ['AMZN','UPS','FEDEX','GOOGLE','APPLE','UBER','SPOTIFY','NETFLIX','AIRBNB','DELIV']
MERCHANTS = ['Amazon','Walmart','Target','Best Buy','Netflix','Uber Eats','DoorDash','Whole Foods','IKEA','Starbucks']
SHORT_DOMAINS = ['amzn.to','bit.ly','tiny.cc','short.ly','lnk.to']

def tracking_code(fmt='1Z{rand:9d}'):
    if fmt.startswith('1Z'):
        return '1Z' + ''.join(str(random.randint(0,9)) for _ in range(16))
    return ''.join(random.choice('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789') for _ in range(10))

def short_link():
    return f"https://{random.choice(SHORT_DOMAINS)}/{''.join(random.choice('abcdefghijklmnopqrstuvwxyz') for _ in range(6))}"

# Templates

def gen_delivery():
    carrier = random.choice(['UPS','FedEx','AMZN','USPS'])
    sender = carrier if carrier!='AMZN' else 'AMZN'
    tn = tracking_code()
    eta_days = random.choice([0,1,2])
    eta = (datetime.date.today() + datetime.timedelta(days=eta_days)).strftime('%b %d')
    templates = [
        f"{sender}: Your package {tn} is out for delivery. ETA {eta}. Track: {short_link()}",
        f"{sender}: Shipment {tn} delivered at 15:42. If not received, visit {short_link()}",
        f"{sender}: Delivery update: Your package {tn} will arrive today between 9AM-1PM.",
        f"{sender}: {random.choice(MERCHANTS)} order #{random.randint(10000,99999)} shipped. Track: {short_link()}",
        f"{sender}: Package {tn} is delayed. New ETA: {eta}. Sorry for the inconvenience.",
    ]
    return random.choice(templates)

def gen_login_security():
    provider = random.choice(['Google','Apple','YourBank','Microsoft'])
    code = random.randint(100000,999999)
    templates = [
        f"{provider}: New sign-in to your account from Chrome on Windows. If this wasn't you, secure: {short_link()}",
        f"{provider}: Your verification code is {code}. It will expire in 10 minutes.",
        f"{provider}: Suspicious activity detected. Password changed. If this wasn't you, visit {short_link()}",
        f"{provider}: 2FA: {code} for login to your account.",
        f"{provider}: We detected a new device sign-in. Was this you? Reply YES/NO or visit {short_link()}",
    ]
    return random.choice(templates)

def gen_receipt():
    m = random.choice(MERCHANTS)
    order = random.randint(1000000,9999999)
    total = round(random.uniform(5,250),2)
    templates = [
        f"{m}: Thanks for your order #{order}. Total ${total}. Pickup at {random.choice(['Store','Locker','Curb'])} at 3:30 PM.",
        f"{m}: Your order {order} is confirmed. We'll notify you when it's ready. Track: {short_link()}",
        f"{m}: Your digital receipt for order #{order}. Amount: ${total}. View: {short_link()}",
        f"{m}: Order #{order} ready for pickup at {random.choice(['Store 12','Locker A'])}. Show this text.",
    ]
    return random.choice(templates)

def gen_app_notification():
    app = random.choice(['Uber','Spotify','Airbnb','DoorDash'])
    templates = [
        f"{app.upper()}: Your ride with John (4.8★) is arriving in 2 mins. Plate ABC-123.",
        f"{app}: Your booking at {random.choice(['Hilton','Airbnb'])} is confirmed. Check-in: 3PM.",
        f"{app}: New episode available. Listen now: {short_link()}",
        f"{app}: Your {random.choice(['delivery','ride'])} is on the way 🚗. Driver: Mike. ETA 8 min.",
    ]
    return random.choice(templates)

def gen_misc():
    templates = [
        f"Reminder: Your appointment with Dr. Smith is on {random.choice(['Mon','Tue','Apr 21'])} at 10:00 AM.",
        f"Alert: Your subscription to {random.choice(['Spotify','Netflix'])} renews on {random.choice(['May 1','Jun 5'])}.",
        f"Delivery: Parcel arriving today. Track {short_link()}",
        f"{random.choice(SENDERS)}: Msg from service. Reply STOP to cancel.",
    ]
    return random.choice(templates)

# Variation helpers

def maybe_multiline(txt):
    if random.random() < 0.25:
        parts = txt.split('. ')
        if len(parts)>1:
            return parts[0].strip()+"\n"+('. '.join(parts[1:]).strip())
    return txt

def maybe_sender_prefix(txt):
    if random.random() < 0.5:
        return f"{random.choice(SENDERS)}: {txt}"
    return txt

def maybe_typo(txt):
    if random.random() < 0.08:
        # introduce small typo
        i = random.randint(0, max(0, len(txt)-1))
        c = random.choice('abcdefghijklmnopqrstuvwxyz')
        txt = txt[:i]+c+txt[i+1:]
    return txt

# Generate samples
out = []
for i in range(NUM):
    cat = random.choices(['delivery','login','receipt','app','misc'], weights=[0.3,0.25,0.2,0.15,0.1])[0]
    if cat=='delivery': txt = gen_delivery()
    elif cat=='login': txt = gen_login_security()
    elif cat=='receipt': txt = gen_receipt()
    elif cat=='app': txt = gen_app_notification()
    else: txt = gen_misc()
    txt = maybe_sender_prefix(txt)
    txt = maybe_multiline(txt)
    txt = maybe_typo(txt)
    # small chance add emoji
    if random.random() < 0.15:
        txt = txt + ' 👍'
    rec = {"text": txt, "bank_name": None, "amount": None, "account_number": None, "merchant": None, "date": None, "raw_type_keyword": None}
    out.append(rec)

# Cap per template family: simple approach - group by normalized lower-case stripped text pattern ignoring numbers
def family_key(s):
    k = s.lower()
    # remove numbers and short links
    k = re.sub(r'\d+', '<NUM>', k)
    k = re.sub(r'https?://\S+', '<URL>', k)
    k = re.sub(r'\s+', ' ', k).strip()
    return k

families = defaultdict(list)
for r in out:
    families[family_key(r['text'])].append(r)

# cap to max_per_family
max_per_family = 5
final = []
for fam, members in families.items():
    final.extend(members[:max_per_family])

# shuffle and trim to NUM
random.shuffle(final)
final = final[:NUM]

# write
with OUT.open('w', encoding='utf-8') as f:
    for r in final:
        f.write(json.dumps(r, ensure_ascii=False) + '\n')

print(f"Wrote {len(final)} improved non-financial samples to {OUT}")
for i, r in enumerate(final[:40],1):
    print('--- SAMPLE', i, '---')
    print(r['text'])
    print()



