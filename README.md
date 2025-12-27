# VHSClient

VHSClient is a Roblox module that provides an easy-to-use interface for creating VHS effects in your game. It includes features such as blur effects, color correction, noise, pink outlines, lines, and preset lines.

## Features

- **Blur Effect**: Adds a blur effect to the screen.
- **Color Correction Effect**: Adjusts the color contrast and saturation.
- **Noise**: Adds noise to the screen.
- **Pink Outline**: Adds a pink outline to the screen.
- **Lines**: Adds lines to the screen.
- **Preset Lines**: Adds preset lines to the screen.

## Installation

**VHSClient can only be used on the client**

### Manual Installation
Download the latest release from the releases page.
Place the VHSClient.rbxm file in your Roblox project.

## Usage

### Initialization
To initialize the VHSClient, require the module and call its functions:

```lua
local VHSClient = require(game.ReplicatedStorage.VHSClient)

-- Show the blur effect
VHSClient:Show("Blur")

-- Hide the noise effect
VHSClient:Hide("Noise")

-- Toggle the pink outline
VHSClient:Toggle("Pink")
```

## Contributing
Contributions are welcome! Please open an issue or submit a pull request on this repository.

## **VHSClient is licensed under the MIT license**
