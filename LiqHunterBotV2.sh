#!/bin/bash
set -e

# ================= CONFIG =================
BOT_USER="botuser"
BOT_DIR="/home/$BOT_USER/liqhunterbotV2"
BOT_FILE="bot.py"
SERVICE_NAME="liqhunterbotV2"
PYTHON_BIN="$BOT_DIR/venv/bin/python"

# Telegram credentials
API_ID=26204033
API_HASH="5b104e183a87f8f7f508ca4a776ba707"
BOT_TOKEN="7652362104:AAH20dRzenPEBKq7hBkifq02n6VtdAU-Yek"

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
api_id = 26204033
api_hash = '5b104e183a87f8f7f508ca4a776ba707'
bot_token = '7652362104:AAH20dRzenPEBKq7hBkifq02n6VtdAU-Yek'

# JSON file for saving all configuration data
DATA_FILE = "liqhunterbot_V2_data.json"

# This will hold all configuration for all 8 groups
bot_config = {}

# ===== DEFAULT GROUP STRUCTURE =====
DEFAULT_GROUP_SETTINGS = {
    "name": "Untitled Group",
    "sources": [],
    "destinations": [],
    "remove_first_line": True,
    "first_line_replacement": "",
    "header_to_remove": "",  # For Group 4's special rule
    "footer_text": "\n\nOffered by Gold Hunter VIP",
    "footer_enabled": True
}

# ===== LOAD DATA =====
# Load saved configuration if exists, otherwise set defaults


def load_data():
    global bot_config
    if os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE, "r") as f:
                bot_config = json.load(f)
                # Ensure all 8 groups exist in config
                for i in range(1, 9):
                    if f"group{i}" not in bot_config:
                        bot_config[f"group{i}"] = DEFAULT_GROUP_SETTINGS.copy()
            print("Successfully loaded data from file.")
        except Exception as e:
            print(f"Error loading {DATA_FILE}, starting fresh: {e}")
            init_default_config()
    else:
        print("No data file found, initializing default config.")
        init_default_config()

    # Set/Update names from your spec
    bot_config["group1"]["name"] = "LiqHunter (Original)"
    bot_config["group2"]["name"] = "Crypto advance 60"
    bot_config["group3"]["name"] = "DL 60"
    bot_config["group4"]["name"] = "E master"
    bot_config["group5"]["name"] = "Alex vip 60"
    bot_config["group6"]["name"] = "Master crypto vip 6"
    bot_config["group7"]["name"] = "Color crypto 60"
    bot_config["group8"]["name"] = "Eagle vip 6"

    save_data()  # Save any changes (like new names)


def init_default_config():
    global bot_config
    bot_config = {}
    for i in range(1, 9):
        bot_config[f"group{i}"] = DEFAULT_GROUP_SETTINGS.copy()

# ===== SAVE FUNCTION =====


def save_data():
    with open(DATA_FILE, "w") as f:
        json.dump(bot_config, f, indent=4)


# Cache for resolved chat entities (avoids re-fetching)
entity_cache = {}

# ===== PASSWORD SYSTEM =====
BOT_PASSWORD = "hunter@Nawoo"  # Bot access password
MAX_ATTEMPTS = 3               # Maximum wrong attempts before lock
LOCK_TIME = 15 * 60            # Lock time in seconds (15 minutes)

# Store authentication state AND management context per-user
# "managing" will store which group (e.g., "group1") they are editing
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

# Helper: get the group key (e.g. "group1") the user is currently managing


def get_managing_group(user_id: int):
    return auth_data.get(user_id, {}).get("managing")

# ===== FILTERING LOGIC (NEW FLEXIBLE STYLE) =====


def passes_filter_group1(text_lower):
    # Logic: (leverage) AND (sl OR stop loss) AND (tp OR take profit OR targets)
    # This is based on your original group1 spec, but using the new synonym logic
    g_lev = ["leverage"]
    g_sl = ["sl", "stop loss"]
    g_tp = ["tp", "take profit", "targets"]

    has_lev = any(w in text_lower for w in g_lev)
    has_sl = any(w in text_lower for w in g_sl)
    has_tp = any(w in text_lower for w in g_tp)

    return has_lev and has_sl and has_tp


def passes_filter_group2(text_lower):
    # Logic: (usdt) AND (long OR short)
    g_curr = ["usdt"]
    g_dir = ["long", "short"]

    has_curr = any(w in text_lower for w in g_curr)
    has_dir = any(w in text_lower for w in g_dir)

    return has_curr and has_dir


def passes_filter_group3(text_lower):
    # Logic: (long OR short) AND (sl OR stop loss)
    g_dir = ["long", "short"]
    g_sl = ["sl", "stop loss"]

    has_dir = any(w in text_lower for w in g_dir)
    has_sl = any(w in text_lower for w in g_sl)

    return has_dir and has_sl


def passes_filter_group4(text_lower):
    # Logic: (usdt) AND (long OR short) AND (sl OR stop loss)
    # THIS IS THE FILTER FOR YOUR TEST MESSAGE
    g_curr = ["usdt"]
    g_dir = ["long", "short"]
    g_sl = ["sl", "stop loss"]

    has_curr = any(w in text_lower for w in g_curr)
    has_dir = any(w in text_lower for w in g_dir)
    has_sl = any(w in text_lower for w in g_sl)

    return has_curr and has_dir and has_sl


def passes_filter_group5(text_lower):
    # Logic: (usdt AND entry) AND (long OR short)
    g_curr = ["usdt"]
    g_entry = ["entry"]
    g_dir = ["long", "short"]

    has_curr = any(w in text_lower for w in g_curr)
    has_entry = any(w in text_lower for w in g_entry)
    has_dir = any(w in text_lower for w in g_dir)

    return (has_curr and has_entry) and has_dir


def passes_filter_group6(text_lower):
    # Logic: (usdt) AND (long OR short) AND (entry)
    # Same as group 5
    return passes_filter_group5(text_lower)


def passes_filter_group7(text_lower):
    # Logic: (long OR short) AND (stop loss) AND (usdt)
    g_dir = ["long", "short"]
    g_sl = ["stop loss"]  # Spec was specific, but "sl" could be added
    g_curr = ["usdt"]

    has_dir = any(w in text_lower for w in g_dir)
    has_sl = any(w in text_lower for w in g_sl)
    has_curr = any(w in text_lower for w in g_curr)

    return has_dir and has_sl and has_curr


def passes_filter_group8(text_lower):
    # Logic: (wallet) AND ((sell OR buy) OR (long OR short))
    g_wallet = ["wallet"]
    g_action1 = ["sell", "buy"]
    g_action2 = ["long", "short"]

    has_wallet = any(w in text_lower for w in g_wallet)
    has_action1 = any(w in text_lower for w in g_action1)
    has_action2 = any(w in text_lower for w in g_action2)

    return has_wallet and (has_action1 or has_action2)

# ===== CLEAN MESSAGE =====


def clean_message(text: str, config: dict) -> str:
    """
    Cleans incoming messages based on per-group config.
    """
    if not text:
        return ""

    lines = text.splitlines()

    # 1. Custom header removal (for Group 4)
    header_to_remove = config.get("header_to_remove", "")
    if header_to_remove and lines:
        if header_to_remove.lower() in lines[0].lower():
            lines = lines[1:]  # Remove header line

    # 2. First line removal/replacement
    remove_first_line = config.get("remove_first_line", False)
    first_line_replacement = config.get("first_line_replacement", "")

    if remove_first_line and lines:
        if first_line_replacement:
            lines[0] = first_line_replacement
        else:
            lines = lines[1:]

    return "\n".join(lines).strip()

# ===== FORWARDING HELPER =====


async def process_and_forward(original_text: str, config: dict):
    """
    Helper to clean, footer, and forward a message based on its config.
    """
    global entity_cache

    cleaned_text = clean_message(original_text, config)
    if not cleaned_text:
        # Message was cleaned to nothing, stop processing
        print("[DEBUG] Message was cleaned to empty string. Not forwarding.")
        return

    # Add footer (if enabled for this group)
    final_text = cleaned_text
    if config.get("footer_enabled", True):
        footer = config.get("footer_text", "")
        if footer:  # Only add if footer is not empty
            final_text += footer

    # Forward to all destinations for this group
    for dest in config.get("destinations", []):
        try:
            if dest not in entity_cache:
                print(f"[DEBUG] Caching entity for destination: {dest}")
                entity_cache[dest] = await bot.get_entity(dest)

            await bot.send_message(entity_cache[dest], final_text)
            print(f"[DEBUG] Successfully forwarded to {dest}")

        except Exception as e:
            print(f"[!!! ERROR !!!] Error sending to destination {dest}: {e}")

# ===== TELETHON CLIENTS =====
# Load data *before* starting clients
load_data()

# User client (reads from source groups)
client = TelegramClient('user_session', api_id, api_hash)
client.start()

# Bot client (sends to destination groups, handles commands)
bot = TelegramClient('bot_session', api_id, api_hash)
bot.start(bot_token=bot_token)

# =================== FORWARDING LOGIC (NEW WITH DEBUG) ===================


@client.on(events.NewMessage)
async def handler(event):
    global bot_config, entity_cache

    if not event.message.message:
        return

    chat_id = event.chat_id
    original_text = event.message.message
    text_lower = original_text.lower()

    # --- DEBUG PRINT 1 ---
    print(f"\n[DEBUG] New message received from chat_id: {chat_id}")
    # print(f"[DEBUG] Message text: {original_text[:50]}...") # You can uncomment this for more detail

    try:
        # --- This is the explicit "nested if" logic ---

        # 1. Check for Group 1
        if chat_id in bot_config["group1"]["sources"]:
            print("[DEBUG] Message is from a Group 1 source.")
            if passes_filter_group1(text_lower):
                print("[DEBUG] PASSED Group 1 filter. Forwarding...")
                await process_and_forward(original_text, bot_config["group1"])
            else:
                print("[DEBUG] FAILED Group 1 filter (keywords not matched).")

        # 2. Check for Group 2
        elif chat_id in bot_config["group2"]["sources"]:
            print("[DEBUG] Message is from a Group 2 source.")
            if passes_filter_group2(text_lower):
                print("[DEBUG] PASSED Group 2 filter. Forwarding...")
                await process_and_forward(original_text, bot_config["group2"])
            else:
                print("[DEBUG] FAILED Group 2 filter (keywords not matched).")

        # 3. Check for Group 3
        elif chat_id in bot_config["group3"]["sources"]:
            print("[DEBUG] Message is from a Group 3 source.")
            if passes_filter_group3(text_lower):
                print("[DEBUG] PASSED Group 3 filter. Forwarding...")
                await process_and_forward(original_text, bot_config["group3"])
            else:
                print("[DEBUG] FAILED Group 3 filter (keywords not matched).")

        # 4. Check for Group 4
        elif chat_id in bot_config["group4"]["sources"]:
            print("[DEBUG] Message is from a Group 4 source.")
            if passes_filter_group4(text_lower):
                print("[DEBUG] PASSED Group 4 filter. Forwarding...")
                await process_and_forward(original_text, bot_config["group4"])
            else:
                print("[DEBUG] FAILED Group 4 filter (keywords not matched).")

        # 5. Check for Group 5
        elif chat_id in bot_config["group5"]["sources"]:
            print("[DEBUG] Message is from a Group 5 source.")
            if passes_filter_group5(text_lower):
                print("[DEBUG] PASSED Group 5 filter. Forwarding...")
                await process_and_forward(original_text, bot_config["group5"])
            else:
                print("[DEBUG] FAILED Group 5 filter (keywords not matched).")

        # 6. Check for Group 6
        elif chat_id in bot_config["group6"]["sources"]:
            print("[DEBUG] Message is from a Group 6 source.")
            if passes_filter_group6(text_lower):
                print("[DEBUG] PASSED Group 6 filter. Forwarding...")
                await process_and_forward(original_text, bot_config["group6"])
            else:
                print("[DEBUG] FAILED Group 6 filter (keywords not matched).")

        # 7. Check for Group 7
        elif chat_id in bot_config["group7"]["sources"]:
            print("[DEBUG] Message is from a Group 7 source.")
            if passes_filter_group7(text_lower):
                print("[DEBUG] PASSED Group 7 filter. Forwarding...")
                await process_and_forward(original_text, bot_config["group7"])
            else:
                print("[DEBUG] FAILED Group 7 filter (keywords not matched).")

        # 8. Check for Group 8
        elif chat_id in bot_config["group8"]["sources"]:
            print("[DEBUG] Message is from a Group 8 source.")
            if passes_filter_group8(text_lower):
                print("[DEBUG] PASSED Group 8 filter. Forwarding...")
                await process_and_forward(original_text, bot_config["group8"])
            else:
                print("[DEBUG] FAILED Group 8 filter (keywords not matched).")

        else:
            # --- DEBUG PRINT 2 ---
            print(
                f"[DEBUG] Message from {chat_id} is not in any configured source list. Ignoring.")

    except Exception as e:
        # --- DEBUG PRINT 3 ---
        print(f"\n[!!! ERROR !!!] Error in main handler: {e}\n")

# =================== PASSWORD HANDLING ===================


@bot.on(events.NewMessage(pattern='/start'))
async def start_command(event):
    user_id = event.sender_id
    # Reset user state
    auth_data[user_id] = {"authenticated": False,
                          "attempts": 0, "locked_until": 0, "managing": None}
    await event.reply("🔐 **Welcome!**\nPlease enter the password to continue:")


@bot.on(events.NewMessage)
async def password_handler(event):
    user_id = event.sender_id
    msg = event.raw_text.strip()

    if user_id not in auth_data:
        return  # User hasn't typed /start
    if auth_data[user_id].get("authenticated"):
        return  # Already authenticated, skip password check
    if msg.lower().startswith("/"):
        return  # Don't check commands as passwords

    # Check lock
    if check_lock(user_id):
        wait_sec = int(auth_data[user_id]["locked_until"] - time.time())
        mins = wait_sec // 60
        secs = wait_sec % 60
        await event.reply(f"⏳ **Too many failed attempts.**\nTry again in {mins}m {secs}s.")
        return

    # Check password
    if msg == BOT_PASSWORD:
        auth_data[user_id]["authenticated"] = True
        auth_data[user_id]["attempts"] = 0
        await event.reply("✅ **Password Correct!**\nYou can now use all commands.\n\n"
                          "**Please select a group to manage:**")
        await show_group_selection(event)
    else:
        auth_data[user_id]["attempts"] += 1
        attempts_left = MAX_ATTEMPTS - auth_data[user_id]["attempts"]
        if attempts_left <= 0:
            auth_data[user_id]["locked_until"] = time.time() + LOCK_TIME
            auth_data[user_id]["attempts"] = 0
            await event.reply("❌ **Access Denied!**\nWrong password too many times.\n⏳ Locked for 15 minutes.")
        else:
            await event.reply(f"❌ **Wrong password.** {attempts_left} attempts left.")

# ===== COMMAND WRAPPER =====


def auth_required(func):
    """
    Decorator to check if a user is authenticated.
    """
    async def wrapper(event):
        user_id = event.sender_id
        if not is_authenticated(user_id):
            await event.reply("⛔️ **Access Required!**\nPlease use /start and enter the password first.")
            return
        await func(event)
    return wrapper


def group_selected(func):
    """
    Decorator to check if a user has selected a group to manage.
    """
    async def wrapper(event):
        user_id = event.sender_id
        if not get_managing_group(user_id):
            await event.reply("⚠️ **No Group Selected!**\nPlease select a group to manage first.")
            await show_group_selection(event)
            return
        await func(event)
    return wrapper

# =================== BOT COMMANDS (Protected) ===================

# /manage command


@bot.on(events.NewMessage(pattern='/manage'))
@auth_required
async def help_command(event):
    user_id = event.sender_id
    managing_group_key = get_managing_group(user_id)

    if managing_group_key:
        group_name = bot_config[managing_group_key]['name']
        status = f"**Managing: {group_name}** (`{managing_group_key}`)"
    else:
        status = "**Not managing any group.**"

    await event.reply(
        f"📌 {status}\n\n"
        "**🧭 Group Selection:**\n"
        "/groups - Show group selection menu\n\n"
        "**🔩 Management Commands (for selected group):**\n"
        "/addsource <chat_id>\n"
        "/removesource <chat_id>\n"
        "/adddestination <chat_id>\n"
        "/removedestination <chat_id>\n"
        "/listsources - Show sources & destinations\n\n"
        "**✂️ Cleaning Settings (for selected group):**\n"
        "/togglefirstline - Enable/Disable removing the first line\n"
        "/setfirstline <text> - Replace the first line\n"
        "/setheaderremove <text> - (For Group 4) Set header text to remove\n"
        "/showsettings - Show cleaning settings\n\n"
        "**📝 Footer (for selected group):**\n"
        "/setfooter <text>\n"
        "/togglefooter\n\n"
        "**⚙️ Other:**\n"
        "/about - Bot info\n"
        "/start - Re-login (resets session)"
    )

# /about command


@bot.on(events.NewMessage(pattern='/about'))
@auth_required
async def about_command(event):
    await event.reply("🤖 **LiqHunter v2.0 (Multi-Group)**\nDeveloped by Lahiru Mahakumburage")

# ========== GROUP SELECTION ==========


async def show_group_selection(event):
    """Helper function to show the group list."""
    lines = []
    for i in range(1, 9):
        group_key = f"group{i}"
        group_name = bot_config[group_key]["name"]
        lines.append(f"• {group_name} ➡️ /group{i}")
    await event.reply("🗂️ **Choose a group to manage:**\n\n" + "\n".join(lines))


@bot.on(events.NewMessage(pattern='/groups'))
@auth_required
async def select_groups_command(event):
    await show_group_selection(event)

# Dynamically create handlers for /group1 to /group8


def create_group_selector(group_key):
    @bot.on(events.NewMessage(pattern=f'/{group_key}'))
    @auth_required
    async def select_group(event):
        user_id = event.sender_id
        auth_data[user_id]["managing"] = group_key
        group_name = bot_config[group_key]["name"]
        await event.reply(f"✅ **Now Managing: {group_name}**\n\n"
                          f"Use /manage to see commands, or /groups to switch.")
    return select_group


group1_selector = create_group_selector("group1")
group2_selector = create_group_selector("group2")
group3_selector = create_group_selector("group3")
group4_selector = create_group_selector("group4")
group5_selector = create_group_selector("group5")
group6_selector = create_group_selector("group6")
group7_selector = create_group_selector("group7")
group8_selector = create_group_selector("group8")


# ========== CLEANING SETTINGS (Now context-aware) ==========
@bot.on(events.NewMessage(pattern='/togglefirstline'))
@auth_required
@group_selected
async def toggle_firstline(event):
    group_key = get_managing_group(event.sender_id)
    config = bot_config[group_key]

    config["remove_first_line"] = not config["remove_first_line"]
    save_data()
    status = "enabled ✅" if config["remove_first_line"] else "disabled ❌"
    await event.reply(f"**{config['name']}**\n✂️ First line removal is now **{status}**")


@bot.on(events.NewMessage(pattern='/setfirstline'))
@auth_required
@group_selected
async def set_firstline(event):
    group_key = get_managing_group(event.sender_id)
    config = bot_config[group_key]

    parts = event.message.message.split(maxsplit=1)
    if len(parts) > 1:
        new_text = parts[1].strip()
        config["first_line_replacement"] = new_text
        save_data()
        await event.reply(f"**{config['name']}**\n✅ First line will now be replaced with:\n{new_text}")
    else:
        config["first_line_replacement"] = ""
        save_data()
        await event.reply(f"**{config['name']}**\n✅ First line replacement cleared.")


@bot.on(events.NewMessage(pattern='/setheaderremove'))
@auth_required
@group_selected
async def set_header_remove(event):
    group_key = get_managing_group(event.sender_id)
    config = bot_config[group_key]

    parts = event.message.message.split(maxsplit=1)
    if len(parts) > 1:
        new_text = parts[1].strip()
        config["header_to_remove"] = new_text
        save_data()
        await event.reply(f"**{config['name']}**\n✅ Will remove header line if it contains:\n{new_text}")
    else:
        config["header_to_remove"] = ""
        save_data()
        await event.reply(f"**{config['name']}**\n✅ Header removal text cleared.")


@bot.on(events.NewMessage(pattern='/showsettings'))
@auth_required
@group_selected
async def show_settings(event):
    group_key = get_managing_group(event.sender_id)
    config = bot_config[group_key]

    status_firstline = "enabled ✅" if config["remove_first_line"] else "disabled ❌"
    replacement_text = config[
        "first_line_replacement"] if config["first_line_replacement"] else "(none)"
    header_text = config["header_to_remove"] if config[
        "header_to_remove"] else "(none)"

    await event.reply(
        f"⚙️ **Settings for {config['name']}:**\n\n"
        f"• First line removal: {status_firstline}\n"
        f"• Replacement text: {replacement_text}\n"
        f"• Header to remove: {header_text}"
    )

# ========== FOOTER SETTINGS (Now context-aware) ==========


@bot.on(events.NewMessage(pattern='/setfooter'))
@auth_required
@group_selected
async def set_footer(event):
    group_key = get_managing_group(event.sender_id)
    config = bot_config[group_key]

    parts = event.message.message.split(maxsplit=1)
    if len(parts) > 1:
        new_footer = parts[1].strip()
        config["footer_text"] = f"\n\n{new_footer}"  # Add newlines
        save_data()
        await event.reply(f"**{config['name']}**\n📝 Footer updated:\n{new_footer}")
    else:
        config["footer_text"] = ""  # Clear footer
        save_data()
        await event.reply(f"**{config['name']}**\n📝 Footer cleared.")


@bot.on(events.NewMessage(pattern='/togglefooter'))
@auth_required
@group_selected
async def toggle_footer(event):
    group_key = get_managing_group(event.sender_id)
    config = bot_config[group_key]

    config["footer_enabled"] = not config["footer_enabled"]
    save_data()
    status = "enabled ✅" if config["footer_enabled"] else "disabled ❌"
    await event.reply(f"**{config['name']}**\n📝 Footer is now **{status}**")

# ========== GROUP MANAGEMENT (Now context-aware) ==========


@bot.on(events.NewMessage(pattern='/adddestination'))
@auth_required
@group_selected
async def add_destination(event):
    group_key = get_managing_group(event.sender_id)
    config = bot_config[group_key]

    try:
        parts = event.message.message.split(maxsplit=1)
        if len(parts) < 2:
            raise ValueError("No argument")

        # Clean the argument (replaces wrong dashes)
        arg_str = parts[1].strip().replace("–", "-").replace("—", "-")
        new_dest = int(arg_str)

        if new_dest not in config["destinations"]:
            config["destinations"].append(new_dest)
            entity_cache.pop(new_dest, None)  # Clear cache for this ID
            save_data()
            await event.reply(f"**{config['name']}**\n📤 Destination added: **{new_dest}**")
        else:
            await event.reply("⚠️ **Already in list** for this group.")
    except ValueError:
        await event.reply("⚠️ **Invalid Usage!**\nExample: `/adddestination -100123456`")


@bot.on(events.NewMessage(pattern='/removedestination'))
@auth_required
@group_selected
async def remove_destination(event):
    group_key = get_managing_group(event.sender_id)
    config = bot_config[group_key]

    try:
        parts = event.message.message.split(maxsplit=1)
        if len(parts) < 2:
            raise ValueError("No argument")

        # Clean the argument (replaces wrong dashes)
        arg_str = parts[1].strip().replace("–", "-").replace("—", "-")
        rem_dest = int(arg_str)

        if rem_dest in config["destinations"]:
            config["destinations"].remove(rem_dest)
            entity_cache.pop(rem_dest, None)
            save_data()
            await event.reply(f"**{config['name']}**\n🗑️ Destination removed: **{rem_dest}**")
        else:
            await event.reply("⚠️ **Not in list** for this group.")
    except ValueError:
        await event.reply("⚠️ **Invalid Usage!**\nExample: `/removedestination -100123456`")


@bot.on(events.NewMessage(pattern='/addsource'))
@auth_required
@group_selected
async def add_source(event):
    group_key = get_managing_group(event.sender_id)
    config = bot_config[group_key]

    try:
        parts = event.message.message.split(maxsplit=1)
        if len(parts) < 2:
            raise ValueError("No argument")

        # Clean the argument (replaces wrong dashes)
        arg_str = parts[1].strip().replace("–", "-").replace("—", "-")
        new_source = int(arg_str)

        if new_source not in config["sources"]:
            config["sources"].append(new_source)
            save_data()
            await event.reply(f"**{config['name']}**\n📥 Source added: **{new_source}**")
        else:
            await event.reply("⚠️ **Already in list** for this group.")
    except ValueError:
        await event.reply("⚠️ **Invalid Usage!**\nExample: `/addsource -100123456`")


@bot.on(events.NewMessage(pattern='/removesource'))
@auth_required
@group_selected
async def remove_source(event):
    group_key = get_managing_group(event.sender_id)
    config = bot_config[group_key]

    try:
        parts = event.message.message.split(maxsplit=1)
        if len(parts) < 2:
            raise ValueError("No argument")

        # Clean the argument (replaces wrong dashes)
        arg_str = parts[1].strip().replace("–", "-").replace("—", "-")
        rem_source = int(arg_str)

        if rem_source in config["sources"]:
            config["sources"].remove(rem_source)
            save_data()
            await event.reply(f"**{config['name']}**\n🗑️ Source removed: **{rem_source}**")
        else:
            await event.reply("⚠️ **Not in list** for this group.")
    except ValueError:
        await event.reply("⚠️ **Invalid Usage!**\nExample: `/removesource -100123456`")


@bot.on(events.NewMessage(pattern='/listsources'))
@auth_required
@group_selected
async def list_sources(event):
    group_key = get_managing_group(event.sender_id)
    config = bot_config[group_key]

    await event.reply(
        f"📂 **Lists for {config['name']}:**\n\n"
        f"📥 **Sources (Listening From):**\n`{config['sources']}`\n\n"
        f"📤 **Destinations (Sending To):**\n`{config['destinations']}`\n"
    )

# =================== RUN BOT ===================
print("LiqHunter v2.0 (Multi-Group) running... Debug mode enabled.")
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
