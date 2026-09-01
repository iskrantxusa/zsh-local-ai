# shellcheck shell=zsh

# Resolve everything relative to this file so the package can live anywhere.
typeset _zsh_local_ai_config_file="${${(%):-%N}:A}"
typeset _zsh_local_ai_root="${_zsh_local_ai_config_file:h:h}"

if [[ -r "$_zsh_local_ai_root/settings.env" ]]; then
  source "$_zsh_local_ai_root/settings.env"
else
  print -u2 -- "zsh-local-ai: missing $_zsh_local_ai_root/settings.env"
  unset _zsh_local_ai_config_file _zsh_local_ai_root
  return 1
fi

export ZSH_AI_PROVIDER="ollama"
export ZSH_AI_OLLAMA_MODEL="${ZSH_LOCAL_AI_MODEL:-qwen2.5-coder:3b}"
export ZSH_AI_OLLAMA_URL="${ZSH_LOCAL_AI_URL:-http://127.0.0.1:11434}"

# Local Ollama must bypass any proxy inherited by the interactive shell.
_zsh_local_ai_add_no_proxy() {
  local variable current address
  for variable in no_proxy NO_PROXY; do
    current="${(P)variable}"
    for address in localhost 127.0.0.1 ::1; do
      [[ ",$current," == *",$address,"* ]] || current="${current:+$current,}$address"
    done
    export "${variable}=${current}"
  done
}
_zsh_local_ai_add_no_proxy
unfunction _zsh_local_ai_add_no_proxy

if [[ -r "$_zsh_local_ai_root/vendor/zsh-ai/zsh-ai.plugin.zsh" ]]; then
  source "$_zsh_local_ai_root/vendor/zsh-ai/zsh-ai.plugin.zsh"
else
  print -u2 -- "zsh-local-ai: vendored zsh-ai plugin is missing"
fi

unset _zsh_local_ai_config_file _zsh_local_ai_root
