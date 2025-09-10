# ZLeader SourceMod Plugin - Copilot Instructions

## Repository Overview

This repository contains the **ZLeader** SourceMod plugin - a comprehensive leader management system for Counter-Strike: Source/Global Offensive zombie escape servers. The plugin provides multi-leader functionality with visual markers, trails, beacons, and communication tools to help coordinate team movement and strategy.

### Plugin Information
- **Name**: ZLeader Remake
- **Authors**: Original by AntiTeal, nuclear silo, CNTT, colia || Remake by Oylsister, .Rushaway
- **Version**: 3.7.0 (defined in zleader.inc)
- **Description**: Comprehensive leader management system for zombie escape servers
- **URL**: https://github.com/oylsister/ZLeader-Remake

### Key Features
- **Multi-Leader System**: Supports up to 5 simultaneous leaders (Alpha, Bravo, Charlie, Delta, Echo)
- **Visual Marker System**: Multiple marker types (Arrow, Defend, ZM Teleport, No Doorhug, Ping)
- **Visual Effects**: Leader trails, sprites, beacons, and neon effects
- **Client Preferences**: Customizable shortcuts and marker positioning
- **Voting System**: Democratic leader selection through player voting
- **Multi-Language Support**: Comprehensive translation system
- **VIP Integration**: Optional VIP Core plugin support
- **Administration Tools**: Admin commands for leader management

## Technical Environment

### Core Technologies
- **Language**: SourcePawn
- **Platform**: SourceMod 1.12+ (minimum supported version)
- **Compiler**: Latest SourcePawn compiler (spcomp)
- **Build System**: SourceKnight (sourceknight.yaml)
- **Target Games**: Counter-Strike: Source, Counter-Strike: Global Offensive

### Dependencies
The plugin has several dependencies managed through SourceKnight:
- **SourceMod**: Core framework (1.11.0+ from config, 1.12+ recommended)
- **MultiColors**: Enhanced chat color support
- **ZombieReloaded**: Integration for zombie-related functionality
- **VIP-Core**: Optional VIP system integration
- **CustomChatColors**: Chat customization support
- **utilshelper**: Utility functions
- **SourceBans++**: Optional ban system integration

## Project Structure

```
addons/sourcemod/
├── scripting/
│   ├── ZLeader.sp              # Main plugin source code
│   └── include/
│       └── zleader.inc         # Native functions and API definitions
├── configs/
│   └── zleader/
│       ├── configs.txt         # Leader configuration (Alpha-Echo leaders)
│       ├── downloads.txt       # Required downloads for clients
│       └── leaders.ini         # Leader permissions/access list
├── translations/
│   └── zleader.phrases.txt     # Multi-language translations (EN/RU)
└── plugins/                    # Compiled plugin output (generated)

materials/                      # Visual assets (textures, sprites)
models/                        # 3D models for markers
sound/                         # Audio files (ping sounds)
sourceknight.yaml              # Build configuration and dependencies
.github/workflows/ci.yml       # CI/CD pipeline
```

## Code Style & Standards

### SourcePawn Conventions
- **Indentation**: Use tabs equivalent to 4 spaces
- **Pragmas**: Always include `#pragma semicolon 1` and `#pragma newdecls required`
- **Variables**: 
  - camelCase for local variables and function parameters
  - PascalCase for function names and global variables
  - Prefix global variables with "g_"
- **Naming**: Use descriptive variable and function names
- **Formatting**: Delete trailing spaces, consistent spacing

### Memory Management
- Use `delete` directly without null checks (SourceMod handles null deletion safely)
- **Never use `.Clear()`** on StringMap/ArrayList - causes memory leaks
- Use `delete` and create new instances instead of clearing
- Implement proper cleanup in `OnPluginEnd()` when necessary
- Use transactions in SQL operations when needed

### Best Practices
- **StringMap/ArrayList**: Prefer over traditional arrays for dynamic data
- **Error Handling**: Implement for all API calls and external operations
- **Translations**: Use translation files for all user-facing messages
- **Event-Driven**: Follow SourceMod's event-based programming model
- **Configuration**: Avoid hardcoded values; use config files
- **SQL Operations**: All queries must be asynchronous using methodmaps
- **Performance**: Minimize operations in frequently called functions (aim for O(1) complexity)

## Plugin-Specific Implementation Details

### Core Systems

#### Leader Management
```sourcepawn
// Native functions available in zleader.inc
native void ZL_SetLeader(int client, int slot);
native bool ZL_IsClientLeader(int client);
native void ZL_RemoveLeader(int client, ResignReason reason, bool announce);
native int ZL_GetClientLeaderSlot(int client);
native bool ZL_IsLeaderSlotFree(int slot);
native bool ZL_IsPossibleLeader(int client);
```

#### Marker System
- **Types**: Arrow (0), Defend (1), ZM Teleport (2), No Doorhug (3), Ping (4)
- **Positioning**: Client position or crosshair position (user preference)
- **Limits**: Configurable maximum markers per leader
- **Entity Management**: Proper cleanup to avoid edict limits

#### Visual Effects
- **Trails**: Configurable trail effects for leaders
- **Beacons**: Toggle-able beacon system
- **Sprites**: Leader identification sprites
- **Neon**: Glow effects around leaders

### Configuration System

#### Leader Configuration (`configs.txt`)
Each leader slot (Alpha-Echo) has comprehensive configuration:
- Codename and slot assignment
- Material files (VMT/VTF) for various visual elements
- Color specifications for different marker types
- Audio files for ping sounds

#### Translation System
- Primary support: English and Russian
- Extensible for additional languages
- Contextual formatting with parameter support
- Menu and chat message translations

### Build & Development Process

#### Using SourceKnight
SourceKnight is used through GitHub Actions for automated building. For local development:
```bash
# The build process is automated via GitHub Actions using:
# uses: maxime1907/action-sourceknight@v1

# Local development requires manual SourceMod compiler (spcomp)
# Dependencies are managed through sourceknight.yaml configuration
```

#### Manual Compilation
For local development without SourceKnight:
```bash
# Ensure SourceMod compiler is in PATH
spcomp -i"addons/sourcemod/scripting/include" addons/sourcemod/scripting/ZLeader.sp
```

#### CI/CD Pipeline
- **Automated Building**: GitHub Actions on push/PR
- **Artifact Generation**: Creates release packages
- **Automatic Releases**: Tags and releases on main branch
- **Package Structure**: Includes plugin, materials, models, sounds

### Testing & Validation

#### Development Testing
- Test on a development server before deployment
- Verify all marker types function correctly
- Test multi-leader scenarios (up to 5 concurrent leaders)
- Validate translation system with different languages
- Check memory usage and entity limits

#### Performance Considerations
- Monitor server tick rate impact
- Profile marker creation/destruction
- Validate SQL query performance (all async)
- Test with maximum concurrent leaders and markers

### Common Development Tasks

#### Adding New Marker Types
1. Define new constants in `zleader.inc`
2. Update `MAX_INDEX` calculations
3. Add configuration entries in `configs.txt`
4. Implement marker logic in main plugin
5. Add translations for new marker type

#### Extending Leader Functionality
1. Check current leader slot availability
2. Implement new native functions in `zleader.inc`
3. Update shared plugin definitions
4. Add appropriate error handling
5. Update documentation and translations

#### Modifying Visual Effects
1. Update material/model files
2. Modify configuration entries
3. Ensure proper precaching in `OnMapStart()`
4. Test rendering performance
5. Validate client download requirements

### Integration Points

#### VIP System Integration
- Optional VIP Core plugin support
- Leader eligibility based on VIP status
- Configurable VIP-only features

#### Chat System Integration
- CustomChatColors support for leader identification
- MultiColors for enhanced message formatting
- Communication punishment integration (mute detection)

#### ZombieReloaded Integration
- Human/zombie state validation
- Infection event handling
- Team-specific leader restrictions

### Error Handling & Debugging

#### Common Issues
- **Edict Limit**: Monitor entity creation, implement cleanup
- **Memory Leaks**: Avoid `.Clear()`, use proper deletion
- **SQL Injection**: Always escape strings, use parameterized queries
- **Client Validation**: Check client validity before operations
- **Permission Checks**: Validate leader eligibility consistently

#### Debugging Tools
- Use SourceMod's built-in profiler for memory leak detection
- Monitor console for plugin errors and warnings
- Implement comprehensive logging for development builds
- Use debug convars for detailed output

### Version Control & Releases

#### Versioning
- Follow semantic versioning (MAJOR.MINOR.PATCH)
- Update version constants in `zleader.inc`
- Synchronize plugin versions with repository tags

#### Commit Guidelines
- Clear, descriptive commit messages
- Separate commits for different functional changes
- Include relevant issue/PR references
- Test changes before committing

### Performance Optimization

#### Entity Management
- Implement entity cleanup timers
- Monitor server edict usage
- Use efficient entity creation/destruction patterns
- Avoid unnecessary entity operations in loops

#### Database Operations
- All SQL operations must be asynchronous
- Use prepared statements for security
- Implement connection pooling where appropriate
- Cache frequently accessed data

#### Event Handling
- Minimize processing in frequently called events
- Use efficient data structures for lookups
- Implement proper event unhooking in cleanup
- Cache expensive calculations

This comprehensive guide should help any coding agent understand the ZLeader plugin architecture, development practices, and codebase conventions for efficient contribution to the project.