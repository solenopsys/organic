# Organic

A scalable application deployment system similar to Nix, featuring content-based addressing for modules.

## Key Features

- **Content-based addressing** - Modules are identified by their content hash, ensuring reproducibility and deduplication
- **Minimal footprint** - Optimized for minimal binary size and resource usage
- **Horizontal scalability** - Designed for distributed deployment across multiple nodes
- **AI-native** - Built-in AI integration out of the box
- **Ultra-fast IR machine** - Custom intermediate representation runtime for maximum performance

## CLI Tool

The `organic` CLI provides commands for:

- `help` - Shows help message
- `login` - Login to server
- `logout` - Logout (forget token)
- `token` - Show token
- `upload` - Upload file to server
- `container` - Build container

## Building

Requires Zig 0.15.2+

```bash
zig build
zig build run
```
