#!/bin/bash

# --- Helper functions ---
log() {
    echo "[INFO] $1"
}

error_exit() {
    echo "[ERROR] $1"
    exit 1
}

# --- Install Blue (Homebrew für Mac) ---
log "Installing Blue (Homebrew)..."
if ! command -v blue > /dev/null 2>&1; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || error_exit "Failed to install Homebrew."
fi
log "Blue (Homebrew) installed successfully."

# --- Install essential tools ---
log "Installing essential tools..."
brew update
brew install git neovim wget zsh iterm2 || error_exit "Failed to install essential tools."

# --- Setup Oh My Zsh ---
log "Installing Oh My Zsh..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || error_exit "Failed to install Oh My Zsh."

# --- Install Powerlevel10k Theme ---
log "Installing Powerlevel10k theme for Oh My Zsh..."
git clone https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k || error_exit "Failed to clone Powerlevel10k."

# --- Install Zsh Plugins ---
log "Installing Zsh plugins..."
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions || error_exit "Failed to install Zsh-autosuggestions."
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting || error_exit "Failed to install Zsh-syntax-highlighting."

# --- Clone Dotfiles ---
log "Cloning dotfiles repository..."
DOTFILES_REPO="https://github.com/louisgundelwein/dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"

if [ -d "$DOTFILES_DIR" ]; then
    log "Dotfiles already exist. Pulling latest changes..."
    git -C "$DOTFILES_DIR" pull || error_exit "Failed to pull dotfiles."
else
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR" || error_exit "Failed to clone dotfiles."
fi

log "Setting up symlinks for dotfiles..."
ln -sf "$DOTFILES_DIR/.bashrc" "$HOME/.bashrc"
ln -sf "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
ln -sf "$DOTFILES_DIR/.vimrc" "$HOME/.vimrc"
ln -sf "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"

# --- Setup SSH ---
log "Setting up SSH..."
ssh-keygen -t ed25519 -C "louis-gundelwein@gmx.com" -f "$HOME/.ssh/id_ed25519" -q -N "" || error_exit "Failed to generate SSH key."
eval "$(ssh-agent -s)"
cat <<EOF > ~/.ssh/config
Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
EOF

log "Adding SSH key to ssh-agent..."
ssh-add --apple-use-keychain "$HOME/.ssh/id_ed25519" || error_exit "Failed to add SSH key to ssh-agent."

# --- Setup Git with Dotfiles Alias ---
log "Setting up Git for dotfiles..."
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
echo "alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'" >> "$HOME/.zshrc"

if [ ! -d "$HOME/.cfg" ]; then
    git clone --bare git@github.com:louisgundelwein/dotfiles.git $HOME/.cfg || error_exit "Failed to clone dotfiles bare repo."
    mkdir -p .config-backup
    config checkout || {
        log "Backing up existing files..."
        config checkout 2>&1 | egrep "\s+\." | awk {'print $1'} | xargs -I{} mv {} .config-backup/{}
        config checkout || error_exit "Failed to checkout dotfiles."
    }
    config config --local status.showUntrackedFiles no
fi

# --- Install NeoVim and NvChad ---
log "Installing NeoVim..."
brew install neovim || error_exit "Failed to install NeoVim."

log "Installing NvChad for NeoVim..."
git clone https://github.com/NvChad/NvChad ~/.config/nvim --depth 1 || error_exit "Failed to clone NvChad."

# --- macOS-specific settings ---
log "Applying macOS settings..."
defaults write com.apple.dock autohide -bool true
defaults write com.apple.finder AppleShowAllFiles -bool true
killall Dock Finder || log "Failed to restart Dock and Finder."

# --- Cleanup ---
log "Cleaning up..."
brew cleanup

log "Setup completed successfully!"
