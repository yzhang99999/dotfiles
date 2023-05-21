#!/usr/bin/env bash

################################################################################
# setup.sh
#
# This script uses GNU Stow to symlink files and directories into place.
# It can be run safely multiple times on the same machine. (idempotency)
################################################################################

dotfiles_echo() {
  local fmt="$1"; shift

  # shellcheck disable=SC2059
  printf "\\n[DOTFILES] ${fmt}\\n" "$@"
}

backup_stow_conflict() {
  dotfiles_echo "Conflict detected: ${1} Backing up.."
  local BACKUP_SUFFIX
  BACKUP_SUFFIX="$(date +%Y-%m-%d)_$(date +%s)"
  mv -v "$1" "${1}_${BACKUP_SUFFIX}"
  dotfiles_echo "Moved $1 to ${1}_${BACKUP_SUFFIX}."
}

osname=$(uname)

if [ "$osname" != "Darwin" ]; then
  dotfiles_echo "Oops, it looks like you're using a non-Apple system. Sorry, this script only supports macOS. Exiting..."
  exit 1
fi

if ! command -v stow >/dev/null; then
  dotfiles_echo "GNU Stow is required but was not found. Try:"
  dotfiles_echo "brew install stow"
  dotfiles_echo "Exiting..."
  exit 1
fi

dotfiles_echo "Initializing dotfiles setup..."

sudo -v

set -e # Terminate script if anything exits with a non-zero value

if [ -z "$DOTFILES" ]; then
  export DOTFILES="${HOME}/dotfiles"
fi

dotfiles_echo "Setting HostName..."

COMPUTER_NAME=$(scutil --get ComputerName)
LOCAL_HOST_NAME=$(scutil --get LocalHostName)

sudo scutil --set HostName "$LOCAL_HOST_NAME"
HOST_NAME=$(scutil --get HostName)

sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server.plist NetBIOSName -string "$HOST_NAME"

printf "ComputerName:  ==> [%s]\\n" "$COMPUTER_NAME"
printf "LocalHostName: ==> [%s]\\n" "$LOCAL_HOST_NAME"
printf "HostName:      ==> [%s]\\n" "$HOST_NAME"

if [ -z "$XDG_CONFIG_HOME" ]; then
  dotfiles_echo "Setting up ~/.config directory..."
  if [ ! -d "${HOME}/.config" ]; then
    mkdir "${HOME}/.config"
  fi
  export XDG_CONFIG_HOME="${HOME}/.config"
fi

if [ ! -d "${HOME}/.local/bin" ]; then
  dotfiles_echo "Setting up ~/.local/bin directory..."
  mkdir -pv "${HOME}/.local/bin"
fi

dotfiles_echo "Checking your system architecture..."

arch="$(uname -m)"

if [ "$arch" == "arm64" ]; then
  dotfiles_echo "You're on Apple Silicon! Setting HOMEBREW_PREFIX to /opt/homebrew..."
  HOMEBREW_PREFIX="/opt/homebrew"
else
  dotfiles_echo "You're on an Intel Mac! Setting HOMEBREW_PREFIX to /usr/local..."
  HOMEBREW_PREFIX="/usr/local"
fi

dotfiles_echo "Checking for potential stow conflicts..."

cd "${DOTFILES}/" # stow needs to run from inside dotfiles dir

stow_conflicts=(
  ".asdfrc"
  ".bashrc"
  ".config/alacritty.yml"
  ".config/fish"
  ".config/lazygit"
  ".config/lvim"
  ".config/nvim"
  ".config/ranger"
  ".config/starship.toml"
  ".config/yamllint"
  ".config/zsh"
  ".config/zsh-abbr"
  ".default-gems"
  ".default-npm-packages"
  ".gemrc"
  ".gitconfig"
  ".gitignore_global"
  ".gitmessage"
  ".hushlogin"
  ".irbrc"
  ".local/bin/colortest"
  ".local/bin/git-brst"
  ".local/bin/git-cm"
  ".local/bin/git-publish"
  ".local/bin/git-uncommit"
  ".local/bin/tat"
  ".npmrc"
  ".pryrc"
  ".ripgreprc"
  ".rubocop.yml"
  ".tmux.conf"
  ".tool-versions"
  ".zshrc"
  "Brewfile"
)

for item in "${stow_conflicts[@]}"; do
  if [ -e "${HOME}/${item}" ]; then
    # Potential conflict detected
    if [ -L "${HOME}/${item}" ]; then
      # This is a symlink and we can ignore it.
      continue
    elif [ "$item" == ".tool-versions" ]; then
      # This was likely generated by Laptop, and we actually want to adopt it for now.
      dotfiles_echo "${HOME}/.tool-versions file found. Adopting..."
      stow --adopt asdf/
    else
      # This is a file or directory that will cause a conflict.
      backup_stow_conflict "${HOME}/${item}"
    fi
  fi
done

dotfiles_echo "Setting up symlinks with GNU Stow..."

for item in *; do
  if [ -d "$item" ]; then
    stow "$item"/
  fi
done

if command -v fish >/dev/null; then
  dotfiles_echo "Initializing fish_user_paths..."
  command fish -c "set -U fish_user_paths $HOME/.asdf/shims $HOME/.local/bin $HOME/.bin $HOME/.yarn/bin $HOMEBREW_PREFIX/bin"
fi

if [ ! -d "${HOME}/.terminfo" ]; then
  dotfiles_echo "Installing custom terminfo entries..."
  # These entries enable, among other things, italic text in the terminal.
  tic -x "${DOTFILES}/terminfo/tmux-256color.terminfo"
  tic -x "${DOTFILES}/terminfo/xterm-256color-italic.terminfo"
fi

dotfiles_echo "Dotfiles setup complete!"
echo
echo "Possible next steps:"
echo "-> Install LunarVim (https://www.lunarvim.org)"
echo "-> Install Zap (https://www.zapzsh.org)"
echo "-> Install Homebrew packages (brew bundle install)"
echo "-> Set up iTerm2 preferences (Settings > General > Preferences)"
echo