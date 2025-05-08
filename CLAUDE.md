# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository contains an AwesomeWM configuration with custom visual effects called "glitch effects". The codebase is structured around Lua modules that extend AwesomeWM functionality with various visual effects that can be applied to windows.

## Key Components

### Core Configuration Files

- `rc.lua`: Main entry point that loads all other modules
- `config.lua`: General configuration (terminal, editor, modkey, layouts)
- `beauty.lua`: Theme settings for AwesomeWM
- `ui.lua`: UI elements (wibar, widgets, tags)
- `rules.lua`: Window rules for specific applications
- `binds.lua`: Keyboard/mouse bindings
- `autostart.lua`: Applications to launch at startup
- `glitch.lua`: Entry point for the glitch effect system

### Glitch Effect System

The glitch effect system is a custom module that adds visual effects to windows. It consists of:

1. **Core Engine (`glitch_effect/core.lua`)**: 
   - Manages effect registration, enabling/disabling, and state tracking
   - Provides the main timer-based tick function that runs effects on windows

2. **Effect Implementations**:
   - `wave.lua`: Makes windows move in a wave pattern
   - `hack.lua`: Randomly teleports windows to previous positions
   - `glide.lua`: Makes windows glide in circular patterns
   - `corner_resize.lua`: Dynamically resizes windows from a corner

3. **Signal Sources**:
   - `audio_listener.lua`: Captures audio from JACK and emits signals
   - `pipewire_native.lua`: Alternative audio capture using PipeWire via LuaJIT FFI
   - `random_pulse.lua`: Generates random signal pulses

## Architecture

The system follows these architectural principles:

1. **Effect Registration**: Effects are registered with the core engine and can be individually enabled/disabled.

2. **Signal-Based Reactivity**: Visual effects can react to audio signals from either JACK or PipeWire.

3. **Per-Client State**: Each window maintains its own state for each effect.

4. **Timer-Based Animation**: A timer calls effect functions periodically to update window properties.

## Working with the Codebase

### Adding New Effects

To add a new effect:

1. Create a new Lua file in `glitch_effect/effects/`
2. Export a function that takes parameters: `client, context, state`
3. Register the effect in `glitch.lua` using `effect_core.register_effect('name', effect_function)`
4. Add keybindings for toggling the effect

### Modifying Audio Signal Processing

Audio processing happens in either:
- `glitch_effect/signal/audio_analyzer.py` (Python-based)

The key parts are:
- Audio capture setup
- RMS level calculation
- Simple FFT implementation for frequency bands
- Emission of `glitch::audio` and `glitch::fft` signals

## Testing

The codebase doesn't have a formal testing framework. Changes should be tested by:

1. Editing files in place in `~/.config/awesome/`
2. Restarting AwesomeWM with `Super+Alt+r` or through the Awesome menu
3. Observing the effects of changes

## Common Issues

- **FFT Performance**: The simple FFT implementation is not optimized and can impact performance for large buffer sizes.
- **Window Positioning**: Effects that change window geometry may cause windows to go off-screen.