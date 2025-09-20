import json
import os
import time
from telethon import TelegramClient, events

# ===== CONFIGURE =====
api_id = 22044713
api_hash = 'f4de9c1a1f8201e83b9222a235453fc0'
bot_token = '8249770888:AAG3OOpi4WfTTEUQSoqI4Ou-dlPRRTcEoJE'

# JSON file for saving data (sources, destinations, settings)
DATA_FILE = "liqhunterbot_data.json"

# ===== LOAD DATA =====
if os.path.exists(DATA_FILE):
    with open(DATA_FILE, "r") as f:
        data = json.load(f)
        destination_groups = data.get("destinations", [])
        source_groups = data.get("sources", [])
        remove_first_line = data.get("remove_first_line", True)
        first_line_replacement = data.get("first_line_replacement", "")
else:
    destination_groups = []
    source_groups = []
    remove_first_line = True
    first_line_replacement = ""

# ===== SAVE FUNCTION =====
def save_data():
    with open(DATA_FILE, "w") as f:
        json.dump({
            "sources": source_groups,
            "destinations": destination_groups,
            "remove_first_line": remove_first_line,
            "first_line_replacement": first_line_replacement
        }, f)

# ===== FOOTER CONTROLS =====
footer_text = "\n\nOffered by Gold Hunter VIP"
footer_enabled = True

# Cache for resolved chat entities
entity_cache = {}

# ===== PASSWORD SYSTEM =====
BOT_PASSWORD = "hunter@Nawoo"
MAX_ATTEMPTS = 3
LOCK_TIME = 15 * 60

auth_data = {}

def is_authenticated(user_id: int) -> bool:
    return auth_data.get(user_id, {}).get("authenticated", False)

def check_lock(user_id: int) -> bool:
    return time.time() < auth_data.get(user_id, {}).get("locked_until", 0)

# ===== CLEAN MESSAGE =====
def clean_message(text: str) -> str:
    if not text:
        return ""
    lines = text.splitlines()

    if remove_first_line and lines:
        if first_line_replacement:
            lines[0] = first_line_replacement
        else:
            lines = lines[1:]

    new_lines = []
    for line in lines:
        new_lines.append(line)
        if "leverage" in line.lower():
            break

    return "\n".join(new_lines).strip()

# ===== TELETHON CLIENTS =====
client = TelegramClient('user_session', api_id, api_hash)
client.start()

bot = TelegramClient('bot_session', api_id, api_hash)
bot.start(bot_token=bot_token)

# =================== FORWARDING LOGIC ===================
@client.on(events.NewMessage)
async def handler(event):
    global destination_groups, source_groups, footer_text, footer_enabled, entity_cache

    if event.chat_id not in source_groups:
        return
    if not event.message.message:
        return

    original_text = event.message.message
    text_lower = original_text.lower()

    # Required keyword groups
    group1 = ["tp", "take profit", "targets"]
    group2 = ["sl", "stop loss"]
    group3 = ["long", "short"]

    has_group1 = any(word in text_lower for word in group1)
    has_group2 = any(word in text_lower for word in group2)
    has_group3 = any(word in text_lower for word in group3)

    if not (has_group1 and has_group2 and has_group3):
        return

    # ===== Special rule: If TP exists anywhere =====
    if "tp" in text_lower:
        final_text = f"{original_text}{footer_text}" if footer_enabled else original_text
    else:
        cleaned_text = clean_message(original_text)
        if not cleaned_text:
            return
        final_text = f"{cleaned_text}{footer_text}" if footer_enabled else cleaned_text

    # ===== Send to destinations =====
    for dest in destination_groups + [-1003043235135]:
        try:
            if dest not in entity_cache:
                entity_cache[dest] = await bot.get_entity(dest)
            await bot.send_message(entity_cache[dest], final_text)
        except Exception as e:
            print(f"Error sending to {dest}: {e}")

# =================== PASSWORD HANDLING ===================
@bot.on(events.NewMessage(pattern='/start'))
async def start_command(event):
    user_id = event.sender_id
    auth_data[user_id] = {"authenticated": False, "attempts": 0, "locked_until": 0}
    await event.reply("🔒 Welcome! Please enter the password to continue:")

@bot.on(events.NewMessage)
async def password_handler(event):
    user_id = event.sender_id
    msg = event.raw_text.strip()

    if user_id not in auth_data:
        return
    if auth_data[user_id].get("authenticated"):
        return
    if msg.lower().startswith("/start"):
        return

    if check_lock(user_id):
        wait_sec = int(auth_data[user_id]["locked_until"] - time.time())
        await event.reply(f"⏳ Too many failed attempts. Try again in {wait_sec//60}m {wait_sec%60}s.")
        return

    if msg == BOT_PASSWORD:
        auth_data[user_id]["authenticated"] = True
        auth_data[user_id]["attempts"] = 0
        await event.reply("✅ Password correct! You can now use all commands.\n/help - Show commands")
    else:
        auth_data[user_id]["attempts"] += 1
        attempts_left = MAX_ATTEMPTS - auth_data[user_id]["attempts"]
        if attempts_left <= 0:
            auth_data[user_id]["locked_until"] = time.time() + LOCK_TIME
            auth_data[user_id]["attempts"] = 0
            await event.reply("❌ Wrong password too many times.\n⏳ Locked for 15 minutes.")
        else:
            await event.reply(f"❌ Wrong password. {attempts_left} attempts left.")

# ===== COMMAND WRAPPER =====
def auth_required(func):
    async def wrapper(event):
        if not is_authenticated(event.sender_id):
            await event.reply("🔒 Please enter the password first with /start.")
            return
        await func(event)
    return wrapper

# =================== BOT COMMANDS ===================
@bot.on(events.NewMessage(pattern='/help'))
@auth_required
async def help_command(event):
    await event.reply(
        "📌 **LiqHunter Commands:**\n"
        "/start - Start the bot\n"
        "/help - Show commands\n"
        "/about - Bot info\n\n"
        "✂️ **Message Cleaning:**\n"
        "/togglefirstline - Enable/Disable removing the first line\n"
        "/setfirstline <text> - Replace the first line\n"
        "/showsettings - Show cleaning settings\n\n"
        "📤 **Group Management:**\n"
        "/adddestination <chat_id>\n"
        "/removedestination <chat_id>\n"
        "/addsource <chat_id>\n"
        "/removesource <chat_id>\n"
        "/listsources - Show sources & destinations\n\n"
        "📝 **Footer:**\n"
        "/setfooter <text>\n"
        "/togglefooter"
    )

@bot.on(events.NewMessage(pattern='/about'))
@auth_required
async def about_command(event):
    await event.reply("LiqHunter v1.0\nDeveloped by Lahiru Mahakumburage")

# ========== CLEANING SETTINGS ==========
@bot.on(events.NewMessage(pattern='/togglefirstline'))
@auth_required
async def toggle_firstline(event):
    global remove_first_line
    remove_first_line = not remove_first_line
    save_data()
    await event.reply(f"First line removal is now {'enabled ✅' if remove_first_line else 'disabled ❌'}")

@bot.on(events.NewMessage(pattern='/setfirstline'))
@auth_required
async def set_firstline(event):
    global first_line_replacement
    new_text = event.message.message.replace("/setfirstline", "").strip()
    if new_text:
        first_line_replacement = new_text
        save_data()
        await event.reply(f"✅ First line will now be replaced with:\n{first_line_replacement}")
    else:
        first_line_replacement = ""
        save_data()
        await event.reply("✅ First line replacement cleared.")

@bot.on(events.NewMessage(pattern='/showsettings'))
@auth_required
async def show_settings(event):
    status_firstline = "enabled ✅" if remove_first_line else "disabled ❌"
    replacement_text = first_line_replacement if first_line_replacement else "(none)"
    await event.reply(
        "⚙️ **Current Settings:**\n\n"
        f"• First line removal: {status_firstline}\n"
        f"• Replacement: {replacement_text}"
    )

# ========== FOOTER SETTINGS ==========
@bot.on(events.NewMessage(pattern='/setfooter'))
@auth_required
async def set_footer(event):
    global footer_text
    new_footer = event.message.message.replace("/setfooter", "").strip()
    if new_footer:
        footer_text = f"\n\n{new_footer}"
        await event.reply(f"✅ Footer updated:\n{footer_text.strip()}")
    else:
        await event.reply("⚠️ Usage: /setfooter Your footer text")

@bot.on(events.NewMessage(pattern='/togglefooter'))
@auth_required
async def toggle_footer(event):
    global footer_enabled
    footer_enabled = not footer_enabled
    await event.reply(f"Footer is now {'enabled ✅' if footer_enabled else 'disabled ❌'}")

# ========== GROUP MANAGEMENT ==========
@bot.on(events.NewMessage(pattern='/adddestination'))
@auth_required
async def add_destination(event):
    global destination_groups, entity_cache
    try:
        new_dest = int(event.message.message.replace("/adddestination", "").strip())
        if new_dest not in destination_groups:
            destination_groups.append(new_dest)
            entity_cache.pop(new_dest, None)
            save_data()
            await event.reply(f"✅ Destination added: {new_dest}")
        else:
            await event.reply("⚠️ Already in list.")
    except:
        await event.reply("⚠️ Usage: /adddestination <chat_id>")

@bot.on(events.NewMessage(pattern='/removedestination'))
@auth_required
async def remove_destination(event):
    global destination_groups, entity_cache
    try:
        rem_dest = int(event.message.message.replace("/removedestination", "").strip())
        if rem_dest in destination_groups:
            destination_groups.remove(rem_dest)
            entity_cache.pop(rem_dest, None)
            save_data()
            await event.reply(f"✅ Destination removed: {rem_dest}")
        else:
            await event.reply("⚠️ Not in list.")
    except:
        await event.reply("⚠️ Usage: /removedestination <chat_id>")

@bot.on(events.NewMessage(pattern='/addsource'))
@auth_required
async def add_source(event):
    global source_groups
    try:
        new_source = int(event.message.message.replace("/addsource", "").strip())
        if new_source not in source_groups:
            source_groups.append(new_source)
            save_data()
            await event.reply(f"✅ Source added: {new_source}")
        else:
            await event.reply("⚠️ Already in list.")
    except:
        await event.reply("⚠️ Usage: /addsource <chat_id>")

@bot.on(events.NewMessage(pattern='/removesource'))
@auth_required
async def remove_source(event):
    global source_groups
    try:
        rem_source = int(event.message.message.replace("/removesource", "").strip())
        if rem_source in source_groups:
            source_groups.remove(rem_source)
            save_data()
            await event.reply(f"✅ Source removed: {rem_source}")
        else:
            await event.reply("⚠️ Not in list.")
    except:
        await event.reply("⚠️ Usage: /removesource <chat_id>")

@bot.on(events.NewMessage(pattern='/listsources'))
@auth_required
async def list_sources(event):
    await event.reply(
        f"📌 Sources:\n{source_groups}\n\n"
        f"📌 Destinations:\n{destination_groups}\n"
    )

# =================== RUN BOT ===================
print("LiqHunter running... Forwarding messages now!")
client.run_until_disconnected()
