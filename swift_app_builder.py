import asyncio
import subprocess
from pathlib import Path

async def run_command(cmd):
    proc = await asyncio.create_subprocess_shell(
        cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE
    )
    stdout, stderr = await proc.communicate()
    return stdout, stderr

async def build_swiftui_app(app_name: str, app_config: dict):
    """Build and package a SwiftUI application"""
    
    # Step 1: Build the Swift package
    print(f"Building {app_name}...")
    await run_command(f"cd macos/cr4sh0ut && swift build")
    
    # Step 2: Run the app
    print(f"Running {app_name}...")
    await run_command(f"cd macos/cr4sh0ut && swift run")

async def main():
    app_config = {
        "name": "Cr4sh0ut",
        "version": "1.0.0",
        "deployment_target": "12.0",
        "packages": [
            "SwiftUI",
            "Foundation"
        ],
        "capabilities": [
            "network.client",
            "files.user-selected"
        ]
    }
    
    await build_swiftui_app(app_config["name"], app_config)

if __name__ == "__main__":
    asyncio.run(main()) 