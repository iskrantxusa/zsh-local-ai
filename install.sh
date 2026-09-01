#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
settings_file="$project_dir/settings.env"
plugin_file="$project_dir/vendor/zsh-ai/zsh-ai.plugin.zsh"
config_link="$HOME/.config/zsh-local-ai"
unit_dir="$HOME/.config/systemd/user"
unit_link="$unit_dir/ollama.service"
zshrc_local="${ZSH_LOCAL_AI_ZSHRC:-$HOME/.zshrc.local}"

die() {
  printf 'zsh-local-ai: %s\n' "$*" >&2
  exit 1
}

[ -r "$settings_file" ] || die "missing $settings_file"
[ -r "$plugin_file" ] || die "missing vendored zsh-ai plugin"

# settings.env intentionally uses POSIX-compatible assignments.
# shellcheck disable=SC1090
. "$settings_file"
model=${ZSH_LOCAL_AI_MODEL:-qwen2.5-coder:3b}
ollama_url=${ZSH_LOCAL_AI_URL:-http://127.0.0.1:11434}

for command_name in zsh curl perl jq ollama systemctl; do
  command -v "$command_name" >/dev/null 2>&1 || die "required command not found: $command_name"
done

mkdir -p "$HOME/.config" "$unit_dir"

if [ -e "$config_link" ] && [ ! -L "$config_link" ]; then
  die "$config_link already exists and is not a symbolic link"
fi
ln -sfn "$project_dir" "$config_link"

# Preserve an unrelated pre-existing service. Replace the legacy service made
# by the original one-off setup without leaving duplicate units behind.
if [ -e "$unit_link" ] && [ ! -L "$unit_link" ]; then
  if grep -q '^Description=Ollama local model server$' "$unit_link" && \
     grep -q '^ExecStart=/usr/local/bin/ollama serve$' "$unit_link"; then
    rm -f "$unit_link"
  else
    backup="$unit_link.backup-$(date +%Y%m%d-%H%M%S)"
    mv "$unit_link" "$backup"
    printf 'Preserved existing unit as %s\n' "$backup"
  fi
fi
ln -sfn "$config_link/config/ollama.service" "$unit_link"

mkdir -p "$(dirname -- "$zshrc_local")"
touch "$zshrc_local"
source_line='[[ -r "$HOME/.config/zsh-local-ai/config/zsh-ai.zsh" ]] && source "$HOME/.config/zsh-local-ai/config/zsh-ai.zsh"'
if ! grep -Fq 'zsh-local-ai/config/zsh-ai.zsh' "$zshrc_local"; then
  {
    printf '\n# >>> zsh-local-ai >>>\n'
    printf '%s\n' "$source_line"
    printf '# <<< zsh-local-ai <<<\n'
  } >>"$zshrc_local"
fi

systemctl --user daemon-reload
systemctl --user enable ollama.service
systemctl --user restart ollama.service

attempt=0
until curl --noproxy '*' -sf "$ollama_url/api/tags" >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  [ "$attempt" -lt 30 ] || die "Ollama did not become ready at $ollama_url"
  sleep 1
done

ollama pull "$model"

printf '\nInstalled zsh-local-ai from %s\n' "$project_dir"
printf 'Model: %s\n' "$model"
printf 'Reload the current shell with: exec zsh\n'
