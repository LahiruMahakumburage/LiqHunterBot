import asyncio
from telethon import TelegramClient, events

# ===== CONFIG =====
api_id = 22044713
api_hash = 'f4de9c1a1f8201e83b9222a235453fc0'
bot_token = '8593908913:AAEqfyvLmRVzSMO4__QiSaByrQw0ogqOqkc'

# ===== MAIN FUNCTION =====


async def main():
    bot = TelegramClient('gm_bot_session', api_id, api_hash)
    await bot.start(bot_token=bot_token)

    print("✅ GM/WINNER Message Bot is running...")

    # --- Respond to 'gm' ---
    @bot.on(events.NewMessage(pattern='(?i)^gm$'))
    async def gm_message(event):
        await event.reply("🌞 Good Morning Premium Traders 😍 Happy Sunday ♥️")

    # --- Respond to 'winner' ---
    @bot.on(events.NewMessage(pattern='(?i)^winner$'))
    async def winner_message(event):
        message = (
            "💥 Holders are Winners කියන්නෙ නිකන් නෙමෙ පුතේ 😎\n"
            "Premium සිග්නල් සැප 😍 XAN 🟢 300%++ Gain 😍\n\n"
            "━━━━━━━━━━━━━━━━━━━━━━\n"
            "💎 VIP Contact - @Emaster_Admin"
        )
        await event.reply(message)

    # Keep running
    await bot.run_until_disconnected()

# ===== START =====
asyncio.run(main())
