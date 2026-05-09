#!/usr/bin/env zsh

PS1="Ready > "
RPS1="%F{240}Loading...%f"

############
### Features
############

# Basic
setopt always_to_end extended_glob no_beep no_flow_control no_nomatch prompt_subst

# Directory
DIRSTACKSIZE=16
setopt auto_cd auto_pushd pushd_ignore_dups pushd_minus pushd_silent

# Job Control
setopt long_list_jobs no_bg_nice no_check_jobs no_hup

# I/O
setopt interactive_comments no_clobber rc_quotes

# History
HISTFILE="${ZSH[DATA_DIR]}/zhistory"
HISTSIZE=131073
SAVEHIST=131073
setopt hist_save_no_dups hist_find_no_dups hist_ignore_dups hist_ignore_space hist_verify inc_append_history extended_history hist_reduce_blanks

#
### End of Features
#

############
### Prompt
############
# . "${ZDOTDIR}/prompt.zsh"

# Modified based on zimfw/asciiship & fff7d1bc/conf-mgmt & ohmyzsh/ohmyzsh/blob/master/themes/fishy.zsh-theme
# https://gist.github.com/poscat0x04/152faf5087e261314c0961dd3c3367ec

zmodload zsh/datetime
zmodload zsh/system

typeset -gA _asciiship

_asciiship=(
  start_time  0
  git_fd      -1
  env_fd      -1
  git         ""
  env         ""
)

_asciiship_get_shortened_dir() {
  local directory_parts
  directory_parts=("${(s:/:)PWD/#$HOME/~}")
  
  if zstyle -t ':asciiship:' dir-short; then
    if (( $#directory_parts > 1 )); then
      for i in {1..$(($#directory_parts-1))}; do
        if [[ "${directory_parts[$i]}" = .* ]]; then
          directory_parts[$i]="${${directory_parts[$i]}[1,2]}"
        else
          directory_parts[$i]="${${directory_parts[$i]}[1]}"
        fi
      done
    fi
  fi
  printf "%s" "${(j:/:)directory_parts}"
}

_asciiship_duration_format() {
  typeset -i elapsed=$1 h m s
  (( h = elapsed / 3600 ))
  (( m = (elapsed % 3600) / 60 ))
  (( s = elapsed % 60 ))
  local out=""
  (( h )) && out+="${h}h"
  (( m )) && out+="${m}m"
  out+="${s}s"
  print -r -- "$out"
}

_asciiship_title_updater() {
  case "$TERM" in
    rxvt*|xterm*|*term|screen*|st*|alacritty|kitty|foot) ;;
    *) return ;;
  esac

  local user="${USER}"
  local host="${(%):-%m}"
  local dir="${3:-$(_asciiship_get_shortened_dir)}"
  local title

  if [[ "$1" == "preexec" ]]; then
    local -a words
    words=("${(z)2}")
    local skip_prefixes="(env|sudo|doas|time|nice|nohup)"
    local -a cmd_args
    cmd_args=(${words:#(*=*|$~skip_prefixes)})
    local cmd_name="${(V)cmd_args[1]:t}"
    [[ -z "$cmd_name" ]] && cmd_name="${(V)2}"
    title="$cmd_name [$user@$host: $dir]"
  else
    title="$user@$host: $dir"
  fi

  [[ -n "$SSH_TTY" ]] && title="~> $title"
  printf '\e]0;%s\a' "$title"
}

_asciiship_set_transient_prompt() {
  PROMPT="%F{cyan}>%f "
  RPROMPT=""
  zle reset-prompt
}
zle -N zle-line-finish _asciiship_set_transient_prompt

_asciiship_cleanup_fd() {
  local fd=$1
  if (( fd > 2 )); then
    zle -F "$fd" 2>/dev/null
    exec {fd}>&- 2>/dev/null
  fi
}

_asciiship_git_helper() {
  emulate -L zsh
  local fd=$1
  if [[ -z "$2" || "$2" == "hup" ]]; then
    local result branch ahead behind conflicted stashed staged renamed deleted modified untracked git_state
    IFS='' read -rd '' -u $fd result
    eval $result

    if [[ -z "$branch" ]]; then
      _asciiship[git]=""
    else
      local status_text=""
      [[ $ahead      -gt 0 ]] && status_text+="%F{82}⇡${ahead}%f"
      [[ $behind     -gt 0 ]] && status_text+="%F{214}⇣${behind}%f"
      [[ $conflicted -gt 0 ]] && status_text+="%F{196}~${conflicted}%f"
      [[ $stashed    -gt 0 ]] && status_text+="%F{141}*${stashed}%f"
      [[ $staged     -gt 0 ]] && status_text+="%F{45}+${staged}%f"
      [[ $renamed    -gt 0 ]] && status_text+="%F{33}↠${renamed}%f"
      [[ $deleted    -gt 0 ]] && status_text+="%F{160}×${deleted}%f"
      [[ $modified   -gt 0 ]] && status_text+="%F{220}!${modified}%f"
      [[ $untracked  -gt 0 ]] && status_text+="%F{245}?${untracked}%f"

      local open="%F{blue}[%B%F{white}"
      local close="%b%F{blue}]%f"
      
      if [[ -n "$status_text" ]]; then
        _asciiship[git]=" %F{white}on ${open}${branch}%F{101}:${status_text}${close}${git_state}"
      else
        _asciiship[git]=" %F{white}on ${open}${branch}${close}${git_state}"
      fi
    fi

    zle && zle reset-prompt
  fi

  _asciiship_cleanup_fd "$fd"
  _asciiship[git_fd]=-1
}

_asciiship_git_render() {
  _asciiship_cleanup_fd "$_asciiship[git_fd]"

  if ! zstyle -t ':asciiship:' git-info; then
    _asciiship[git]=""
    return
  fi

  local git_dir
  git_dir=$(git rev-parse --git-dir 2>/dev/null) || { _asciiship[git]=""; return }
  local fd=-1
  exec {fd}< <(
    local current_state=""
    [[ -f $git_dir/MERGE_HEAD                              ]] && current_state=" %F{red}(merge)%f"
    [[ -d $git_dir/rebase-merge || -d $git_dir/rebase-apply ]] && current_state=" %F{red}(rebase)%f"
    [[ -f $git_dir/CHERRY_PICK_HEAD                        ]] && current_state=" %F{red}(cherry-pick)%f"
    [[ -f $git_dir/BISECT_LOG                              ]] && current_state=" %F{red}(bisect)%f"
    [[ -f $git_dir/REVERT_HEAD                             ]] && current_state=" %F{red}(revert)%f"

    git status --porcelain=v2 --branch --show-stash --ahead-behind 2>/dev/null | awk -v git_state="$current_state" '
    BEGIN { 
      conflicted=deleted=renamed=modified=staged=stashed=untracked=ahead=behind=0; 
      branch=""; commit=""; 
    }
    {
      if ($1=="#") {
        if ($2=="branch.ab")   { ahead=int(substr($3,2)); behind=int(substr($4,2)) }
        else if ($2=="branch.oid")  { commit=substr($3,1,7) }
        else if ($2=="branch.head") { branch=($3=="(detached)" ? commit : $3) }
        else if ($2=="stash")       { stashed=$3 }
      } else if ($1=="?") {
        untracked++
      } else if ($1=="u") {
        conflicted++
      } else if ($1=="1" || $1=="2") {
        fst=substr($2,1,1); snd=substr($2,2,1);
        if (snd=="D") deleted++
        if (snd=="M" || snd=="A" || snd=="T") modified++
        if (fst=="M" || fst=="A" || fst=="T" || fst=="D") staged++
        if ($1=="2") renamed++
      }
    }
    END {
      printf "branch=%s ahead=%d behind=%d conflicted=%d stashed=%d staged=%d renamed=%d deleted=%d modified=%d untracked=%d git_state=\"%s\";", \
        branch, ahead, behind, conflicted, stashed, staged, renamed, deleted, modified, untracked, git_state
    }'
  )
  
  _asciiship[git_fd]="$fd"
  zle -F "$fd" _asciiship_git_helper
}

_asciiship_env_helper() {
  emulate -L zsh
  local fd=$1
  if [[ -z "$2" || "$2" == "hup" ]]; then
    local env_data
    IFS='' read -u $fd env_data
    
    local -a marker_list
    local venv_info=""
    local final_content=""

    if [[ -n "$env_data" ]]; then
      for item in ${(s:,:)env_data}; do
        case $item in
          py)   marker_list+=("%F{75}py%f") ;;
          node) marker_list+=("%F{76}node%f") ;;
          zig)  marker_list+=("%F{214}zig%f") ;;
          rs)   marker_list+=("%F{208}rs%f") ;;
          bun)  marker_list+=("%F{231}bun%f") ;;
          nix)  marker_list+=("%F{81}nix%f") ;;
        esac
      done
    fi

    if [[ -n "$VIRTUAL_ENV" ]]; then
      venv_info="%B%F{yellow}${VIRTUAL_ENV:t}%f%b"
    fi

    local markers_str="${(j:/:)marker_list}"

    if [[ -n "$venv_info" && -n "$markers_str" ]]; then
      final_content="${venv_info}%F{242}|%f${markers_str}"
    elif [[ -n "$venv_info" ]]; then
      final_content="${venv_info}"
    elif [[ -n "$markers_str" ]]; then
      final_content="${markers_str}"
    fi

    if [[ -n "$final_content" ]]; then
      _asciiship[env]=" %F{242}via %F{blue}[%f${final_content}%F{blue}]%f"
    else
      _asciiship[env]=""
    fi

    zle && zle reset-prompt
  fi

  _asciiship_cleanup_fd "$fd"
  _asciiship[env_fd]=-1
}

_asciiship_env_render() {
  _asciiship_cleanup_fd "$_asciiship[env_fd]"

  if ! zstyle -t ':asciiship:' env-info; then
    if [[ -n "$VIRTUAL_ENV" ]]; then
      _asciiship[env]=" %F{242}via %F{blue}[%B%F{yellow}${VIRTUAL_ENV:t}%f%b%F{blue}]%f"
    else
      _asciiship[env]=""
    fi
    return
  fi

  local fd=-1
  exec {fd}< <(
    local current_dir="$PWD"
    local -A found
    local results=()
    
    for i in {0..2}; do
      [[ "$current_dir" == "/" ]] && break
      [[ "$current_dir" == "${HOME:h}" ]] && break

      [[ -z ${found[py]} ]]   && ( [[ -f "$current_dir/pyproject.toml" || -f "$current_dir/requirements.txt" ]] ) && { found[py]=1; results+=(py) }
      [[ -z ${found[node]} ]] && ( [[ -f "$current_dir/package.json" || -d "$current_dir/node_modules" ]] ) && { found[node]=1; results+=(node) }
      [[ -z ${found[zig]} ]]  && ( [[ -f "$current_dir/build.zig" || -d "$current_dir/zig-cache" ]] ) && { found[zig]=1; results+=(zig) }
      [[ -z ${found[rs]} ]]   && [[ -f "$current_dir/Cargo.toml" ]] && { found[rs]=1; results+=(rs) }
      [[ -z ${found[bun]} ]]  && ( [[ -f "$current_dir/bun.lockb" || -f "$current_dir/bunfig.toml" ]] ) && { found[bun]=1; results+=(bun) }
      [[ -z ${found[nix]} ]]  && ( [[ -f "$current_dir/flake.nix" || -f "$current_dir/shell.nix" || -f "$current_dir/default.nix" ]] ) && { found[nix]=1; results+=(nix) }

      current_dir="${current_dir:h}"
      [[ "$current_dir" == "$HOME" && $i -gt 0 ]] && break
    done
    echo "${(j:,:)results}"
  )

  _asciiship[env_fd]=$fd
  zle -F "$fd" _asciiship_env_helper
}

preexec() {
  _asciiship[start_time]=$EPOCHSECONDS
  _asciiship_title_updater preexec "$1"
}

precmd() {
  local _dir
  _dir="$(_asciiship_get_shortened_dir)"

  if (( _asciiship[start_time] > 0 )); then
    local -i elapsed=$(( EPOCHSECONDS - _asciiship[start_time] ))
    (( elapsed > 3 )) && RPROMPT="%F{yellow}$(_asciiship_duration_format $elapsed)%f" || RPROMPT=""
    _asciiship[start_time]=0
  else
    RPROMPT=""
  fi

  _asciiship_title_updater precmd "" "$_dir"
  _asciiship_git_render
  _asciiship_env_render

  PROMPT='
%(2L.%B%F{white}(%L)%f%b .)%(!.%B%F{red}%n%f%b in .%B%F{blue}${SSH_TTY:+"%n@%m in "}%f%b)%B%F{cyan}'"$_dir"'%f%b${_asciiship[git]}${_asciiship[env]}
%B%(1j.%F{blue}*%f .)%(?.%F{green}.%F{red}%? )%#%f%b '
}

#
### End of Prompt
#

############
### Func
############
history-fuzzy-search() {
  local preview_cmd="printf '%s' {2..} | sed 's/\\\\n/\\n/g'"

  local selected=$(
    fc -lnr 1 | fzf +s +m -x \
    --scheme=history \
    --layout=reverse \
    --height=50% \
    --preview-window='bottom:3:wrap' \
    --preview "printf '%s' {..}" \
    --query="${BUFFER}"
  )

  if [ -n "${selected}" ]; then
    BUFFER="${selected#"${selected%%[![:space:]]*}"}"
    CURSOR=${#BUFFER}
  fi
  
  zle reset-prompt
}

## file find
file-fuzzy-find() {
  emulate -L zsh -o no_aliases
  local fuzzy_filefind cmd keyword
  if [[ "${BUFFER}" == *" "* ]]; then
    cmd=${${BUFFER}[(w)1]}
    keyword=${BUFFER#"${cmd} "}
    fuzzy_filefind="$cmd $(eval ${FZF_DEFAULT_COMMAND} | fzf --height=50% --layout=reverse --scheme=path --query="${keyword}" +m)"
  else
    fuzzy_filefind="$(eval ${FZF_DEFAULT_COMMAND} | fzf --height=50% --layout=reverse --scheme=path --query="${BUFFER}" +m)"
  fi
  if [ -n "$fuzzy_filefind" ]; then
    BUFFER="${fuzzy_filefind[@]}"
  fi
  zle end-of-line
  zle reset-prompt
}

## sudo or doas will be inserted before the command
sudo-command-line() {
  emulate -L zsh -o no_aliases
  local cmd
  [[ -z ${BUFFER} ]] && zle up-history
  if (( ${+commands[doas]} )) ; then
    cmd="doas "
  elif (( ${+commands[sudo]} )) ; then
    cmd="sudo "
  else
    cmd="su - root -c "
  fi
  if [[ ${BUFFER} == ${cmd}* ]]; then
    CURSOR=$(( CURSOR-${#cmd} ))
    BUFFER="${BUFFER#$cmd}"
  else
    BUFFER="${cmd}${BUFFER}"
    CURSOR=$(( CURSOR+${#cmd} ))
  fi
  zle reset-prompt
}

## File Download
xget() {
  local uri="$1"
  local save="$2"
  if [[ -z "$save" ]]; then
    save=$(basename "${uri%%\?*}")
  fi
  if (( ${+commands[aria2c]} )); then
    aria2c --max-connection-per-server=4 --continue "$uri" -o "$save"
  elif (( ${+commands[axel]} )); then
    axel --num-connections=4 --alternate "$uri" -o "$save"
  elif (( ${+commands[wget]} )); then
    wget --hsts-file="${XDG_CACHE_HOME}/wget-hsts" --continue --progress=bar -O "$save" "$uri"
  elif (( ${+commands[curl]} )); then
    curl --continue-at - --location --progress-bar --remote-name --remote-time "$uri" -o "$save"
  else
    print -r -- "No suitable download tool found."
  fi
}

## smart cd function, allows switching to /etc when running 'cd /etc/fstab'
cd() {
  if (( ${#argv} == 1 )) && [[ -f ${1} ]]; then
    [[ ! -e ${1:h} ]] && return 1
    print -r -- "Correcting ${1} to ${1:h}"
    builtin cd ${1:h}
  else
    builtin cd "$@"
  fi
}

reload() {
  # clear
  exec "${SHELL}" "$@"
}

mdcd() {
  [[ -n "$1" ]] && mkdir -p "$1" && builtin cd "$1"
}

.dot() {
  local dot_work="${DOT_WORK:-${HOME}}"
  local dot_dir="${DOT_DIR:-${dot_work}/.config/.dot}"
  local -a dot_git=(git --git-dir="$dot_dir" --work-tree="$dot_work")
  local -A dot_alias=( ci "commit -m" st status ls "ls-files" )
  (( $# == 0 )) && { printf 'Usage: dot <git-command> | dot init [repo_url]\n'; return 1 }
  case "$1" in
    init) shift
      [[ -d "$dot_dir" ]] && { printf 'Error: %s exists.\n' "$dot_dir" >&2; return 1 }
      mkdir -p "${dot_dir:h}"
       [[ -n "$1" ]] && git clone --bare "$1" "$dot_dir" || git init --bare "$dot_dir"
      git --git-dir="$dot_dir" --work-tree="$dot_work" config --local status.showUntrackedFiles no
      printf '/*\n!.config/\n!.local/\n.config/.dot/\n.local/state/\n*.bak\n' >> "$dot_dir/info/exclude"
      if [[ -n $1 ]];then
        if ! $dot_git switch dotfiles 2>/dev/null; then
          printf 'Conflict detected. Backing up files to %s/.dot-backup...\n' "$dot_work"
          $dot_git switch dotfiles 2>&1 | awk '/^[[:space:]]+[^[:space:]]/ {print $1}' | while IFS= read -r file; do
            mkdir -p "$dot_work/.dot-backup/${file:h}"
            printf "move %s => %s\n" "$dot_work/$file" "$dot_work/.dot-backup/$file"
            mv "$dot_work/$file" "$dot_work/.dot-backup/$file"
          done
          $dot_git switch dotfiles || { printf 'Error: Checkout failed even after backup.\n' >&2; return 1 }
        else
          printf "Checked out config.\n"
        fi
      else
        $dot_git branch -m dotfiles
      fi;;
    add) shift
      for arg in "$@"; do
        if [[ "$arg" == "." || "$arg" == ".." || "$arg" == "*" || "$arg" == "-A" || "$arg" == "--all" || "$arg" == "-u" || "$arg" == "--update" ]]; then
          printf 'Error: "dot add %s" is forbidden. Use explicit paths.\n' "$arg" >&2
          return 1
        fi
      done
       $dot_git add "$@";;
    *)
      local cmd="${dot_alias[$1]:-$1}"
      shift
      $dot_git ${=cmd} "$@";;
  esac
}

_dot() {
  local -x GIT_WORK_TREE="${DOT_WORK:-${HOME}}"
  local -x GIT_DIR="${DOT_DIR:-${GIT_WORK_TREE}/.config/.dot}"
  words[1]="git"; service="git"; _git
}

alias dot='noglob .dot'

#
### End of Func
#

############
### Keybindings
############

# Modified based on jirutka/alpine-zsh-config
# Use emacs key bindings.
bindkey -e

# Load widgets that are not loaded by default.
autoload -U up-line-or-beginning-search
zle -N up-line-or-beginning-search

autoload -U down-line-or-beginning-search
zle -N down-line-or-beginning-search

[[ ${TERM} != dumb ]] && () {
  emulate -L zsh -o no_aliases

  # Make sure that the terminal is in application mode when zle is active,
  # since only then values from $terminfo are valid.
  if (( ${+terminfo[smkx]} && ${+terminfo[rmkx]} )); then
    autoload -U add-zle-hook-widget

    function .zshrc::term-application-mode() {
      echoti smkx
    }
    add-zle-hook-widget zle-line-init .zshrc::term-application-mode

    function .zshrc::term-normal-mode() {
      echoti rmkx
    }
    add-zle-hook-widget zle-line-finish .zshrc::term-normal-mode
  fi

  # `seq` is a fallback for the case when terminfo is not available.
  local kcap seq widget
  for kcap   seq        widget (                     # key name
    khome  '^[[H'     beginning-of-line              # Home
    khome  '^[OH'     beginning-of-line              # Home (in app mode)
    kend   '^[[F'     end-of-line                    # End
    kend   '^[OF'     end-of-line                    # End (in app mode)
    kdch1  '^[[3~'    delete-char                    # Delete
    kpp    '^[[5~'    up-line-or-history             # PageUp
    knp    '^[[6~'    down-line-or-history           # PageDown
    kcuu1  '^[[A'     up-line-or-beginning-search    # UpArrow - fuzzy find history backward
    kcuu1  '^[OA'     up-line-or-beginning-search    # UpArrow - fuzzy find history backward (in app mode)
    kcud1  '^[[B'     down-line-or-beginning-search  # DownArrow - fuzzy find history forward
    kcud1  '^[OB'     down-line-or-beginning-search  # DownArrow - fuzzy find history forward (in app mode)
    kcbt   '^[[Z'     reverse-menu-complete          # Shift + Tab
    x      '^[[2;5~'  copy-region-as-kill            # Ctrl + Insert
    kDC5   '^[[3;5~'  kill-word                      # Ctrl + Delete
    kRIT5  '^[[1;5C'  forward-word                   # Ctrl + RightArrow
    kLFT5  '^[[1;5D'  backward-word                  # Ctrl + LeftArrow
  ); do
    bindkey -M emacs ${terminfo[$kcap]:-$seq} $widget
    bindkey -M viins ${terminfo[$kcap]:-$seq} $widget
    bindkey -M vicmd ${terminfo[$kcap]:-$seq} $widget
  done
}

# Expandpace.
bindkey ' ' magic-space

# Use smart URL pasting and escaping.
autoload -Uz bracketed-paste-url-magic && zle -N bracketed-paste bracketed-paste-url-magic
autoload -Uz url-quote-magic && zle -N self-insert url-quote-magic

# <Ctrl-e> to edit command-line in EDITOR
autoload -Uz edit-command-line && zle -N edit-command-line && \
  bindkey "^E" edit-command-line

# [Esc] [Esc] to sudo-command-line
zle -N sudo-command-line && \
  bindkey "\e\e" sudo-command-line

if (( ${+commands[fzf]} )) ; then
# <Ctrl-r> to history-fuzzy-search
  zle -N history-fuzzy-search && \
    bindkey "^R" history-fuzzy-search
# <Ctrl-t> to file-fuzzy-find
  zle -N file-fuzzy-find && \
    bindkey "^T" file-fuzzy-find
fi

.clear-msg() { zle reset-prompt; zle redisplay; }
zle -N .clear-msg && \
  bindkey '\e' .clear-msg

.exit_zsh() { exit; }
zle -N .exit_zsh && \
  bindkey "^D" .exit_zsh

#
### End of Keybindings
#

############
### Plugins
############
typeset -A ZINIT=(
  BIN_DIR         "${ZSH[DATA_DIR]}/@zinit"
  HOME_DIR        "${ZSH[DATA_DIR]}"
  ZCOMPDUMP_PATH  "${ZSH[CACHE_DIR]}/zcompdump"
)

if [[ ! -e "${ZINIT[BIN_DIR]}" ]]; then
  print -P "%F{cyan}Installing ZINIT…%f"
  command mkdir -pv "${ZINIT[HOME_DIR]}" \
    && command git clone --depth 1 https://github.com/zdharma-continuum/zinit.git "${ZINIT[BIN_DIR]}" \
    || {print -P "%F{red}The clone has failed.%f"; return 1} && print -P "%F{cyan}Setting up zinit%f" \
    && command chmod g-rwX "${ZINIT[HOME_DIR]}" && zcompile "${ZINIT[BIN_DIR]}/zinit.zsh" \
    && print -P "%F{cyan}Installation successful.%f"
fi
if [[ -e "${ZINIT[BIN_DIR]}/zinit.zsh" ]]; then
  source "${ZINIT[BIN_DIR]}/zinit.zsh" \
    && autoload -Uz _zinit \
    && (( ${+_comps} )) \
    && _comps[zinit]=_zinit
else
  print -P "%F{red}Unable to find 'zinit.zsh'" && return 1
fi

zstyle ':completion::complete:*' use-cache on
zstyle ':completion:*' cache-path "${ZSH[CACHE_DIR]}/zcompcache"

# Aloxaf/fzf-tab
zstyle -d ':completion:*' format
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*:git-checkout:*' sort false
zstyle ':completion:*' menu no
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls -1 --color=always $realpath'
zstyle ':completion:*:*:cd:*:*' tag-order 'local-directories directory-stack path-directories'

# zsh-users/zsh-autosuggestions
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_HISTORY_IGNORE="(cd |ls |git add |man )*"
ZSH_AUTOSUGGEST_USE_ASYNC=1
ZSH_AUTOSUGGEST_MANUAL_REBIND=1
ZSH_AUTOSUGGEST_HISTORY_IGNORE='?(#c80,)'

zinit wait"0a" lucid light-mode for \
  OMZL::clipboard.zsh \
   atload"alias x=extract" \
  OMZP::extract/extract.plugin.zsh \
   as"completion" \
  OMZP::extract/_extract

zinit wait"0b" lucid light-mode blockf for \
   atinit"ZSHZ_DATA=${ZSH[DATA_DIR]}/z.dat" \
  agkozak/zsh-z \
   atinit"zpcompinit; zpcdreplay; compdef _dot .dot" \
  zsh-users/zsh-completions \
  Aloxaf/fzf-tab

zinit wait"0c" lucid light-mode for \
  zdharma-continuum/fast-syntax-highlighting \
   atload"_zsh_autosuggest_start" \
  zsh-users/zsh-autosuggestions \
   atinit"ABBR_USER_ABBREVIATIONS_FILE=${ZSH[DATA_DIR]}/abbr" \
  olets/zsh-abbr \
   has"-atuin" id-as"atuinsh/atuin" atclone"atuin init zsh > init.zsh; zcompile init.zsh" nocompile src"init.zsh" \
  zdharma-continuum/null \
   if"(( ! $+commands[fzf] && ! $+commands[atuin] ))" \
  zdharma-continuum/history-search-multi-word

#
### End of Plugins
#

############
### Misc
############

# prompt optional
zstyle ':asciiship:' env-info true
zstyle ':asciiship:' git-info true
zstyle ':asciiship:' dir-short true

#
### End of Misc
#

############
### Aliases
############

if (( ${+commands[bat]} )); then
  alias cat='bat -p'
elif (( ${+commands[batcat]} )); then
  alias cat='batcat -p'
  alias bat='batcat'
fi

if (( ${+commands[eza]} )); then
  alias ls='command eza --color=auto --sort=Name --classify --group-directories-first --time-style=long-iso --group'
  alias l='ls'
  alias la='ls -a'
  alias ll='ls --all --header --long'
else
  alias ls="ls --color=auto --group-directories-first -C -F -h"
  alias l="ls"
  alias la="ls -al"
  alias ll="la"
fi

if (( ${+commands[fdfind]} )); then
  alias fd='fdfind'
fi

if (( ${+commands[doas]} )) ; then
  alias s="doas"
elif (( ${+commands[sudo]} )); then
  alias s="sudo"
fi

alias wget="wget --hsts-file=${XDG_CACHE_HOME}/wget-hsts"

#
### End of Aliases
#

##### end
