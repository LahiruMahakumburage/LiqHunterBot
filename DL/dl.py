# ==========================
# FWS LiqHunterBot – Forwarder with Emoji Formatting (FIXED)
# ==========================

import asyncio
import re
from telethon import TelegramClient, events

# ===================== CONFIG =====================

api_id = 22044713
api_hash = 'f4de9c1a1f8201e83b9222a235453fc0'
bot_token = '8593908913:AAEqfyvLmRVzSMO4__QiSaByrQw0ogqOqkc'
bot_password = "tinojan@fws"

# Source → Destination
SOURCE_GROUPS = [-5029760630]      # your source group(s)
DESTINATION_GROUPS = [-5003303694]  # your destination group(s)

# ===================== SIGNALS DATABASE =====================
SIGNALS = {
    "xrp": "🟢 XRP – Spot Buy\n\n📥 Entry: Market Price\n⚙️ Isolated 10X\n\n1️⃣ Target: 3.05\n2️⃣ Target: 3.13\n3️⃣ Target: 3.28\n4️⃣ Target: 3.45\n\n🛑 SL: Hold",
    "snx": "🔴 SNX – Short\n\n📥 Entry: Market Price\n⚙️ Isolated 10X\n\n1️⃣ Target: 20%\n2️⃣ Target: 40%\n3️⃣ Target: 60%\n4️⃣ Target: 100%\n\n🛑 SL: 100%",
    "grass": "🔴 GRASS – Short\n\n📥 Entry: Market Price\n⚙️ Isolated 10X\n\n1️⃣ Target: 0.890\n2️⃣ Target: 0.880\n3️⃣ Target: 0.865\n4️⃣ Target: 0.855\n5️⃣ Target: 0.841\n\n🛑 SL: 100%",
    "pengu": "🔴 PENGU – Short\n\n📥 Entry: Market Price\n⚙️ Isolated 10X\n\n1️⃣ Target: 0.0278\n2️⃣ Target: 0.0275\n3️⃣ Target: 0.0270\n4️⃣ Target: 0.0266\n5️⃣ Target: 0.0260\n\n🛑 SL: 100%",
    "the": "🟢 THE – Long\n\n📥 Entry: Market Price\n⚙️ Isolated 10X\n\n1️⃣ Target: 0.420\n2️⃣ Target: 0.425\n3️⃣ Target: 0.430\n4️⃣ Target: 0.444\n5️⃣ Target: 0.459\n\n🛑 SL: 100%",
    "kernel": "🟢 KERNEL – Long\n\n📥 Entry: Market Price\n⚙️ Isolated 10X\n\n1️⃣ Target: 0.1943\n2️⃣ Target: 0.198\n3️⃣ Target: 0.202\n4️⃣ Target: 0.209\n5️⃣ Target: 0.219\n\n🛑 SL: 100%",
    "bera": "🔴 BERA – Short\n\n📥 Entry: Market Price\n⚙️ Isolated 10X\n\n1️⃣ Target: 2.85\n2️⃣ Target: 2.81\n3️⃣ Target: 2.77\n4️⃣ Target: 2.72\n5️⃣ Target: 2.61\n\n🛑 SL: 100%",
    "btc": "🔴 BTC – Short\n\n📥 Entry: Market Price\n⚙️ Cross 10X\n\n1️⃣ Target: 112,000\n2️⃣ Target: 110,000\n3️⃣ Target: 107,000\n4️⃣ Target: 103,000\n\n🛑 SL: 124,000",
    "bnb": "🔴 BNB – Short\n\n📥 Entry: Market Price\n⚙️ Cross 10X\n\n1️⃣ Target: 1010\n2️⃣ Target: 1000\n3️⃣ Target: 987\n4️⃣ Target: 957\n5️⃣ Target: 900\n\n🛑 SL: 100%",
    "sqd": "🔴 SQD – Short\n\n📥 Entry: Market Price\n⚙️ Isolated 10X\n\n1️⃣ Target: 0.227\n2️⃣ Target: 0.224\n3️⃣ Target: 0.220\n4️⃣ Target: 0.215\n\n🛑 SL: 100%",
    "zec": "🔴 ZEC – Short\n\n📥 Entry: Market Price\n⚙️ Isolated 10X\n\n1️⃣ Target: 0.794\n2️⃣ Target: 0.775\n3️⃣ Target: 0.765\n4️⃣ Target: 0.752\n5️⃣ Target: 0.740\n\n🛑 SL: 100%",
    "pump": "🔴 PUMP – Short\n\n📥 Entry: Market Price\n⚙️ Isolated 10X\n\n1️⃣ Target: 0.0063\n2️⃣ Target: 0.0062\n3️⃣ Target: 0.0060\n4️⃣ Target: 0.0057\n\n🛑 SL: 100%",
    "zen": "🔴 ZEN – Short\n\n📥 Entry: Market Price\n⚙️ Isolated 10X\n\n1️⃣ Target: 9.48\n2️⃣ Target: 9.40\n3️⃣ Target: 9.30\n4️⃣ Target: 9.17\n5️⃣ Target: 9.01\n\n🛑 SL: 100%",
    "sol": "🔴 SOL – Short\n\n📥 Entry: Market Price\n⚙️ Isolated 10X\n\n1️⃣ Target: 226\n2️⃣ Target: 223\n3️⃣ Target: 219\n4️⃣ Target: 210\n5️⃣ Target: 201\n\n🛑 SL: 100%"
}

# ===================== ASYNCIO FIX =====================
loop = asyncio.new_event_loop()
asyncio.set_event_loop(loop)

# ===================== CREATE CLIENTS =====================
user_client = TelegramClient('user_session', api_id, api_hash, loop=loop)
bot = TelegramClient('bot_session', api_id, api_hash, loop=loop)
auth = {}

# ===================== AUTH SYSTEM =====================


@bot.on(events.NewMessage(pattern="/start"))
async def start(event):
    # Ignore group messages
    if event.is_group:
        return

    user_id = event.sender_id
    auth[user_id] = False
    await event.reply("🔐 Welcome!\nPlease enter the password to continue:")


@bot.on(events.NewMessage)
async def auth_handler(event):
    # IMPORTANT: SKIP SOURCE GROUP MESSAGES
    if event.chat_id in SOURCE_GROUPS:
        return

    # Also skip bot's own messages
    if event.is_group:
        return

    user_id = event.sender_id
    text = event.raw_text.strip()

    if text.startswith("/") and text != "/start":
        return

    if user_id in auth and not auth[user_id]:
        if text == bot_password:
            auth[user_id] = True
            await event.reply("✅ Login successful!\nType /help")
        else:
            await event.reply("❌ Wrong password!")


def auth_required(func):
    async def wrapper(event):
        if event.is_group:
            return
        user_id = event.sender_id
        if user_id not in auth or not auth[user_id]:
            await event.reply("🔒 Authenticate first using /start")
            return
        await func(event)
    return wrapper


@bot.on(events.NewMessage(pattern="/help"))
@auth_required
async def help_cmd(event):
    await event.reply(
        "📌 **Available Commands**\n"
        "/listsources\n"
    )


@bot.on(events.NewMessage(pattern="/listsources"))
@auth_required
async def list_sources(event):
    await event.reply(
        f"📌 **Sources:** {SOURCE_GROUPS}\n"
        f"📌 **Destinations:** {DESTINATION_GROUPS}"
    )


# ===================== FORWARDER (WORKING VERSION) =====================

@user_client.on(events.NewMessage)
async def forwarder(event):

    # Only forward if message comes from source groups
    if event.chat_id not in SOURCE_GROUPS:
        return

    text = event.raw_text
    if not text:
        return

    # Check if it's a signal command (e.g., /SOL, /BTC, /XRP)
    if text.startswith("/"):
        cmd = text[1:].strip().lower().split()[0]
        if cmd in SIGNALS:
            final_msg = SIGNALS[cmd] + "\n\n💎 Shared via **FWS LiqHunterBot**"
            for dest in DESTINATION_GROUPS:
                try:
                    await bot.send_message(dest, final_msg)
                except Exception as e:
                    print(f"Error sending to {dest}: {e}")
        return

    # Check if message contains trading signal keywords
    text_lower = text.lower()
    required_keywords = ["entry", "target", "tp", "sl", "stop loss"]
    if not any(keyword in text_lower for keyword in required_keywords):
        return

    # ========== FORMAT THE MESSAGE ==========
    lines = text.splitlines()
    final_lines = []
    emoji_numbers = ["", "1️⃣", "2️⃣", "3️⃣", "4️⃣", "5️⃣", "6️⃣", "7️⃣", "8️⃣", "9️⃣"]
    target_count = 0

    for line in lines:
        l = line.strip()
        if not l or l.startswith("/"):
            continue

        low = l.lower()

        # LONG
        if "long" in low and "long" == low:
            final_lines.append("🍌 **Long Banana**")
            continue

        # SHORT
        if "short" in low and "short" == low:
            final_lines.append("🔻 **Short Bear**")
            continue

        # ENTRY
        if "entry" in low:
            entry_val = l.split(':')[-1].strip() if ':' in l else "Market Price"
            final_lines.append(f"📥 **Entry:** {entry_val}")
            continue

        # LEVERAGE
        if "isolated" in low or ("x" in low and any(c.isdigit() for c in l)):
            final_lines.append(f"⚙️ {l}")
            continue

        # TARGETS (TP or Target)
        if "target" in low or "tp" in low:
            nums = re.findall(r"\d+\.?\d*", l)
            for num in nums:
                target_count += 1
                if target_count < len(emoji_numbers):
                    final_lines.append(f"{emoji_numbers[target_count]} **Target:** {num}")
            continue

        # SL
        if "sl" in low or "stop loss" in low:
            sl_val = l.split(':')[-1].strip() if ':' in l else l.replace("sl", "").replace("SL", "").strip()
            final_lines.append(f"🛑 **SL:** {sl_val}")
            continue

    final_msg = "\n".join(final_lines) + \
        "\n\n💎 Shared via **FWS LiqHunterBot**"

    # ========== SEND TO DESTINATION GROUPS ==========
    for dest in DESTINATION_GROUPS:
        try:
            await bot.send_message(dest, final_msg)
        except Exception as e:
            print(f"Error sending to {dest}: {e}")


# ===================== START BOT =====================
async def main():
    await user_client.start()
    await bot.start(bot_token=bot_token)
    print("🔥 FWS LiqHunterBot is running...")
    print(f"📡 Listening to: {SOURCE_GROUPS}")
    print(f"📤 Forwarding to: {DESTINATION_GROUPS}")
    await user_client.run_until_disconnected()

loop.run_until_complete(main())
