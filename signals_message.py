import asyncio
import time
from telethon import TelegramClient, events

# ===== CONFIG =====
api_id = 22044713
api_hash = 'f4de9c1a1f8201e83b9222a235453fc0'
bot_token = '8593908913:AAEqfyvLmRVzSMO4__QiSaByrQw0ogqOqkc'

# ===== SECURITY SETTINGS =====
BOT_PASSWORD = "hunter@Nawoo"
MAX_ATTEMPTS = 3
LOCK_TIME = 15 * 60  # 15 minutes lock

auth_data = {}

# ===== DEFAULT GROUPS =====
source_groups = [-4803848611]        # Only source group
destination_groups = [-5072973587]   # Only destination group

# ========= SHORT MESSAGE RESPONSES ============
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
}

# ========= HELPER FUNCTIONS ============


def is_locked(user_id):
    if user_id in auth_data and "lock_until" in auth_data[user_id]:
        if time.time() < auth_data[user_id]["lock_until"]:
            return True
        else:
            del auth_data[user_id]["lock_until"]
    return False


def is_authenticated(user_id):
    return auth_data.get(user_id, {}).get("logged_in", False)


# ========= MAIN BOT ============
async def main():

    # FIX FOR PYTHON 3.12+ / 3.13 / 3.14
    asyncio.set_event_loop(asyncio.new_event_loop())

    bot = TelegramClient('signals_secure_bot', api_id, api_hash)
    await bot.start(bot_token=bot_token)

    print("✅ Secure Signal Bot Started...")

    # ===== /start =====
    @bot.on(events.NewMessage(pattern="/start"))
    async def start_cmd(event):
        await event.reply(
            "🔒 Welcome to Secure Signal Bot!\n"
            "Please login using:\n\n"
            "`/login your_password`"
        )

    # ===== /login =====
    @bot.on(events.NewMessage(pattern="/login"))
    async def login_handler(event):
        user_id = event.sender_id
        parts = event.raw_text.split(" ")

        if is_locked(user_id):
            remaining = int(auth_data[user_id]["lock_until"] - time.time())
            return await event.reply(f"⛔ Locked. Try again in {remaining} seconds.")

        if len(parts) < 2:
            return await event.reply("⚠ Usage: `/login your_password`")

        password = parts[1]

        if password == BOT_PASSWORD:
            auth_data[user_id] = {"logged_in": True, "attempts": 0}

            commands_list = (
                "/start - Start the bot\n"
                "/help - Show commands\n"
                "/about - Bot info\n"
                "/adddestination <chat_id>\n"
                "/removedestination <chat_id>\n"
                "/addsource <chat_id>\n"
                "/removesource <chat_id>\n"
                "/listsources"
            )

            return await event.reply(
                f"✅ Login Successful!\n\n"
                f"Here are your commands:\n{commands_list}"
            )

        # Wrong password
        if user_id not in auth_data:
            auth_data[user_id] = {"attempts": 0}

        auth_data[user_id]["attempts"] += 1
        left = MAX_ATTEMPTS - auth_data[user_id]["attempts"]

        if left <= 0:
            auth_data[user_id]["lock_until"] = time.time() + LOCK_TIME
            return await event.reply("⛔ Too many attempts! Locked 15 minutes.")

        return await event.reply(f"❌ Wrong password. Attempts left: {left}")

    # ===== /help =====
    @bot.on(events.NewMessage(pattern="/help"))
    async def help_cmd(event):
        if not is_authenticated(event.sender_id):
            return await event.reply("🔐 Please login using /login password")

        commands_list = (
            "/start - Start the bot\n"
            "/help - Show commands\n"
            "/about - Bot info\n"
            "/adddestination <chat_id>\n"
            "/removedestination <chat_id>\n"
            "/addsource <chat_id>\n"
            "/removesource <chat_id>\n"
            "/listsources"
        )

        await event.reply(
            f"📌 **Available Commands:**\n{commands_list}"
        )

    # ===== /about =====
    @bot.on(events.NewMessage(pattern="/about"))
    async def about_cmd(event):
        if not is_authenticated(event.sender_id):
            return await event.reply("🔐 Please login using /login password")
        await event.reply("🤖 Secure Signal Bot v1.0\nCreated by Emaster Tools")

    # ===== GROUP MANAGEMENT =====
    @bot.on(events.NewMessage(pattern="/addsource"))
    async def add_source(event):
        if not is_authenticated(event.sender_id):
            return await event.reply("🔐 Login first.")
        try:
            chat_id = int(event.raw_text.split(" ")[1])
            if chat_id not in source_groups:
                source_groups.append(chat_id)
                await event.reply("📌 Source group added.")
            else:
                await event.reply("⚠ Already exists.")
        except:
            await event.reply("⚠ Usage: /addsource <chat_id>")

    @bot.on(events.NewMessage(pattern="/adddestination"))
    async def add_destination(event):
        if not is_authenticated(event.sender_id):
            return await event.reply("🔐 Login first.")
        try:
            chat_id = int(event.raw_text.split(" ")[1])
            if chat_id not in destination_groups:
                destination_groups.append(chat_id)
                await event.reply("📌 Destination group added.")
            else:
                await event.reply("⚠ Already exists.")
        except:
            await event.reply("⚠ Usage: /adddestination <chat_id>")

    @bot.on(events.NewMessage(pattern="/removesource"))
    async def remove_source(event):
        if not is_authenticated(event.sender_id):
            return await event.reply("🔐 Login first.")
        try:
            chat_id = int(event.raw_text.split(" ")[1])
            if chat_id in source_groups:
                source_groups.remove(chat_id)
                await event.reply("🗑 Removed from source list.")
            else:
                await event.reply("⚠ Not found.")
        except:
            await event.reply("⚠ Usage: /removesource <chat_id>")

    @bot.on(events.NewMessage(pattern="/removedestination"))
    async def remove_destination(event):
        if not is_authenticated(event.sender_id):
            return await event.reply("🔐 Login first.")
        try:
            chat_id = int(event.raw_text.split(" ")[1])
            if chat_id in destination_groups:
                destination_groups.remove(chat_id)
                await event.reply("🗑 Removed from destination list.")
            else:
                await event.reply("⚠ Not found.")
        except:
            await event.reply("⚠ Usage: /removedestination <chat_id>")

    @bot.on(events.NewMessage(pattern="/listsources"))
    async def list_sources(event):
        if not is_authenticated(event.sender_id):
            return await event.reply("🔐 Login first.")
        await event.reply(
            f"📌 **Source Groups:**\n{source_groups}\n\n"
            f"📌 **Destination Groups:**\n{destination_groups}"
        )

    # ===== SHORT SIGNAL REPLIES + AUTO FORWARD =====
    @bot.on(events.NewMessage)
    async def handle_short_words(event):
        msg = event.raw_text.strip().lower()

        # Reply if matches a short signal
        if msg in responses:
            await event.reply(responses[msg])

        # Auto-forward messages from source to all destinations
        if event.chat_id in source_groups:
            for dest in destination_groups:
                await bot.send_message(dest, event.message)

    await bot.run_until_disconnected()


# ========= START BOT =========
asyncio.run(main())
