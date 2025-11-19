#!/bin/bash
set -e

# ================= CONFIG =================
BOT_USER="botuser"
BOT_DIR="/home/$BOT_USER/liqhunterbot"
BOT_FILE="bot.py"
SERVICE_NAME="liqhunterbot"
PYTHON_BIN="$BOT_DIR/venv/bin/python"

# Telegram credentials
API_ID="22044713"
API_HASH="f4de9c1a1f8201e83b9222a235453fc0"
BOT_TOKEN="8249770888:AAG3OOpi4WfTTEUQSoqI4Ou-dlPRRTcEoJE"

# ================= SCRIPT =================
echo "=== 1. Installing dependencies ==="
sudo apt update
sudo apt install -y python3 python3-venv python3-pip tmux

echo "=== 2. Creating dedicated user ($BOT_USER) ==="
if id "$BOT_USER" &>/dev/null; then
    echo "User $BOT_USER already exists, skipping creation."
else
    sudo adduser --disabled-password --gecos "" $BOT_USER
fi

echo "=== 3. Creating bot directory ==="
sudo mkdir -p $BOT_DIR
sudo chown $BOT_USER:$BOT_USER $BOT_DIR

echo "=== 4. Setting up Python virtual environment ==="
sudo -u $BOT_USER python3 -m venv $BOT_DIR/venv
sudo -u $BOT_USER $PYTHON_BIN -m pip install --upgrade pip
sudo -u $BOT_USER $PYTHON_BIN -m pip install telethon

echo "=== 5. Creating bot.py ==="
sudo -u $BOT_USER tee $BOT_DIR/$BOT_FILE > /dev/null <<'EOF'
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
# Load saved configuration if exists, otherwise set defaults
if os.path.exists(DATA_FILE):
    with open(DATA_FILE, "r") as f:
        data = json.load(f)
        destination_groups = data.get("destinations", [])
        source_groups = data.get("sources", [])
        remove_first_line = data.get("remove_first_line", True)
        first_line_replacement = data.get("first_line_replacement", "")
        required_keywords = data.get("required_keywords", ["leverage", "usdt", "sl", "tp"])
        min_required_keywords = data.get("min_required_keywords", 2)
else:
    # Defaults if no file exists
    destination_groups = []
    source_groups = []
    remove_first_line = True
    first_line_replacement = ""
    required_keywords = ["leverage", "usdt", "sl", "tp"]
    min_required_keywords = 2

# ===== SAVE FUNCTION =====
# Saves current bot settings to JSON file
def save_data():
    with open(DATA_FILE, "w") as f:
        json.dump({
            "sources": source_groups,
            "destinations": destination_groups,
            "remove_first_line": remove_first_line,
            "first_line_replacement": first_line_replacement,
            "required_keywords": required_keywords,
            "min_required_keywords": min_required_keywords
        }, f)

# ===== FOOTER CONTROLS =====
footer_text = "\n\nOffered by Gold Hunter VIP"
footer_enabled = True

# Cache for resolved chat entities (avoids re-fetching)
entity_cache = {}

# ===== PASSWORD SYSTEM =====
BOT_PASSWORD = "hunter@Nawoo"  # Bot access password
MAX_ATTEMPTS = 3             # Maximum wrong attempts before lock
LOCK_TIME = 15 * 60          # Lock time in seconds (15 minutes)

# Store authentication state per-user
auth_data = {}  

# Helper: check if user authenticated
def is_authenticated(user_id: int) -> bool:
    user = auth_data.get(user_id, {})
    return user.get("authenticated", False)

# Helper: check if user is locked due to failed attempts
def check_lock(user_id: int) -> bool:
    user = auth_data.get(user_id, {})
    locked_until = user.get("locked_until", 0)
    return time.time() < locked_until

# ===== CLEAN MESSAGE =====
def clean_message(text: str) -> str:
    """
    Cleans incoming messages:
    - Removes or replaces first line
    - Keeps lines up to 'leverage'
    """
    global remove_first_line, first_line_replacement

    if not text:
        return ""

    lines = text.splitlines()

    # Remove or replace first line
    if remove_first_line and lines:
        if first_line_replacement:
            lines[0] = first_line_replacement
        else:
            lines = lines[1:]

    # Keep all lines until 'leverage' appears
    new_lines = []
    for line in lines:
        new_lines.append(line)
        if "leverage" in line.lower():
            break

    return "\n".join(new_lines).strip()

# ===== TELETHON CLIENTS =====
# User client (reads from source groups)
client = TelegramClient('user_session', api_id, api_hash)
client.start()

# Bot client (sends to destination groups, handles commands)
bot = TelegramClient('bot_session', api_id, api_hash)
bot.start(bot_token=bot_token)

# =================== FORWARDING LOGIC ===================
@client.on(events.NewMessage)
async def handler(event):
    global destination_groups, source_groups, footer_text, footer_enabled
    global entity_cache, required_keywords, min_required_keywords

    if event.chat_id not in source_groups:
        return

    try:
        if not event.message.message:
            return

        original_text = event.message.message

        if "tp" in original_text.lower():
            final_text = f"{original_text}{footer_text}" if footer_enabled else original_text
        else:
            text_lower = original_text.lower()
            matches = sum(1 for word in required_keywords if word in text_lower)
            if matches < min_required_keywords:
                return

            cleaned_text = clean_message(original_text)
            if not cleaned_text:
                return

            final_text = f"{cleaned_text}{footer_text}" if footer_enabled else cleaned_text

        for dest in destination_groups + [-1003043235135]:
            try:
                if dest not in entity_cache:
                    entity_cache[dest] = await bot.get_entity(dest)
                await bot.send_message(entity_cache[dest], final_text)
            except Exception as e:
                print(f"Error sending to {dest}: {e}")

    except Exception as e:
        print("Error handling message:", e)

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
        mins = wait_sec // 60
        secs = wait_sec % 60
        await event.reply(f"⏳ Too many failed attempts. Try again in {mins}m {secs}s.")
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
        user_id = event.sender_id
        if not is_authenticated(user_id):
            await event.reply("🔒 Please enter the password first with /start.")
            return
        await func(event)
    return wrapper

# =================== BOT COMMANDS (Protected) ===================
# /help command
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
        "/setminkeywords <number> - Set minimum required keywords\n"
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

# /about command
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
    status = "enabled ✅" if remove_first_line else "disabled ❌"
    await event.reply(f"First line removal is now {status}")

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

@bot.on(events.NewMessage(pattern='/setminkeywords'))
@auth_required
async def set_min_keywords(event):
    global min_required_keywords
    try:
        value = int(event.message.message.replace("/setminkeywords", "").strip())
        if value > 0:
            min_required_keywords = value
            save_data()
            await event.reply(f"✅ Min required keywords set to {min_required_keywords}")
        else:
            await event.reply("⚠️ Value must be > 0")
    except:
        await event.reply("⚠️ Usage: /setminkeywords <number>")

@bot.on(events.NewMessage(pattern='/showsettings'))
@auth_required
async def show_settings(event):
    status_firstline = "enabled ✅" if remove_first_line else "disabled ❌"
    replacement_text = first_line_replacement if first_line_replacement else "(none)"
    await event.reply(
        "⚙️ **Current Settings:**\n\n"
        f"• First line removal: {status_firstline}\n"
        f"• Replacement: {replacement_text}\n"
        f"• Min keywords: {min_required_keywords}"
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
    status = "enabled ✅" if footer_enabled else "disabled ❌"
    await event.reply(f"Footer is now {status}")

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
EOF

echo "=== 6. Creating systemd service ==="
sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null <<EOF
[Unit]
Description=LiqHunter Telegram Bot
After=network.target

[Service]
Type=simple
User=$BOT_USER
WorkingDirectory=$BOT_DIR
ExecStart=$PYTHON_BIN $BOT_DIR/$BOT_FILE
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

echo "=== 7. Enabling and starting service ==="
sudo systemctl daemon-reload
sudo systemctl enable --now $SERVICE_NAME

echo "=== Setup complete! ==="
echo "Use 'sudo journalctl -u $SERVICE_NAME -f' to view logs."
echo "Bot will start automatically on server reboot."
