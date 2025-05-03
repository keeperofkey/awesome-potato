# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Run Commands
- Python audio VFX: `cd audio_vfx && python main.py`
- Python virtual environment: `audio_vfx/audio_env`
- Install Python requirements: `pip install -r audio_vfx/requirements.txt`
- Lint Python: `flake8 --max-line-length=100 audio_vfx/`
- Format Python: `black audio_vfx/`
- Format Lua: `stylua --indent-type Spaces --indent-width 4 *.lua glitch_effect/**/*.lua`

## Code Style Guidelines
- Lua: Follow AwesomeWM conventions (4-space indent, snake_case for variables and functions)
- Python: PEP 8 style with max 100 characters per line
- Use descriptive variable names in both Python and Lua
- Python imports: stdlib first, then third-party, then local modules
- Error handling: Use pcall in Lua, try/except in Python
- Comments: Document complex algorithms and non-obvious logic
- Python typing: Use type hints in newer Python code
- Consistency: Match existing code style in files being modified