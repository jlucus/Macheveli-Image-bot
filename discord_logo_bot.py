import discord
from discord import app_commands
import io
import os
from datetime import datetime
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Import Modal function directly from the deployed app
MODAL_SERVER = os.getenv("MODAL_SERVER")
APP_NAME = "logo-generator"

# Try to import the function from the Modal app
try:
    import sys
    import os as os_module

    # Handle both script and Jupyter environments
    try:
        script_dir = os_module.path.dirname(os_module.path.abspath(__file__))
    except NameError:
        # __file__ not defined (Jupyter/IPython)
        script_dir = os_module.getcwd()

    modal_project_path = os_module.path.join(script_dir, "modal_project", "src")

    if modal_project_path not in sys.path:
        sys.path.insert(0, modal_project_path)

    from logo_generator import generate_logo_svg
    print(f"✅ Imported Modal function from: {modal_project_path}")
except ImportError as e:
    print(f"⚠️  Warning: Could not import Modal function: {e}")
    print(f"⚠️  Make sure modal_project/src/logo_generator.py exists")
    print(f"⚠️  Current working directory: {os.getcwd()}")
    generate_logo_svg = None

# Bot setup
intents = discord.Intents.default()
client = discord.Client(intents=intents)
tree = app_commands.CommandTree(client)

@tree.command(name="logo", description="Generate an AI logo from your prompt")
@app_commands.describe(
    prompt="Describe the logo you want (e.g., 'cyberpunk neon logo with circuits')",
    style="Optional style preset"
)
@app_commands.choices(style=[
    app_commands.Choice(name="Cyberpunk", value="cyberpunk neon with circuit patterns"),
    app_commands.Choice(name="Minimalist", value="minimalist geometric clean"),
    app_commands.Choice(name="Retro", value="retro 80s synthwave"),
    app_commands.Choice(name="Gaming", value="gaming esports bold"),
    app_commands.Choice(name="Tech Startup", value="modern tech startup professional")
])
async def generate_logo(
    interaction: discord.Interaction,
    prompt: str,
    style: app_commands.Choice[str] = None
):
    """Generate a logo using AI"""

    # Check if Modal function is available
    if generate_logo_svg is None:
        await interaction.response.send_message(
            "❌ Modal app not connected. Please check the bot logs.",
            ephemeral=True
        )
        return

    # Build full prompt
    full_prompt = prompt
    if style:
        full_prompt = f"{prompt} in {style.value} style"

    # Defer (this takes time with GPU)
    await interaction.response.defer()

    try:
        # Generate via Modal
        svg_code = generate_logo_svg.remote(prompt=full_prompt)
        
        # Option 1: Send as SVG file (smaller, scalable)
        svg_file = discord.File(
            fp=io.BytesIO(svg_code.encode('utf-8')),
            filename=f"logo_{datetime.now().strftime('%Y%m%d_%H%M%S')}.svg"
        )
        
        embed = discord.Embed(
            title="🎨 Logo Generated!",
            description=f"**Prompt:** {full_prompt}",
            color=discord.Color.blue()
        )
        embed.set_footer(text="Powered by Modal + Qwen3-8B")
        
        await interaction.followup.send(embed=embed, file=svg_file)
        
    except Exception as e:
        error_embed = discord.Embed(
            title="❌ Generation Failed",
            description=f"```{str(e)}```",
            color=discord.Color.red()
        )
        await interaction.followup.send(embed=error_embed, ephemeral=True)

@client.event
async def on_ready():
    print(f"✅ Logged in as {client.user.name}")
    print(f"✅ Bot ID: {client.user.id}")

    # Show configuration
    app_id = os.getenv("DISCORD_APP_ID")
    install_link = os.getenv("DISCORD_INSTALL_LINK")

    if app_id:
        print(f"✅ Application ID: {app_id}")
    if install_link:
        print(f"🔗 Install Link: {install_link}")
    if MODAL_SERVER:
        print(f"🌐 Modal Server: {MODAL_SERVER}")

    # Sync commands
    try:
        synced = await tree.sync()
        print(f"✅ Synced {len(synced)} command(s)")
    except Exception as e:
        print(f"❌ Failed to sync commands: {e}")

async def start_bot():
    """Start the Discord bot (for Jupyter/IPython environments)"""
    # Load Discord token (check both DISCORD_BOT_TOKE and DISCORD_BOT_TOKEN)
    TOKEN = os.getenv("DISCORD_BOT_TOKE") or os.getenv("DISCORD_BOT_TOKEN")

    if not TOKEN:
        print("❌ Error: DISCORD_BOT_TOKEN not set in .env file")
        print("Add to .env file: DISCORD_BOT_TOKE=your-token-here")
        return

    # Validate other optional variables
    PUBLIC_KEY = os.getenv("DISCORD_PUBLIC_KEY")
    APP_ID = os.getenv("DISCORD_APP_ID")

    if PUBLIC_KEY:
        print(f"✅ Using Discord Public Key: {PUBLIC_KEY[:8]}...")
    if APP_ID:
        print(f"✅ Using Discord App ID: {APP_ID}")

    print("🤖 Starting Discord bot...")

    try:
        await client.start(TOKEN)
    except KeyboardInterrupt:
        await client.close()

if __name__ == "__main__":
    # Check if running in Jupyter/IPython
    try:
        import asyncio
        # Try to get running loop
        loop = asyncio.get_running_loop()
        print("📓 Jupyter/IPython detected")
        print("⚠️  Run this instead: await start_bot()")
        print("⚠️  Or better: run from command line with 'python discord_logo_bot.py'")
    except RuntimeError:
        # No running loop, safe to use client.run()
        TOKEN = os.getenv("DISCORD_BOT_TOKE") or os.getenv("DISCORD_BOT_TOKEN")

        if not TOKEN:
            print("❌ Error: DISCORD_BOT_TOKEN not set in .env file")
            print("Add to .env file: DISCORD_BOT_TOKE=your-token-here")
            exit(1)

        print("🤖 Starting Discord bot...")
        client.run(TOKEN)