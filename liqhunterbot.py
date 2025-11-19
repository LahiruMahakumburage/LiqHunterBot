import asyncio
import json
import os
import time
from telethon import TelegramClient, events

# ===== CONFIG =====
api_id = 22044713
api_hash = 'f4de9c1a1f8201e83b9222a235453fc0'
bot_token = '8593908913:AAEqfyvLmRVzSMO4__QiSaByrQw0ogqOqkc'
DATA_FILE = "liqhunterbot_data.json"

# ===== DEFAULTS =====
BOT_PASSWORD = "hunter@Nawoo"
MAX_ATTEMPTS = 3
LOCK_TIME = 15 * 60  # 15 min lock
auth_data = {}
source_groups = []       # List of group IDs (source)
destination_groups = []  # List of group IDs (destination)

# ===== LOAD DATA =====
if os.path.exists(DATA_FILE):
    with open(DATA_FILE, "r") as f:
        data = json.load(f)
        source_groups = data.get("sources", [])
        destination_groups = data.get("destinations", [])


def save_data():
    with open(DATA_FILE, "w") as f:
        json.dump({
            "sources": source_groups,
            "destinations": destination_groups
        }, f)


# ===== SIGNAL RESPONSES =====
responses = {
    "dood": "📢 Free Signal 😍 DOOD 🟢 2nd TP Completed ✅",
    "dood 2": "📢 DOOD 🟢 3rd TP Completed 💥",
    "dood 3": "😅 DOOD 🟢 Profit Reaction නෑ 😕",
    "dood 4": "💎 Premium Signal 😍 GOAT 🟢 2nd TP Completed 💥",
    "free": "📢 Free Signal 😍 DOOD 🟢 4th TP Completed 💥",
    "goat": "💎 Premium Signal 😍 GOAT 🟢 2nd TP Completed 💥",
    "goat 3": "💎 Premium Signal 😍 GOAT 🟢 3rd TP Completed 💥",
    "storj": "💎 Premium Signal 😍 STORJ 🟢 1st TP Completed 💥",
    "morph": "💎 Premium Signal 😍 MORPH 🟢 3rd TP Completed 💥",
    "emaster2.1": (
        "🌎 EMASER VIP SIGNAL 🌎\n\n"
        "FIL / USDT\nLONG TRADE 🟢\nENTRY = market - 2.1\n\n"
        "TARGETS:\n2.323\n2.346\n2.36\n2.381\n2.40 🚀\n2.50 🚀\n\n"
        "SL = 2.05\nLeverage = 10x"
    )
}

# ===== HELPER FUNCTIONS =====


def is_authenticated(user_id):
    return auth_data.get(user_id, {}).get("authenticated", False)


def check_lock(user_id):
    return time.time() < auth_data.get(user_id, {}).get("locked_until", 0)


def auth_required(func):
    async def wrapper(event):
        if not is_authenticated(event.sender_id):
            await event.reply("🔒 Please login first with /login <password>")
            return
        await func(event)
    return wrapper

# ===== MAIN BOT =====


async def main():
    asyncio.set_event_loop(asyncio.new_event_loop())

    bot = TelegramClient("liq_bot", api_id, api_hash)
    await bot.start(bot_token=bot_token)
    print("✅ LiqHunter Bot Started...")

    # ===== /start =====
    @bot.on(events.NewMessage(pattern="/start"))
    async def start_cmd(event):
        await event.reply("🔒 Welcome!\nSend password or use: /login <password>")

    # ===== /login =====
    @bot.on(events.NewMessage(pattern="/login"))
    async def login_cmd(event):
        user_id = event.sender_id
        parts = event.raw_text.split(" ")
        if len(parts) < 2:
            await event.reply("⚠ Usage: /login <password>")
            return

        if check_lock(user_id):
            wait_sec = int(auth_data[user_id]["locked_until"] - time.time())
            await event.reply(f"⏳ Too many failed attempts. Try again in {wait_sec}s")
            return

        password = parts[1]
        if password == BOT_PASSWORD:
            auth_data[user_id] = {"authenticated": True, "attempts": 0}
            await event.reply("✅ Login successful!\nUse /help to see commands.")
        else:
            auth_data.setdefault(user_id, {"attempts": 0})
            auth_data[user_id]["attempts"] += 1
            attempts_left = MAX_ATTEMPTS - auth_data[user_id]["attempts"]
            if attempts_left <= 0:
                auth_data[user_id]["locked_until"] = time.time() + LOCK_TIME
                await event.reply("❌ Wrong password too many times. Locked 15 minutes.")
            else:
                await event.reply(f"❌ Wrong password. {attempts_left} attempts left.")

    # ===== /help =====
    @bot.on(events.NewMessage(pattern="/help"))
    @auth_required
    async def help_cmd(event):
        await event.reply(
            "/start - Start and enter password\n"
            "/login <password> - Login\n"
            "/help - Show commands\n"
            "/about - Bot info\n"
            "/addsource <chat_id> - Add source group\n"
            "/removesource <chat_id> - Remove source group\n"
            "/adddestination <chat_id> - Add destination group\n"
            "/removedestination <chat_id> - Remove destination group\n"
            "/listsources - Show source & destination lists"
        )

    # ===== /about =====
    @bot.on(events.NewMessage(pattern="/about"))
    @auth_required
    async def about_cmd(event):
        await event.reply("LiqHunter Bot — Secure Signal Forwarder")

    # ===== GROUP MANAGEMENT =====
    @bot.on(events.NewMessage(pattern="/addsource"))
    @auth_required
    async def add_source(event):
        try:
            chat_id = int(event.raw_text.split(" ")[1])
            if chat_id not in source_groups:
                source_groups.append(chat_id)
                save_data()
                await event.reply(f"✅ Source group added: {chat_id}")
            else:
                await event.reply("⚠ Already exists")
        except:
            await event.reply("⚠ Usage: /addsource <chat_id>")

    @bot.on(events.NewMessage(pattern="/removesource"))
    @auth_required
    async def remove_source(event):
        try:
            chat_id = int(event.raw_text.split(" ")[1])
            if chat_id in source_groups:
                source_groups.remove(chat_id)
                save_data()
                await event.reply(f"🗑 Removed source group: {chat_id}")
            else:
                await event.reply("⚠ Not found")
        except:
            await event.reply("⚠ Usage: /removesource <chat_id>")

    @bot.on(events.NewMessage(pattern="/adddestination"))
    @auth_required
    async def add_destination(event):
        try:
            chat_id = int(event.raw_text.split(" ")[1])
            if chat_id not in destination_groups:
                destination_groups.append(chat_id)
                save_data()
                await event.reply(f"✅ Destination added: {chat_id}")
            else:
                await event.reply("⚠ Already exists")
        except:
            await event.reply("⚠ Usage: /adddestination <chat_id>")

    @bot.on(events.NewMessage(pattern="/removedestination"))
    @auth_required
    async def remove_destination(event):
        try:
            chat_id = int(event.raw_text.split(" ")[1])
            if chat_id in destination_groups:
                destination_groups.remove(chat_id)
                save_data()
                await event.reply(f"🗑 Removed destination group: {chat_id}")
            else:
                await event.reply("⚠ Not found")
        except:
            await event.reply("⚠ Usage: /removedestination <chat_id>")

    @bot.on(events.NewMessage(pattern="/listsources"))
    @auth_required
    async def list_sources(event):
        await event.reply(
            f"📌 Sources:\n{source_groups}\n\n"
            f"📌 Destinations:\n{destination_groups}"
        )

    # ===== SIGNAL HANDLER =====
    @bot.on(events.NewMessage)
    async def signal_handler(event):
        # Add private chat as default source automatically
        if event.chat_id not in source_groups and event.is_private:
            source_groups.append(event.chat_id)
            save_data()

        # Only respond to messages from source groups
        if event.chat_id not in source_groups:
            return

        msg = event.raw_text.strip().lower()
        if msg in responses:
            # Reply in source group/private chat
            await event.reply(responses[msg])
            # Forward to all destinations
            for dest in destination_groups:
                try:
                    await bot.send_message(dest, responses[msg])
                except Exception as e:
                    print(f"Error sending to {dest}: {e}")

    await bot.run_until_disconnected()

# ===== START BOT =====
asyncio.run(main())
