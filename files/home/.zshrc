#
# ~/.zshrc - interactive zsh configuration
#
# Omarchy's shell defaults live in $OMARCHY_PATH/default/bash and are written
# for bash. The portable parts (envs, aliases, fns) are sourced live below
# under `emulate sh`, so `omarchy update` keeps them current. Everything
# bash-specific -- shopt, readline/inputrc, bash-completion, `... init bash` --
# is reimplemented natively further down.
#
# Add your own exports, aliases, and functions at the bottom.

# If not running interactively, don't do anything else
[[ -o interactive ]] || return

#: "${OMARCHY_PATH:=/usr/share/omarchy}"


#
# History  (replaces default/bash/shell)
#
HISTFILE="$HOME/.zsh_history"
HISTSIZE=32768
SAVEHIST=$HISTSIZE
setopt APPEND_HISTORY INC_APPEND_HISTORY EXTENDED_HISTORY
#setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE   # bash's HISTCONTROL=ignoreboth
#setopt HIST_REDUCE_BLANKS HIST_VERIFY

# mise shims appear and disappear, so don't cache command lookups
# (bash equivalent: `set +h`)
unsetopt HASH_CMDS HASH_DIRS

setopt INTERACTIVE_COMMENTS
setopt NO_BEEP

#
# Completion  (replaces default/bash/completions + the inputrc settings)
#
fpath=("$HOME/.config/zsh/completions" /usr/share/zsh/site-functions $fpath)

autoload -Uz compinit
_zcompdump="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-${ZSH_VERSION}"
[[ -d ${_zcompdump:h} ]] || mkdir -p "${_zcompdump:h}"
# Rebuild the dump at most once a day; use the cache otherwise
if [[ -n ${_zcompdump}(#qN.mh-24) ]]; then
  compinit -C -d "$_zcompdump"
else
  compinit -d "$_zcompdump"
fi
unset _zcompdump

zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'  # ignore case
zstyle ':completion:*' menu select                         # cycle candidates
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"    # colored stats
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/compcache"
zstyle ':completion:*:descriptions' format '%F{cyan}%d%f'
# Hide the individual omarchy-* binaries; `omarchy` is the entry point
zstyle ':completion:*:*:-command-:*:commands' ignored-patterns 'omarchy-*'

setopt ALWAYS_TO_END COMPLETE_IN_WORD   # skip-completed-text
setopt LIST_TYPES                       # visible-stats
setopt MARK_DIRS                        # mark-symlinked-directories
unsetopt LIST_BEEP
LISTMAX=200                             # ask before listing >200 matches

#
# Key bindings  (replaces default/bash/inputrc)
#
bindkey -e

# Arrow keys match what you've typed so far against your command history
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OB' down-line-or-beginning-search

bindkey '^[[Z' reverse-menu-complete     # shift-tab cycles backwards
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char

#
# Tool init  (replaces default/bash/init)
#
if command -v mise &>/dev/null; then
  eval "$(mise activate zsh)"
fi

if [[ ${TERM:-} != "dumb" ]] && command -v starship &>/dev/null; then
  eval "$(starship init zsh)"
fi

if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh)"
fi

if command -v try &>/dev/null; then
  try() {
    unfunction try
    eval "$(SHELL=/bin/zsh command try init ~/Work/tries)"
    try "$@"
  }
fi

if command -v fzf &>/dev/null; then
  [[ -f /usr/share/fzf/completion.zsh ]] && source /usr/share/fzf/completion.zsh
  [[ -f /usr/share/fzf/key-bindings.zsh ]] && source /usr/share/fzf/key-bindings.zsh
fi

#
# Plugins (load order matters: autosuggestions before syntax-highlighting,
# and syntax-highlighting must be last)
#
[[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] &&
  source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] &&
  source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
# alias p='python'

# Secrets (API keys, tokens) never go in this file, which is public in git.
# Put them in ~/.zshrc.local, which install.sh never touches.
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# >>> Codex installer >>>
export PATH="$HOME/.local/bin:$PATH"
# <<< Codex installer <<<
