setopt NO_GLOBAL_RCS
zmodload zsh/files
umask 0022
typeset -gU path fpath
if [[ -z "${USER}" ]]; then
  if (( EUID == 0 )); then
    USER="root"
  else
    USER="${LOGNAME:-$(id -un)}"
  fi
fi

: ${XDG_CONFIG_HOME:=${HOME}/.config}
: ${XDG_CACHE_HOME:=${HOME}/.cache}
: ${XDG_DATA_HOME:=${HOME}/.local/share}
: ${XDG_STATE_HOME:=${HOME}/.local/state}

: ${ZDOTDIR:=${XDG_CONFIG_HOME}/zsh}
export WGETRC="${XDG_CONFIG_HOME}/wget/wgetrc"
export PYTHONSTARTUP="${XDG_CONFIG_HOME}/python/pythonrc"
export PIP_CONFIG_FILE="${XDG_CONFIG_HOME}/python/pip.conf"
export LESSHISTFILE="${XDG_STATE_HOME}/lesshst"
export INPUTRC="${XDG_CONFIG_HOME}/readline/inputrc"
export DOCKER_CONFIG="${XDG_CONFIG_HOME}/docker"
export ANDROID_USER_HOME="${XDG_DATA_HOME}/android"
export CCACHE_CONFIGPATH="${XDG_CONFIG_HOME}/ccache/ccache.conf"
export CCACHE_DIR="${XDG_CACHE_HOME}/ccache"
export XDG_CONFIG_HOME XDG_CACHE_HOME XDG_DATA_HOME XDG_STATE_HOME ZDOTDIR

typeset -A ZSH=(
  CONFIG_DIR         "${XDG_CONFIG_HOME}/zsh"
  CACHE_DIR          "${XDG_CACHE_HOME}/zsh"
  DATA_DIR           "${XDG_DATA_HOME}/zsh"
)
export ZSH_CACHE_DIR="${ZSH[CACHE_DIR]}"
mkdir -p "${ZSH[CACHE_DIR]}" "${ZSH[DATA_DIR]}"
export ZPFX="${HOME}/.local"

path+=( "${HOME}/.local/bin" )

if [[ "${TERM}" == "linux" ]] ; then
  export LANG=C.UTF-8
fi

if (( ${+commands[gpg]} )); then
  export GNUPGHOME="${XDG_DATA_HOME}/gnupg"
  export GPG_TTY=$TTY
fi

if (( ${+commands[npm]} )); then
  export NPM_CONFIG_USERCONFIG="${XDG_CONFIG_HOME}/npm/npmrc"
  [[ ! -d "${XDG_CONFIG_HOME}/npm" ]] && mkdir "${XDG_CONFIG_HOME}/npm"
fi

if (( ${+commands[cargo]} )); then
  export CARGO_HOME="${XDG_DATA_HOME}/cargo"
  export RUSTUP_HOME="${XDG_DATA_HOME}/rustup"
  path+=( "${CARGO_HOME}/bin" )
fi

if (( ${+commands[go]} )); then
  export GOPATH="${XDG_DATA_HOME}/go"
  path+=( "${GOPATH}/bin" )
fi

if [[ -z "${EDITOR}" ]]; then
  for _editor in helix hx nvim vim nano; do
    if (( ${+commands[${_editor}]} )); then
      export EDITOR="${_editor}"
      break
    fi
  done
fi
unset _editor

if (( ${+commands[fd]} )); then
  export FZF_DEFAULT_COMMAND="fd --hidden --follow --exclude '.git' --exclude 'node_modules'"
elif (( ${+commands[fdfind]} )); then
  export FZF_DEFAULT_COMMAND="fdfind --hidden --follow --exclude '.git' --exclude 'node_modules'"
else
  export FZF_DEFAULT_COMMAND='find . -type f -not \( -path "*/.git/*" -o -path "./node_modules/*" \)'
fi
